import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/supabase_service.dart';
import 'dart:async';

class GroupsController extends GetxController {
  final _supabase = SupabaseService.client;
  final TextEditingController groupNameController = TextEditingController();
  final searchQuery = ''.obs;
  final isLoading = false.obs;
  final errorMessage = ''.obs;
  final selectedDuration = '24 hours'.obs;
  final selectedMembers = <Map<String, dynamic>>[].obs;
  final joinedGroups = <Map<String, dynamic>>[].obs;
  final availableGroups = <Map<String, dynamic>>[].obs;
  RxList filteredJoinedGroups = <Map<String, dynamic>>[].obs;
  RxList filteredAvailableGroups = <Map<String, dynamic>>[].obs;
  
  final durations = ['24 hours', '48 hours', '72 hours'];
  StreamSubscription<List<Map<String, dynamic>>>? _groupsSubscription;

  @override
  void onInit() async {
    super.onInit();
    await initializeGroups();
    ever(searchQuery, _filterGroups);
    _filterGroups(searchQuery.value);
  }

  @override
  void onClose() {
    groupNameController.dispose();
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

  Future<void> initializeGroups({bool refresh = false}) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      // Get joined groups
      final joinedGroupsResponse = await _supabase
          .from('chats')
          .select('*, chat_participants!inner(*)')
          .eq('chat_participants.user_id', currentUser.id)
          .eq('type', 'group')
          .order('created_at', ascending: false);

      // Filter out expired groups and add member count
      final now = DateTime.now().toUtc();
      final filteredGroups = joinedGroupsResponse.where((group) {
        final expiryTime = group['expiry_time'] as String?;
        if (expiryTime == null) return false;
        final expiry = DateTime.parse(expiryTime);
        return expiry.isAfter(now);
      }).toList();

      // Get member counts for each group
      final groupsWithCounts = await Future.wait(
        filteredGroups.map((group) async {
          final memberCountResponse = await _supabase
              .from('chat_participants')
              .select('count')
              .eq('chat_id', group['id'])
              .single();
              
          return {
            ...group,
            'member_count': memberCountResponse['count'] ?? 0,
          };
        }),
      );

      joinedGroups.value = groupsWithCounts;
      isLoading.value = false;
    } catch (e) {
      print('Error loading groups: $e');
      errorMessage.value = e.toString();
      isLoading.value = false;
    }
  }

  Future<void> createGroup() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return;

      final now = DateTime.now().toUtc();
      final hours = int.parse(selectedDuration.value.split(' ')[0]);
      final expiryTime = now.add(Duration(hours: hours));
      final expiryTimeStr = expiryTime.toIso8601String();

      // Create the group chat
      final chatResponse = await _supabase
          .from('chats')
          .insert({
            'name': groupNameController.text.trim(),
            'type': 'group',
            'created_at': now.toIso8601String(),
            'created_by': currentUser.id,
            'expiry_time': expiryTimeStr,
          })
          .select()
          .single();

      // Add all participants
      final participants = [
        {'user_id': currentUser.id, 'chat_id': chatResponse['id']},
        ...selectedMembers.map((member) => {
          'user_id': member['id'],
          'chat_id': chatResponse['id'],
        }),
      ];

      await _supabase.from('chat_participants').insert(participants);

      // Clear form
      groupNameController.clear();
      selectedMembers.clear();
      selectedDuration.value = '24 hours';

      // Refresh groups list
      await initializeGroups(refresh: true);
    } catch (e) {
      print('Error creating group: $e');
      errorMessage.value = e.toString();
    }
  }

  Future<void> joinGroup(String groupId) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return;

      await _supabase.from('chat_participants').insert({
        'user_id': currentUser.id,
        'chat_id': groupId,
      });

      await initializeGroups(refresh: true);
    } catch (e) {
      print('Error joining group: $e');
      errorMessage.value = e.toString();
    }
  }

  String formatRemainingTime(String? expiryTime) {
    if (expiryTime == null) return 'Expired';
    
    final expiry = DateTime.parse(expiryTime);
    final now = DateTime.now().toUtc();
    final difference = expiry.difference(now);
    
    if (difference.isNegative) return 'Expired';
    
    final hours = difference.inHours;
    final minutes = difference.inMinutes % 60;
    
    if (hours > 0) {
      return '$hours h ${minutes}m left';
    } else {
      return '$minutes min left';
    }
  }
} 