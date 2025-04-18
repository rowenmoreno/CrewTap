import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; // For date formatting
import '../../../../services/supabase_service.dart';
import 'dart:async'; // For Timer
import '../message_details/message_details_screen.dart';
import 'messages_controller.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(MessagesController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: controller.searchController,
              decoration: InputDecoration(
                hintText: 'Search messages',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }

              if (controller.errorMessage.value != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Error: ${controller.errorMessage.value} Please try again later.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  ),
                );
              }

              if (controller.filteredChats.isEmpty) {
                if (controller.searchController.text.isNotEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No chats found for "${controller.searchController.text}"',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }
                return _buildEmptyState();
              }

              return RefreshIndicator(
                onRefresh: () => controller.initializeMessagesScreen(refresh: true),
                child: ListView.separated(
                  itemCount: controller.filteredChats.length,
                  separatorBuilder: (context, index) => Divider(height: 1, indent: 72, color: Colors.grey[200]),
                  itemBuilder: (context, index) {
                    final chat = controller.filteredChats[index];
                    return _buildChatListItem(chat, controller);
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildChatListItem(Map<String, dynamic> chat, MessagesController controller) {
    final isGroup = chat['type'] == 'group';
    final chatName = chat['name'] ?? (isGroup ? 'Group Chat' : 'Private Chat');
    final lastMessage = chat['last_message'] as String? ?? '';
    final lastMessageTime = controller.formatLastMessageTime(chat['last_message_time'] as String?);
    final remainingTime = controller.formatRemainingTime(chat['expiry_time'] as String?);
    final bool hasExpired = remainingTime == 'Expired';
    final bool isUnread = chat['unread_count'] != null && chat['unread_count'] > 0;

    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundColor: isGroup ? Colors.blue[100] : Colors.grey[300],
            child: Icon(
              isGroup ? Icons.group : Icons.person,
              color: isGroup ? Colors.blue[900] : Colors.white,
            ),
          ),
          if (isUnread)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(
                  chat['unread_count'].toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              chatName,
              style: TextStyle(
                fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                color: hasExpired ? Colors.grey : Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (lastMessageTime.isNotEmpty)
            Text(
              lastMessageTime,
              style: TextStyle(
                fontSize: 12,
                color: isUnread ? Colors.blue[900] : Colors.grey[600],
                fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
              ),
            ),
        ],
      ),
      subtitle: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              lastMessage,
              style: TextStyle(
                color: hasExpired ? Colors.grey : (isUnread ? Colors.black87 : Colors.grey[700]),
                fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (chat['expiry_time'] != null && !hasExpired)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Text(
                remainingTime,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.orange,
                  fontWeight: FontWeight.w500
                ),
              ),
            )
          else if (hasExpired)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Text(
                'Expired',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.red[400],
                  fontWeight: FontWeight.w500
                ),
              ),
            )
        ],
      ),
      onTap: hasExpired ? null : () async {
        // Get the recipient ID for private chats
        String recipientId = '';
        if (!isGroup) {
          final participants = await controller.supabase
              .from('chat_participants')
              .select('user_id')
              .eq('chat_id', chat['id']);
          
          final currentUserId = controller.supabase.auth.currentUser?.id;
          recipientId = participants.firstWhere(
            (p) => p['user_id'] != currentUserId,
            orElse: () => {'user_id': ''},
          )['user_id'];
        }
        
        await Get.to(
          () => MessageDetailsScreen(
            chatId: chat['id'],
            recipientName: chatName,
            recipientId: recipientId,
          ),
        );

        // Refresh messages when returning from MessageDetailsScreen
        
          controller.initializeMessagesScreen(refresh: true);
      },
      tileColor: hasExpired ? Colors.grey[100] : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[200],
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              color: Colors.grey[400],
              size: 24,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No conversations yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Scan a QR code or tap a device to get\nstarted',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// TODO: Create ChatDetailScreen widget for navigation
