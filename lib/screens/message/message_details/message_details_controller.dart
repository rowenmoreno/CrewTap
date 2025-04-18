import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../../../services/supabase_service.dart';

class AddMembersDialog extends StatefulWidget  {
  final List<Map<String, dynamic>> users;
  final selectedUserIds = <String>[];

  AddMembersDialog({super.key, required this.users});

  @override
  State<AddMembersDialog> createState() => _AddMembersDialogState();
}

class _AddMembersDialogState extends State<AddMembersDialog> {
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
            return CheckboxListTile(
              title: Text(user['display_name'] ?? 'Unknown'),
              subtitle: Text('${user['position'] ?? ''} at ${user['company_name'] ?? ''}'),
              value: widget.selectedUserIds.contains(user['id']),
              onChanged: (value) {
                if (value == true) {
                  widget.selectedUserIds.add(user['id']);
                } else {
                  widget.selectedUserIds.remove(user['id']);
                }
                setState(() {});
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, widget.selectedUserIds),
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class MessageDetailsController extends GetxController {
  final _supabase = SupabaseService.client;
  SupabaseClient get supabase => _supabase;
  final String chatId;
  final String recipientName;

  MessageDetailsController({
    required this.chatId,
    required this.recipientName,
  });

  final messages = <Map<String, dynamic>>[].obs;
  final isLoading = true.obs;
  final errorMessage = RxnString();
  final senderNames = <String, String>{}.obs;
  final isGroupChat = false.obs;
  final groupName = ''.obs;
  final memberUpdateCount = 0.obs;
  final participants = <Map<String, dynamic>>[].obs;
  StreamSubscription<List<Map<String, dynamic>>>? _messagesSubscription;

  @override
  void onInit() {
    super.onInit();
    initializeMessages();
    checkChatType();
    loadParticipants();
  }

  @override
  void onClose() {
    _messagesSubscription?.cancel();
    super.onClose();
  }

  Future<void> initializeMessages() async {
    try {
      // Subscribe to real-time messages
      _messagesSubscription = _supabase
          .from('chat_messages')
          .stream(primaryKey: ['id'])
          .eq('chat_id', chatId)
          .order('created_at', ascending: true)
          .listen((newMessages) async {
        // Fetch sender names for all messages
        for (var message in newMessages) {
          if (!senderNames.containsKey(message['sender_id'])) {
            try {
              final profile = await _supabase
                  .from('profiles')
                  .select('display_name')
                  .eq('id', message['sender_id'])
                  .single();
              senderNames[message['sender_id']] = profile['display_name'] ?? 'Unknown';
            } catch (e) {
              senderNames[message['sender_id']] = 'Unknown';
            }
          }
        }
        
        messages.value = newMessages;
        isLoading.value = false;
      });
    } catch (e) {
      errorMessage.value = e.toString();
      isLoading.value = false;
    }
  }

  Future<void> checkChatType() async {
    try {
      final chat = await _supabase
          .from('chats')
          .select('type, name')
          .eq('id', chatId)
          .single();
      
      isGroupChat.value = chat['type'] == 'group';
      groupName.value = chat['name'] ?? recipientName;
    } catch (e) {
      print('Error checking chat type: $e');
    }
  }

  Future<void> loadParticipants() async {
    try {
      final participantIds = await _supabase
          .from('chat_participants')
          .select('user_id')
          .eq('chat_id', chatId);

      if (participantIds.isNotEmpty) {
        final users = await _supabase
            .from('profiles')
            .select('id, display_name')
            .inFilter('id', participantIds.map((p) => p['user_id'] as String).toList());

        participants.value = users;
      }
    } catch (e) {
      print('Error loading participants: $e');
    }
  }

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase.from('chat_messages').insert({
        'chat_id': chatId,
        'sender_id': userId,
        'content': content.trim(),
        'status': 'sent',
      });
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to send message: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
    }
  }

