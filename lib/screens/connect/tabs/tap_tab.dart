import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/supabase_service.dart';
import 'dart:developer' as developer;
import 'package:nfc_manager/nfc_manager.dart';
import 'dart:convert';

class TapTab extends StatefulWidget {
  const TapTab({super.key});

  @override
  State<TapTab> createState() => _TapTabState();
}

class _TapTabState extends State<TapTab> {
  Map<String, dynamic>? userData;
  Map<String, dynamic>? userProfile;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isNfcAvailable = false;
  bool _isNfcSessionStarted = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkNfcAvailability();
  }

  @override
  void dispose() {
    if (_isNfcSessionStarted) {
      NfcManager.instance.stopSession();
    }
    super.dispose();
  }

  Future<void> _checkNfcAvailability() async {
    bool isAvailable = await NfcManager.instance.isAvailable();
    setState(() {
      _isNfcAvailable = isAvailable;
    });
  }

  Future<void> _startNfcSession() async {
    if (!_isNfcAvailable) {
      _showMessage('NFC is not available on this device');
      return;
    }

    setState(() {
      _isNfcSessionStarted = true;
    });

    try {
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          try {
            var ndef = Ndef.from(tag);
            if (ndef == null) {
              _showMessage('This NFC tag is not NDEF formatted');
              return;
            }

            var message = await ndef.read();
            if (message == null) {
              _showMessage('No data found on this NFC tag');
              return;
            }

            var record = message.records.first;
            if (record.typeNameFormat != NdefTypeNameFormat.nfcWellknown ||
                record.type.length != 1 ||
                record.type.first != 0x54) {
              _showMessage('Invalid NFC data format');
              return;
            }

            var text = String.fromCharCodes(record.payload);
            try {
              final userData = jsonDecode(text);
              if (!mounted) return;
              _showUserDataDialog(userData);
            } catch (e) {
              _showMessage('Invalid data format');
            }
          } catch (e) {
            _showMessage('Error reading NFC tag: ${e.toString()}');
          }
        },
        onError: (error) {
          _showMessage('NFC Error: ${error.toString()}');
          throw error;
        },
      );
    } catch (e) {
      _showMessage('Failed to start NFC session: ${e.toString()}');
    }
  }

  void _stopNfcSession() {
    NfcManager.instance.stopSession();
    setState(() {
      _isNfcSessionStarted = false;
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showUserDataDialog(Map<String, dynamic> userData) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Crew Member Found'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              userData['display_name'] ?? 'No Name Set',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              userData['email'] ?? '',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${userData['role']} • ${userData['company']}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _stopNfcSession();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement connection request
              Navigator.pop(context);
              _stopNfcSession();
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadUserData() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
        return;
      }

      // Get user profile data
      final profile = await SupabaseService.getProfile(currentUser.id);
      setState(() {
        userProfile = profile;
      });

      // Prepare user data
      setState(() {
        userData = {
          'id': currentUser.id,
          'email': currentUser.email,
          'display_name': profile?['display_name'] ?? 'No Name Set',
          'role': profile?['role'] ?? 'Role',
          'company': profile?['company'] ?? 'Company',
        };
        _isLoading = false;
      });
    } catch (e) {
      developer.log('Error loading user data', name: 'TapTab', error: e.toString());
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Failed to load user data',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadUserData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (userData == null) {
      return const Center(
        child: Text('No user data available'),
      );
    }

    if (!_isNfcAvailable) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.wifi_off,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'NFC is not available on this device',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    if (_isNfcSessionStarted) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.blue,
                  width: 2,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.nfc_rounded,
                  size: 80,
                  color: Colors.blue,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'NFC active. Hold your phone near another\nCrewLink device to connect.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            TextButton(
              onPressed: _stopNfcSession,
              child: const Text(
                'Turn Off NFC',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.touch_app,
                    size: 64,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    userData!['display_name'] ?? 'No Name Set',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    userData!['email'] ?? '',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${userData!['role']} • ${userData!['company']}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Tap your phone against another device\nto connect with crew.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _startNfcSession,
              icon: const Icon(Icons.nfc),
              label: const Text('Start NFC Connection'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 