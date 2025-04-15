import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/supabase_service.dart';
import 'dart:async';
import 'package:intl/intl.dart';

class GroupsController extends GetxController {
  final _supabase = SupabaseService.client;
  StreamSubscription<List<Map<String, dynamic>>>? _groupsSubscription;
  
  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;
  final RxList<Map<String, dynamic>> joinedGroups = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> availableGroups = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> filteredJoinedGroups = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> filteredAvailableGroups = <Map<String, dynamic>>[].obs;
  final RxString searchQuery = ''.obs;

  @override
  void onInit() {
    super.onInit();
    initializeGroups();
    ever(searchQuery, _filterGroups);
  }

  @override
  void onClose() {
    _groupsSubscription?.cancel();
    super.onClose();
  }

  void _filterGroups(String query) {
    if (query.isEmpty) {
      filteredJoinedGroups.value = joinedGroups;
      filteredAvailableGroups.value = availableGroups;
      return;
    }

    final lowercaseQuery = query.toLowerCase();
    filteredJoinedGroups.value = joinedGroups.where((group) {
      final groupName = (group['name'] ?? '').toString().toLowerCase();
      return groupName.contains(lowercaseQuery);
    }).toList();

    filteredAvailableGroups.value = availableGroups.where((group) {
      final groupName = (group['name'] ?? '').toString().toLowerCase();
      return groupName.contains(lowercaseQuery);
    }).toList();
  }

  Future<void> joinGroup(String groupId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase.from('chat_participants').insert({
        'chat_id': groupId,
        'user_id': userId,
      });

      // Refresh groups after joining
      await initializeGroups(refresh: true);
    } catch (e) {
      errorMessage.value = "Failed to join group: ${e.toString()}";
    }
  }

  Future<void> initializeGroups({bool refresh = false}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      isLoading.value = false;
      errorMessage.value = "User not logged in.";
      return;
    }

    if (!refresh) {
      isLoading.value = true;
    }

    try {
      // Get user's group chats
      final userGroups = await _supabase
          .from('chat_participants')
          .select('chat_id')
          .eq('user_id', userId);

      final joinedGroupIds = userGroups.map((g) => g['chat_id'] as String).toList();

      // Listen for real-time changes in group chats
      final groupsStream = _supabase
          .from('chats')
          .stream(primaryKey: ['id'])
          .eq('type', 'group')
          .order('created_at', ascending: false);

      _groupsSubscription?.cancel();
      _groupsSubscription = groupsStream.listen((groupsData) async {
        List<Map<String, dynamic>> updatedJoinedGroups = [];
        List<Map<String, dynamic>> updatedAvailableGroups = [];

        for (var group in groupsData) {
          // Get participant count
          final participants = await _supabase
              .from('chat_participants')
              .select('user_id')
              .eq('chat_id', group['id']);

          group['member_count'] = participants.length;

          // Get last message
          // final lastMessageResponse = await _supabase
          //     .from('chat_messages')
          //     .select('content, created_at')
          //     .eq('chat_id', group['id'])
          //     .order('created_at', ascending: false)
          //     .limit(1)
          //     .maybeSingle();

          // group['last_message'] = lastMessageResponse?['content'] ?? 'No messages yet';
          // group['last_message_time'] = lastMessageResponse?['created_at'];

          // Check if group is expired
          final now = DateTime.now();
          final expiryTimeStr = group['expiry_time'] as String?;
          final expiryTime = expiryTimeStr != null ? DateTime.tryParse(expiryTimeStr) : null;
          final isExpired = expiryTime != null && expiryTime.isBefore(now);

          if (!isExpired) {
            if (joinedGroupIds.contains(group['id'])) {
              updatedJoinedGroups.add(group);
            } else {
              updatedAvailableGroups.add(group);
            }
          }
        }

        joinedGroups.value = updatedJoinedGroups;
        availableGroups.value = updatedAvailableGroups;
        _filterGroups(searchQuery.value);
        isLoading.value = false;
        errorMessage.value = '';
      }, onError: (error) {
        isLoading.value = false;
        errorMessage.value = "Error listening to groups: ${error.toString()}";
      });
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = "Failed to load groups: ${e.toString()}";
    }
  }

  String formatRemainingTime(String? expiryTimeString) {
    if (expiryTimeString == null) {
      return 'Never expires';
    }
    final expiryTime = DateTime.tryParse(expiryTimeString);
    if (expiryTime == null) {
      return 'Invalid date';
    }

    final now = DateTime.now();
    final difference = expiryTime.difference(now);

    if (difference.isNegative) {
      return 'Expired';
    }

    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;

    if (days > 0) {
      return '$days day${days > 1 ? 's' : ''} left';
    } else if (hours > 0) {
      return '$hours hr${hours > 1 ? 's' : ''} left';
    } else {
      return '$minutes min${minutes > 1 ? 's' : ''} left';
    }
  }
} 