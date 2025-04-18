import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:math';
import 'message_details_controller.dart';
import '../../../theme/app_theme.dart';

class MessageDetailsScreen extends StatelessWidget {
  final String chatId;
  final String recipientName;
  final String recipientId;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  MessageDetailsScreen({
    super.key,
    required this.chatId,
    required this.recipientName,
    required this.recipientId,
  });

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(MessageDetailsController(
      chatId: chatId,
      recipientName: recipientName,
    ));

    // Listen to messages changes and scroll to bottom
    ever(controller.messages, (_) {
      // Use Future.delayed to ensure the layout is complete
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    });

    return WillPopScope(
      onWillPop: () async {
        Get.back(result: true);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Obx(() => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                controller.isGroupChat.value ? controller.groupName.value : recipientName,
                style: const TextStyle(fontSize: 18),
              ),
              if (controller.isGroupChat.value) ...[
                const SizedBox(height: 4),
                FutureBuilder<Map<String, dynamic>>(
                  future: controller.supabase
                      .from('chats')
                      .select('expiry_time')
                      .eq('id', chatId)
                      .single(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      final expiryTime = snapshot.data!['expiry_time'] as String?;
                      final timeLeft = controller.formatRemainingTime(expiryTime);
                      final isExpired = timeLeft == 'Expired';
                      
                      return Text(
                        timeLeft,
                        style: TextStyle(
                          fontSize: 12,
                          color: isExpired ? Colors.red : Colors.grey[600],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ],
          )),
          actions: [
            Obx(() {
              if (!controller.isGroupChat.value) return const SizedBox.shrink();
              return PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  switch (value) {
                    case 'rename':
                      _showRenameDialog(context, controller);
                      break;
                    case 'add_members':
                      controller.addMembers();
                      break;
                    case 'share':
                      _showShareDialog(context, controller);
                      break;
                    case 'leave':
                      _showLeaveDialog(context, controller);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20, color: AppColors.midnightNavy),
                        SizedBox(width: 8),
                        Text('Rename Group'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'add_members',
                    child: Row(
                      children: [
                        Icon(Icons.person_add, size: 20, color: AppColors.midnightNavy),
                        SizedBox(width: 8),
                        Text('Add Members'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'share',
                    child: Row(
                      children: [
                        Icon(Icons.qr_code, size: 20, color: AppColors.midnightNavy),
                        SizedBox(width: 8),
                        Text('Share Group'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'leave',
                    child: Row(
                      children: [
                        Icon(Icons.exit_to_app, size: 20, color: AppColors.midnightNavy),
                        SizedBox(width: 8),
                        Text('Leave Group'),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Obx(() {
              if (!controller.isGroupChat.value) return const SizedBox.shrink();
              return Container(
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
                    Obx(() => SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: controller.participants.map((user) {
                          final displayName = user['display_name'] as String? ?? 'Unknown';
                          final names = displayName.split(' ');
                          final initials = names.length > 1
                              ? '${names[0][0]}${names[1][0]}'
                              : displayName.substring(0, min(2, displayName.length));
                          
                          // Generate a consistent color based on the user's ID
                          final colorSeed = user['id'].hashCode;
                          final colors = [
                            AppColors.skyBlue,
                            AppColors.aeroTeal,
                            AppColors.crewGold,
                            const Color(0xFF8B5CF6), // Purple
                            const Color(0xFFEC4899), // Pink
                            const Color(0xFFF97316), // Orange
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
                                      backgroundColor: color.withOpacity(0.15),
                                      child: Text(
                                        initials.toUpperCase(),
                                        style: TextStyle(
                                          color: color,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    if (user['id'] == controller.supabase.auth.currentUser?.id)
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: AppColors.aeroTeal,
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
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.jetGrey,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    )),
                  ],
                ),
              );
            }),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (controller.errorMessage.value != null) {
                  return Center(child: Text(controller.errorMessage.value!));
                }
                
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: controller.messages.length,
                  itemBuilder: (context, index) {
                    final message = controller.messages[index];
                    final isMe = message['sender_id'] == controller.supabase.auth.currentUser?.id;
                    final senderName = controller.senderNames[message['sender_id']] ?? 'Unknown';
                    final time = DateFormat('HH:mm').format(
                      DateTime.parse(message['created_at']),
                    );
                    final isSystemMessage = message['type'] == 'system';

                    // Check if we should show the sender name
                    final showSenderName = !isMe && !isSystemMessage && (index == 0 || 
                      controller.messages[index - 1]['sender_id'] != message['sender_id']);

                    if (isSystemMessage) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              message['content'],
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          if (showSenderName)
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
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.75,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isMe ? AppColors.skyBlue : AppColors.aeroTeal.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message['content'],
                                  style: TextStyle(
                                    color: isMe ? Colors.white : AppColors.midnightNavy,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  time,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isMe ? Colors.white70 : AppColors.jetGrey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.cloudWhite,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: AppColors.jetGrey.withOpacity(0.6)),
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (text) {
                        if (text.trim().isNotEmpty) {
                          controller.sendMessage(text);
                          _messageController.clear();
                        }
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    color: AppColors.skyBlue,
                    onPressed: () {
                      final text = _messageController.text;
                      if (text.trim().isNotEmpty) {
                        controller.sendMessage(text);
                        _messageController.clear();
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, MessageDetailsController controller) {
    final TextEditingController nameController = TextEditingController(text: controller.groupName.value);
    
    showDialog<String>(
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
            onPressed: () {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty) {
                Navigator.pop(context);
                controller.renameGroup(newName);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showLeaveDialog(BuildContext context, MessageDetailsController controller) {
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
              controller.leaveGroup();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  void _showShareDialog(BuildContext context, MessageDetailsController controller) {
    final qrData = 'crewtap://join/group/$chatId/${controller.groupName.value}';

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
                'Scan this QR code to join "${controller.groupName.value}"',
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
                        'Join my group "${controller.groupName.value}" on CrewTap!\n\nScan the QR code',
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
} 