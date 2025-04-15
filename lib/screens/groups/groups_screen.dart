import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'controller/groups_controller.dart';
import '../message/message_details_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  @override
  Widget build(BuildContext context) {
    final controller = Get.put(GroupsController());

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
            child: TextField(
              onChanged: (value) => controller.searchQuery.value = value,
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
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (controller.errorMessage.value.isNotEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Error: ${controller.errorMessage.value}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  ),
                );
              }
              
              if (controller.filteredJoinedGroups.isEmpty && controller.filteredAvailableGroups.isEmpty) {
                return _buildEmptyState(controller);
              }
              
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (controller.filteredJoinedGroups.isNotEmpty) ...[
                    const Text(
                      'Joined Groups',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.1,
                      children: controller.filteredJoinedGroups.map((group) => _buildGroupCard(
                        group['name'] ?? 'Group Chat',
                        group['member_count'] ?? 0,
                        controller.formatRemainingTime(group['expiry_time']),
                        group,
                        isJoined: true,
                      )).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],
                  // if (controller.filteredAvailableGroups.isNotEmpty) ...[
                  //   const Text(
                  //     'Available Groups',
                  //     style: TextStyle(
                  //       fontSize: 18,
                  //       fontWeight: FontWeight.bold,
                  //     ),
                  //   ),
                  //   const SizedBox(height: 16),
                  //   GridView.count(
                  //     shrinkWrap: true,
                  //     physics: const NeverScrollableScrollPhysics(),
                  //     crossAxisCount: 2,
                  //     mainAxisSpacing: 16,
                  //     crossAxisSpacing: 16,
                  //     childAspectRatio: 1.1,
                  //     children: controller.filteredAvailableGroups.map((group) => _buildGroupCard(
                  //       group['name'] ?? 'Group Chat',
                  //       group['member_count'] ?? 0,
                  //       controller.formatRemainingTime(group['expiry_time']),
                  //       group,
                  //       isJoined: false,
                  //     )).toList(),
                  //   ),
                  // ],
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(GroupsController controller) {
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

  Widget _buildGroupCard(String name, int members, String timeLeft, Map<String, dynamic> group, {required bool isJoined}) {
    return GestureDetector(
      onTap: () {
        if (isJoined) {
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
              Get.find<GroupsController>().initializeGroups(refresh: true);
            }
          });
        } else {
          // Show join group dialog
          showDialog(
            context:context,
            builder: (context) => AlertDialog(
              title: const Text('Join Group'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Group: $name'),
                  Text('Members: $members'),
                  Text('Time left: $timeLeft'),
                  const SizedBox(height: 16),
                  const Text('Would you like to join this group?'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Get.find<GroupsController>().joinGroup(group['id']);
                  },
                  child: const Text('Join'),
                ),
              ],
            ),
          );
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
              if (!isJoined) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Join',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
} 