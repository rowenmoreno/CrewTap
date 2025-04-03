import 'package:flutter/material.dart';
import 'tabs/my_qr_tab.dart';
import 'tabs/scan_tab.dart';
import 'tabs/tap_tab.dart';
import '../../services/supabase_service.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  int _selectedIndex = 0;
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final user = SupabaseService.client.auth.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      final profileResponse = await SupabaseService.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      if (profileResponse == null) {
        throw Exception('Profile not found');
      }

      setState(() {
        _userProfile = profileResponse;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
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
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          MyQRTab(
            userId: SupabaseService.client.auth.currentUser!.id,
            displayName: _userProfile?['display_name'] ?? "Name",
            position: _userProfile?['position'] ?? "Role",
          ),
          ScanTab(isActive: _selectedIndex == 1),
          TapTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code),
            label: 'My QR',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Scan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.tap_and_play),
            label: 'Tap',
          ),
        ],
      ),
    );
  }
} 