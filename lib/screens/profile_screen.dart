import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const CircleAvatar(
            radius: 50,
            child: Icon(Icons.person, size: 50),
          ),
          const SizedBox(height: 16),
          const Text(
            'John Doe',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'john.doe@example.com',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Edit Profile'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notifications'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Privacy'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help & Support'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () {},
          ),
        ],
      ),
    );
  }
} 