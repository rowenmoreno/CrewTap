import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../../../../services/supabase_service.dart';

class MessagesController extends GetxController {
  final supabase = SupabaseService.client;
  StreamSubscription<List<Map<String, dynamic>>>? _chatsSubscription;
  Timer? _timer;
  final TextEditingController searchController = TextEditingController();

  final isLoading = true.obs;
  final errorMessage = RxnString();
  final chats = <Map<String, dynamic>>[].obs;
  final filteredChats = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    initializeMessagesScreen();
    startTimer();
    ever(RxString(searchController.text), (String value) => _filterChats(value));
  }

  @override
  void onClose() {
    _chatsSubscription?.cancel();
    _timer?.cancel();
    searchController.dispose();
    super.onClose();
  }

  void startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      update(); // Trigger rebuild to update remaining time
    });
  }

  void _filterChats(String query) {
    if (query.isEmpty) {
      filteredChats.value = chats;
      return;
    }

    final lowercaseQuery = query.toLowerCase();
    filteredChats.value = chats.where((chat) {
      final chatName = (chat['name'] ?? '').toString().toLowerCase();
      return chatName.contains(lowercaseQuery);
    }).toList();
  }

  Future<void> initializeMessagesScreen({bool refresh = false}) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      isLoading.value = false;
      errorMessage.value = "User not logged in.";
      return;
    }

    if (!refresh) {
      isLoading.value = true;
    }

    try {
      // Listen for real-time changes in chats and messages
      final chatsStream = supabase
          .from('chats')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false);

      _chatsSubscription?.cancel();
      _chatsSubscription = chatsStream.listen((chatsData) async {
        try {
          final userChats = await supabase
              .from('chat_participants')
              .select('chat_id')
              .eq('user_id', userId);

          final chatIds = userChats.map((p) => p['chat_id'] as String).toList();

          if (chatIds.isEmpty) {
            chats.value = [];
            filteredChats.value = [];
            isLoading.value = false;
            return;
          }

          // Filter chatsData based on user participation
          final filteredChatsData = chatsData.where((chat) => chatIds.contains(chat['id'])).toList();

          List<Map<String, dynamic>> updatedChats = [];
          for (var chat in filteredChatsData) {
            // Fetch last message for each chat
            final lastMessageResponse = await supabase
                .from('chat_messages')
                .select('content, created_at')
                .eq('chat_id', chat['id'])
                .order('created_at', ascending: false)
                .limit(1)
                .maybeSingle();

            chat['last_message'] = lastMessageResponse?['content'] ?? 'No messages yet';
            chat['last_message_time'] = lastMessageResponse?['created_at'];

            // Fetch participants to determine if it's a private chat and get the other user's name if so
            if (chat['type'] == 'private') {
              final participants = await supabase
                  .from('chat_participants')
                  .select('user_id')
                  .eq('chat_id', chat['id']);

              if (participants.length == 2) {
                final otherUserId = participants.firstWhere((p) => p['user_id'] != userId)['user_id'];
                final otherUserProfile = await supabase
                    .from('profiles')
                    .select('display_name')
                    .eq('id', otherUserId)
                    .single();
                chat['name'] = otherUserProfile['display_name'] ?? 'Private Chat';
              } else {
                chat['name'] = 'Private Chat';
              }
            }

            updatedChats.add(chat);
          }

          // Filter out expired chats
          final now = DateTime.now().toUtc();
          updatedChats = updatedChats.where((chat) {
            final expiryTimeStr = chat['expiry_time'] as String?;
            if (expiryTimeStr == null) return true;
            final expiryTime = DateTime.parse(expiryTimeStr);
            return expiryTime.isAfter(now);
          }).toList();

          // Sort chats by last message time
          updatedChats.sort((a, b) {
            final timeA = a['last_message_time'] != null ? DateTime.parse(a['last_message_time']) : DateTime(1970);
            final timeB = b['last_message_time'] != null ? DateTime.parse(b['last_message_time']) : DateTime(1970);
            return timeB.compareTo(timeA);
          });

          chats.value = updatedChats;
          filteredChats.value = updatedChats;
          isLoading.value = false;
          errorMessage.value = null;
        } catch (e) {
          isLoading.value = false;
          errorMessage.value = "Failed to load chats: ${e.toString()}";
          print("Error fetching chat data: $e");
        }
      }, onError: (error) {
        isLoading.value = false;
        errorMessage.value = "Error listening to chats: ${error.toString()}";
        print("Error in chat stream: $error");
      });
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = "Failed to initialize: ${e.toString()}";
    }
  }

  String formatRemainingTime(String? expiryTimeString) {
    if (expiryTimeString == null) return 'Never expires';
    
    final expiryTime = DateTime.parse(expiryTimeString);
    final now = DateTime.now().toUtc();
    final difference = expiryTime.difference(now);
    
    if (difference.isNegative) return 'Expired';

    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;
    final seconds = difference.inSeconds % 60;

    if (days > 0) {
      return '$days day${days > 1 ? 's' : ''}, $hours hr${hours > 1 ? 's' : ''} left';
    } else if (hours > 0) {
      return '$hours hr${hours > 1 ? 's' : ''}, $minutes min${minutes > 1 ? 's' : ''} left';
    } else if (minutes > 0) {
      return '$minutes min${minutes > 1 ? 's' : ''}, $seconds sec${seconds > 1 ? 's' : ''} left';
    } else {
      return '$seconds sec${seconds > 1 ? 's' : ''} left';
    }
  }

  String formatLastMessageTime(String? timeString) {
    if (timeString == null) return '';
    try {
      final dateTime = DateTime.parse(timeString).toLocal();
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 0) {
        return '${dateTime.month}/${dateTime.day}';
      } else {
        return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return '';
    }
  }
} 