import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math';
import 'dart:developer' as developer;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../services/supabase_service.dart';

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
  final _membersListKey = GlobalKey();
  final _memberUpdateNotifier = ValueNotifier<int>(0);

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
    _memberUpdateNotifier.dispose();
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

      // Get all users except current participants with their position and company info
      final users = await _supabase
          .from('profiles')
          .select('id, display_name, position, company_name')
          .not('id', 'in', currentParticipantIds);

      if (users.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No users available to add'),
              backgroundColor: Colors.blue,
            ),
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

        // Trigger members list refresh
        _memberUpdateNotifier.value++;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Successfully added ${selectedUsers.length} member${selectedUsers.length > 1 ? 's' : ''} to the group',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Failed to add members: ${e.toString()}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        );
      }
    }
  }

  Future<void> _shareGroupQRCode() async {
    if (!_isGroupChat) return;

    final qrData = 'crewtap://join/group/${widget.chatId}/${_groupName}';

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Share Group',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 200.0,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Scan this QR code to join "$_groupName"',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await Share.share(
                        'Join my group "$_groupName" on CrewTap!\n\nScan the QR code',
                        subject: 'Join my CrewTap group',
                      );
                    },
                    child: const Text('Share'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMembersList() {
    return ValueListenableBuilder<int>(
      valueListenable: _memberUpdateNotifier,
      builder: (context, _, __) => FutureBuilder<List<Map<String, dynamic>>>(
        key: _membersListKey,
        future: _supabase
            .from('chat_participants')
            .select('user_id')
            .eq('chat_id', widget.chatId),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final participantIds = snapshot.data!.map((p) => p['user_id'] as String).toList();
            return FutureBuilder<List<Map<String, dynamic>>>(
              future: _supabase
                  .from('profiles')
                  .select('id, display_name')
                  .inFilter('id', participantIds),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: snapshot.data!.map((user) {
                        final displayName = user['display_name'] as String? ?? 'Unknown';
                        final names = displayName.split(' ');
                        final initials = names.length > 1
                            ? '${names[0][0]}${names[1][0]}'
                            : displayName.substring(0, min(2, displayName.length));
                        
                        // Generate a consistent color based on the user's ID
                        final colorSeed = user['id'].hashCode;
                        final colors = [
                          const Color(0xFF0EA5E9), // Blue
                          const Color(0xFF10B981), // Green
                          const Color(0xFFF59E0B), // Yellow
                          const Color(0xFFEF4444), // Red
                          const Color(0xFF8B5CF6), // Purple
                          const Color(0xFFEC4899), // Pink
                        ];
                        final color = colors[colorSeed % colors.length];
                        
                        return Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: Column(
                            children: [
                              Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: color.withOpacity(0.2),
                                    child: Text(
                                      initials.toUpperCase(),
                                      style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  if (user['id'] == _supabase.auth.currentUser?.id)
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                names[0],
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
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
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isGroupChat ? _groupName : widget.recipientName,
                style: const TextStyle(fontSize: 18),
              ),
              if (_isGroupChat) ...[
                const SizedBox(height: 4),
                FutureBuilder<Map<String, dynamic>>(
                  future: _supabase
                      .from('chats')
                      .select('expiry_time')
                      .eq('id', widget.chatId)
                      .single(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      final expiryTime = snapshot.data!['expiry_time'] as String?;
                      if (expiryTime != null) {
                        final now = DateTime.now().toUtc();
                        final expiry = DateTime.parse(expiryTime);
                        final difference = expiry.difference(now);
                        
                        String timeLeft;
                        if (difference.isNegative) {
                          timeLeft = 'Expired';
                        } else if (difference.inDays > 0) {
                          timeLeft = '${difference.inDays}d ${difference.inHours % 24}h left';
                        } else if (difference.inHours > 0) {
                          timeLeft = '${difference.inHours}h ${difference.inMinutes % 60}m left';
                        } else {
                          timeLeft = '${difference.inMinutes}m left';
                        }
                        
                        return Text(
                          timeLeft,
                          style: TextStyle(
                            fontSize: 12,
                            color: difference.isNegative ? Colors.red : Colors.grey[600],
                          ),
                        );
                      }
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ],
          ),
          actions: [
            if (_isGroupChat)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  switch (value) {
                    case 'rename':
                      _renameGroup();
                      break;
                    case 'add_members':
                      _addMembers();
                      break;
                    case 'share':
                      _shareGroupQRCode();
                      break;
                    case 'leave':
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
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 8),
                        Text('Rename Group'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'add_members',
                    child: Row(
                      children: [
                        Icon(Icons.person_add, size: 20),
                        SizedBox(width: 8),
                        Text('Add Members'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'share',
                    child: Row(
                      children: [
                        Icon(Icons.qr_code, size: 20),
                        SizedBox(width: 8),
                        Text('Share Group'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'leave',
                    child: Row(
                      children: [
                        Icon(Icons.exit_to_app, size: 20),
                        SizedBox(width: 8),
                        Text('Leave Group'),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
        body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isGroupChat)
              Container(
                padding: const EdgeInsets.all(16),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[200]!),
                  ),
                ),
                child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Crew Members',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildMembersList(),
                  ],
                ),
              ),
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

  const AddMembersDialog({super.key, required this.users});

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
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user['display_name'] ?? 'Unknown User',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (user['position'] != null || user['company_name'] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${user['position'] ?? ''}${user['position'] != null && user['company_name'] != null ? ' at ' : ''}${user['company_name'] ?? ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
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