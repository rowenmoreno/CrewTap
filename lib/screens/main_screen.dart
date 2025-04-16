import 'package:flutter/material.dart';
import 'dashboard/dashboard_screen.dart';
import 'connect/connect_screen.dart';
import 'message/message_list/messages_screen.dart';
import 'groups/groups_screen.dart';
import 'profile/profile_screen.dart';
import 'profile/edit_profile_screen.dart';
import '../services/supabase_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 2;
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _userProfile;

  static const List<Widget> _screens = [
    ProfileScreen(),
    MessagesScreen(),
    DashboardScreen(),
    ConnectScreen(),
    GroupsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final user = SupabaseService.client.auth.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      final profile = await SupabaseService.getProfile(user.id);
      if (profile != null) {
        setState(() {
          _userProfile = profile;
          _isLoading = false;
        });

        // Check if display name is "New User" and redirect to edit profile
        if ((profile['display_name'] == 'New User' || profile['display_name'] == '') && mounted) {
          // Use a small delay to ensure the widget is fully mounted
          Future.delayed(Duration.zero, () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const EditProfileScreen(),
              ),
            );
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                'Error: $_errorMessage',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadUserProfile,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
          NavigationDestination(
            icon: Icon(Icons.message),
            label: 'Messages',
          ),
          NavigationDestination(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Connect',
          ),
          NavigationDestination(
            icon: Icon(Icons.group),
            label: 'Groups',
          ),
        ],
      ),
    );
  }
} 