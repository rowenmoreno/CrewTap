import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'connect/connect_screen.dart';
import 'messages_screen.dart';
import 'groups_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = [
    ProfileScreen(),
    MessagesScreen(),
    HomeScreen(),
    ConnectScreen(),
    GroupsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
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