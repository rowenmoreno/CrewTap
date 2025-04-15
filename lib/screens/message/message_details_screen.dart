import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:developer' as developer;
import '../../services/supabase_service.dart';

class MessageDetailsScreen extends StatefulWidget {
  final String chatId;
  final String recipientName;
  final String recipientId;

  const MessageDetailsScreen({
    super.key,
    required this.chatId,
    required this.recipientName,
    required this.recipientId,
  });

  @override
  State<MessageDetailsScreen> createState() => _MessageDetailsScreenState();
}

class _MessageDetailsScreenState extends State<MessageDetailsScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _supabase = SupabaseService.client;
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  String? _errorMessage;
  StreamSubscription<List<Map<String, dynamic>>>? _messagesSubscription;
  Map<String, String> _senderNames = {};
  bool _isGroupChat = false;
  String _groupName = '';

  @override
  void initState() {
    super.initState();
    _initializeMessages();
    _checkChatType();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messagesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeMessages() async {
    try {
      // Subscribe to real-time messages
      _messagesSubscription = _supabase
          .from('chat_messages')
          .stream(primaryKey: ['id'])
          .eq('chat_id', widget.chatId)
          .order('created_at', ascending: true)
          .listen((messages) async {
        // Fetch sender names for all messages
        for (var message in messages) {
          if (!_senderNames.containsKey(message['sender_id'])) {
            try {
              final profile = await _supabase
                  .from('profiles')
                  .select('display_name')
                  .eq('id', message['sender_id'])
                  .single();
              _senderNames[message['sender_id']] = profile['display_name'] ?? 'Unknown';
            } catch (e) {
              _senderNames[message['sender_id']] = 'Unknown';
            }
          }
        }
        
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
        _scrollToBottom();
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase.from('chat_messages').insert({
        'chat_id': widget.chatId,
        'sender_id': userId,
        'content': _messageController.text.trim(),
        'status': 'sent',
      });

      _messageController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _checkChatType() async {
    try {
      final chat = await _supabase
          .from('chats')
          .select('type, name')
          .eq('id', widget.chatId)
          .single();
      
      setState(() {
        _isGroupChat = chat['type'] == 'group';
        _groupName = chat['name'] ?? widget.recipientName;
      });
    } catch (e) {
      developer.log('Error checking chat type: $e');
    }
  }

  Future<void> _renameGroup() async {
    final TextEditingController nameController = TextEditingController(text: _groupName);
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Group'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Group Name',
            hintText: 'Enter new group name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      try {
        await _supabase
            .from('chats')
            .update({'name': result})
            .eq('id', widget.chatId);
        
        setState(() {
          _groupName = result;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group renamed successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to rename group: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _leaveGroup() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Remove user from chat participants
      await _supabase
          .from('chat_participants')
          .delete()
          .eq('chat_id', widget.chatId)
          .eq('user_id', userId);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to leave group: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _addMembers() async {
    try {
      // Get current participants
      final currentParticipants = await _supabase
          .from('chat_participants')
          .select('user_id')
          .eq('chat_id', widget.chatId);

      final currentParticipantIds = currentParticipants.map((p) => p['user_id'] as String).toList();

      // Get all users except current participants
      final users = await _supabase
          .from('profiles')
          .select('id, display_name')
          .not('id', 'in', currentParticipantIds);

      if (users.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No users available to add')),
          );
        }
        return;
      }

      final selectedUsers = await showDialog<List<String>>(
        context: context,
        builder: (context) => AddMembersDialog(users: users),
      );

      if (selectedUsers != null && selectedUsers.isNotEmpty && mounted) {
        // Add selected users to chat participants
        for (final userId in selectedUsers) {
          await _supabase.from('chat_participants').insert({
            'chat_id': widget.chatId,
            'user_id': userId,
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added ${selectedUsers.length} members to the group')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add members: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, true);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isGroupChat ? _groupName : widget.recipientName),
          elevation: 0,
          actions: [
            if (_isGroupChat) ...[
              IconButton(
                icon: const Icon(Icons.person_add),
                onPressed: _addMembers,
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: _renameGroup,
              ),
              IconButton(
                icon: const Icon(Icons.exit_to_app),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Leave Group'),
                      content: const Text('Are you sure you want to leave this group?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _leaveGroup();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          child: const Text('Leave'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(child: Text(_errorMessage!))
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            final isMe = message['sender_id'] == _supabase.auth.currentUser?.id;
                            final senderName = _senderNames[message['sender_id']] ?? 'Unknown';
                            final time = DateFormat('HH:mm').format(
                              DateTime.parse(message['created_at']),
                            );

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Column(
                                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  if (!isMe)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                                      child: Text(
                                        senderName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isMe ? Colors.blue[900] : Colors.blue[100],
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          message['content'],
                                          style: TextStyle(
                                            color: isMe ? Colors.white : Colors.black,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          time,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isMe ? Colors.white70 : Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: InputBorder.none,
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    color: Colors.blue[300],
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AddMembersDialog extends StatefulWidget {
  final List<Map<String, dynamic>> users;

  const AddMembersDialog({
    super.key,
    required this.users,
  });

  @override
  State<AddMembersDialog> createState() => _AddMembersDialogState();
}

class _AddMembersDialogState extends State<AddMembersDialog> {
  final List<String> _selectedUsers = [];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Members'),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: ListView.builder(
          itemCount: widget.users.length,
          itemBuilder: (context, index) {
            final user = widget.users[index];
            final isSelected = _selectedUsers.contains(user['id']);
            
            return CheckboxListTile(
              title: Text(user['display_name'] ?? 'Unknown User'),
              value: isSelected,
              onChanged: (bool? value) {
                setState(() {
                  if (value == true) {
                    _selectedUsers.add(user['id']);
                  } else {
                    _selectedUsers.remove(user['id']);
                  }
                });
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _selectedUsers),
          child: const Text('Add'),
        ),
      ],
    );
  }
} 