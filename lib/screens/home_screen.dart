import 'package:flutter/material.dart';
import 'dart:math';
import '../services/supabase_service.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _userInitials = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) return;

      final profile = await SupabaseService.getProfile(user.id);
      if (profile != null && mounted) {
        final displayName = profile['display_name'] ?? 'User';
        setState(() {
          _userInitials = _getInitials(displayName);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, min(2, name.length)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            // Image.asset(
            //   'assets/images/logo.png',
            //   height: 24,
            // ),
            // const SizedBox(width: 8),
            const Text('Home'),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            offset: const Offset(0, 40),
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: CircleAvatar(
                backgroundColor: Colors.grey[200],
                child: Text(_userInitials),
              ),
            ),
            onSelected: (value) async {
              if (value == 'profile') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                ).then((_) => _loadUserProfile());
              } else if (value == 'logout') {
                await SupabaseService.client.auth.signOut();
                if (mounted) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline),
                    SizedBox(width: 8),
                    Text('View Profile'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Crew Members',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: const [
              CrewMemberTile(
                initials: 'Jo',
                name: 'John S.',
                color: Colors.yellow,
                isOnline: true,
              ),
              CrewMemberTile(
                initials: 'Ma',
                name: 'Maria R.',
                color: Colors.purple,
                isOnline: false,
              ),
              CrewMemberTile(
                initials: 'Al',
                name: 'Alex Ch.',
                color: Colors.pink,
                isOnline: false,
              ),
              CrewMemberTile(
                initials: 'Sa',
                name: 'Sarah J.',
                color: Colors.blue,
                isOnline: true,
              ),
              CrewMemberTile(
                initials: 'Mi',
                name: 'Mike T.',
                color: Colors.green,
                isOnline: true,
              ),
              CrewMemberTile(
                initials: 'Pr',
                name: 'Priya P.',
                color: Colors.orange,
                isOnline: true,
              ),
              CrewMemberTile(
                initials: 'Da',
                name: 'David',
                color: Colors.teal,
                isOnline: false,
              ),
              CrewMemberTile(
                initials: 'Em',
                name: 'Emma',
                color: Colors.purple,
                isOnline: false,
              ),
              CrewMemberTile(
                initials: 'Ca',
                name: 'Carlos',
                color: Colors.pink,
                isOnline: false,
              ),
              CrewMemberTile(
                initials: 'Ai',
                name: 'Aisha K.',
                color: Colors.indigo,
                isOnline: true,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Group Chat',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '23h 59m',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const ChatMessage(
            message: 'Good morning team! Pre-flight briefing in 30 minutes.',
            time: '12:56 PM',
            isCurrentUser: true,
          ),
          const ChatMessage(
            sender: 'Maria Rodriguez',
            message: "Roger that, I'll be there.",
            time: '01:06 PM',
            isCurrentUser: false,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Leave Group'),
          ),
          const SizedBox(height: 16),
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
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: Colors.blue[300],
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CrewMemberTile extends StatelessWidget {
  final String initials;
  final String name;
  final Color color;
  final bool isOnline;

  const CrewMemberTile({
    super.key,
    required this.initials,
    required this.name,
    required this.color,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withOpacity(0.2),
              child: Text(
                initials,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (isOnline)
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
          name,
          style: const TextStyle(
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class ChatMessage extends StatelessWidget {
  final String? sender;
  final String message;
  final String time;
  final bool isCurrentUser;

  const ChatMessage({
    super.key,
    this.sender,
    required this.message,
    required this.time,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment:
            isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isCurrentUser && sender != null)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 4),
              child: Text(
                sender!,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isCurrentUser ? Colors.blue[900] : Colors.blue[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    color: isCurrentUser ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 12,
                    color: isCurrentUser ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 