  Future<void> _createSystemMessage(String content) async {
    try {
      await _supabase.from('chat_messages').insert({
        'chat_id': chatId,
        'sender_id': _supabase.auth.currentUser?.id,
        'content': content,
        'status': 'sent',
        'type': 'system',
      });
    } catch (e) {
      print('Error creating system message: $e');
    }
  }

  Future<void> addMembers() async {
    try {
      // Get current participants
      final currentParticipants = await _supabase
          .from('chat_participants')
          .select('user_id')
          .eq('chat_id', chatId);

      final currentParticipantIds = currentParticipants.map((p) => p['user_id'] as String).toList();

      // Get all users except current participants
      final users = await _supabase
          .from('profiles')
          .select('id, display_name, position, company_name')
          .not('id', 'in', currentParticipantIds);

      if (users.isEmpty) {
        Get.snackbar(
          'Info',
          'No users available to add',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Get.theme.colorScheme.primary,
          colorText: Get.theme.colorScheme.onPrimary,
        );
        return;
      }

      final selectedUsers = await Get.dialog<List<String>>(
        AddMembersDialog(users: users),
      );

      if (selectedUsers != null && selectedUsers.isNotEmpty) {
        // Get user names for system message
        final newMembers = await _supabase
            .from('profiles')
            .select('display_name')
            .inFilter('id', selectedUsers);
        
        final memberNames = newMembers.map((m) => m['display_name'] as String).join(', ');

        // Add selected users to chat participants
        for (final userId in selectedUsers) {
          await _supabase.from('chat_participants').insert({
            'chat_id': chatId,
            'user_id': userId,
          });
        }

        // Create system message
        await _createSystemMessage('$memberNames joined the group');

        // Refresh participants list
        await loadParticipants();
        memberUpdateCount.value++;

        Get.snackbar(
          'Success',
          'Successfully added ${selectedUsers.length} member${selectedUsers.length > 1 ? 's' : ''} to the group',
          icon: const Icon(Icons.check_circle, color: Colors.white),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          borderRadius: 10,
          margin: const EdgeInsets.all(8),
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to add members: ${e.toString()}',
        icon: const Icon(Icons.error, color: Colors.white),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        borderRadius: 10,
        margin: const EdgeInsets.all(8),
      );
    }
  }

  Future<void> renameGroup(String newName) async {
    try {
      await _supabase
          .from('chats')
          .update({'name': newName})
          .eq('id', chatId);
      
      groupName.value = newName;
      
      Get.snackbar(
        'Success',
        'Group renamed successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to rename group: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> leaveGroup() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Get user's display name for system message
      final userProfile = await _supabase
          .from('profiles')
          .select('display_name')
          .eq('id', userId)
          .single();
      
      final displayName = userProfile['display_name'] as String? ?? 'Unknown';

      // Remove user from chat participants
      await _supabase
          .from('chat_participants')
          .delete()
          .eq('chat_id', chatId)
          .eq('user_id', userId);

      // Create system message
      await _createSystemMessage('$displayName left the group');

      // Refresh participants list
      await loadParticipants();
      memberUpdateCount.value++;

      Get.back();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to leave group: ${e.toString()}',
        icon: const Icon(Icons.error, color: Colors.white),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        borderRadius: 10,
        margin: const EdgeInsets.all(8),
      );
    }
  }

  String formatRemainingTime(String? expiryTimeStr) {
    if (expiryTimeStr == null) return 'Never expires';
    
    final now = DateTime.now().toUtc();
    final expiry = DateTime.parse(expiryTimeStr);
    final difference = expiry.difference(now);
    
    if (difference.isNegative) return 'Expired';
    if (difference.inDays > 0) {
      return '${difference.inDays}d ${difference.inHours % 24}h left';
    }
    if (difference.inHours > 0) {
      return '${difference.inHours}h ${difference.inMinutes % 60}m left';
    }
    return '${difference.inMinutes}m left';
  }
} 