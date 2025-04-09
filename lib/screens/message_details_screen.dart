import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../services/supabase_service.dart';

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

  @override
  void initState() {
    super.initState();
    _initializeMessages();
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, true);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.recipientName),
          elevation: 0,
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