import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'message_details_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _groups = [];
  final _supabase = SupabaseService.client;
  StreamSubscription<List<Map<String, dynamic>>>? _groupsSubscription;

  @override
  void initState() {
    super.initState();
    _initializeGroupsScreen();
  }

  @override
  void dispose() {
    _groupsSubscription?.cancel();
    super.dispose();
  }

  void _initializeGroupsScreen({bool refresh = false}) {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = "User not logged in.";
      });
      return;
    }

    // Listen for real-time changes in group chats
    final groupsStream = _supabase
        .from('chats')
        .stream(primaryKey: ['id'])
        .eq('type', 'group')
        .order('created_at', ascending: false);

    _groupsSubscription = groupsStream.listen((groupsData) async {
      if (!mounted) return;
      setState(() {
        if (!refresh) {
          _isLoading = true;
        }
      });

      try {
        // Get user's group chats
        final userGroups = await _supabase
            .from('chat_participants')
            .select('chat_id')
            .eq('user_id', userId);

        final groupIds = userGroups.map((g) => g['chat_id'] as String).toList();

        if (groupIds.isEmpty) {
          setState(() {
            _groups = [];
            _isLoading = false;
          });
          return;
        }

        // Filter groupsData based on user participation
        final filteredGroupsData = groupsData.where((group) => groupIds.contains(group['id'])).toList();

        List<Map<String, dynamic>> updatedGroups = [];
        for (var group in filteredGroupsData) {
          // Get participant count
          final participants = await _supabase
              .from('chat_participants')
              .select('user_id')
              .eq('chat_id', group['id']);

          group['member_count'] = participants.length;

          // Get last message
          final lastMessageResponse = await _supabase
              .from('chat_messages')
              .select('content, created_at')
              .eq('chat_id', group['id'])
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();

          group['last_message'] = lastMessageResponse?['content'] ?? 'No messages yet';
          group['last_message_time'] = lastMessageResponse?['created_at'];

          updatedGroups.add(group);
        }

        // Filter out expired groups
        final now = DateTime.now();
        updatedGroups = updatedGroups.where((group) {
          final expiryTimeStr = group['expiry_time'] as String?;
          if (expiryTimeStr == null) return true; // Never expires
          final expiryTime = DateTime.tryParse(expiryTimeStr);
          return expiryTime != null && expiryTime.isAfter(now);
        }).toList();

        setState(() {
          _groups = updatedGroups;
          _isLoading = false;
          _errorMessage = null;
        });
      } catch (e) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Failed to load groups: ${e.toString()}";
        });
      }
    }, onError: (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Error listening to groups: ${error.toString()}";
        });
      }
    });
  }

  String _formatRemainingTime(String? expiryTimeString) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search groups',
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
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.tune),
                  onPressed: () {},
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Error: $_errorMessage',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.red[700]),
                          ),
                        ),
                      )
                    : _groups.isEmpty
                        ? _buildEmptyState()
                        : GridView.count(
                            crossAxisCount: 2,
                            padding: const EdgeInsets.all(16),
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 1.1,
                            children: _groups.map((group) => _buildGroupCard(
                              group['name'] ?? 'Group Chat',
                              group['member_count'] ?? 0,
                              _formatRemainingTime(group['expiry_time']),
                            )).toList(),
                          ),
          ),
        ],
      ),
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
              Icons.group_outlined,
              color: Colors.grey[400],
              size: 24,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No groups yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Scan a QR code or tap a device to\njoin a group',
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

  Widget _buildGroupCard(String name, int members, String timeLeft) {
    return GestureDetector(
      onTap: () {
        // Find the group data that matches this card
        final group = _groups.firstWhere(
          (g) => g['name'] == name,
          orElse: () => {},
        );
        
        if (group.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MessageDetailsScreen(
                chatId: group['id'],
                recipientName: name,
                recipientId: '', // Empty for group chats
              ),
            ),
          ).then((result) {
            // Refresh the groups list when returning from chat
            if (result == true) {
              _initializeGroupsScreen(refresh: true);
            }
          });
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    timeLeft,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(
                    Icons.group_outlined,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$members members',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Join Group',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 