import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/supabase_service.dart';
import '../../../services/nfc_service.dart';
import 'dart:developer' as developer;

class TapTab extends StatefulWidget {
  const TapTab({
    super.key,
    required this.userId,
    required this.displayName,
    required this.position,
  });

  final String userId;
  final String displayName;
  final String position;

  @override
  State<TapTab> createState() => _TapTabState();
}

class _TapTabState extends State<TapTab> {
  bool _isNfcAvailable = false;
  bool _isNfcSessionStarted = false;
  bool _isPeerDetected = false;

  @override
  void initState() {
    super.initState();
    _checkNfcAvailability();
  }

  @override
  void dispose() {
    if (_isNfcSessionStarted) {
      NFCService.stopNFCSession();
    }
    super.dispose();
  }

  Future<void> _checkNfcAvailability() async {
    bool isAvailable = await NFCService.isNFCAvailable();
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
      _isPeerDetected = false;
    });

    try {
      final tagId = await NFCService.scanNFCTag();
      if (tagId != null) {
        // Parse the tag ID to extract group information
        // The tag ID should be in the format: crewtap://join/group/{groupName}/{creatorId}/{creatorName}/{creatorRole}
        final uri = Uri.parse(tagId);
        if (uri.scheme == 'crewtap' && uri.host == 'join' && uri.pathSegments[0] == 'group') {
          final groupName = uri.pathSegments[1];
          final creatorId = uri.pathSegments[2];
          final creatorName = uri.pathSegments.length > 3 ? uri.pathSegments[3] : 'Name';
          final creatorRole = uri.pathSegments.length > 4 ? uri.pathSegments[4] : 'Role';

          debugPrint('Decoded NFC data - Group: $groupName, Creator: $creatorId, Name: $creatorName, Role: $creatorRole');

          if (!mounted) return;
          
          // Show peer detection dialog
          _showPeerDetectedDialog({
            'group_name': groupName,
            'creator_id': creatorId,
            'creator_name': creatorName,
            'role': creatorRole,
          });
        } else {
          _showMessage('Invalid NFC tag format');
        }
      }
    } catch (e) {
      _showMessage('Error reading NFC tag: ${e.toString()}');
    } finally {
      setState(() {
        _isNfcSessionStarted = false;
      });
    }
  }

  void _showPeerDetectedDialog(Map<String, dynamic> peerData) {
    if (!mounted) return;
    
    final TextEditingController groupNameController = TextEditingController(
      text: 'Connection with ${peerData['creator_name']}',
    );
    
    // Duration state
    String selectedDuration = '24 hours';
    final List<String> durations = ['24 hours', '48 hours', '72 hours'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Peer Detected'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Name: ${peerData['creator_name']}'),
              Text('Role: ${peerData['role']}'),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Group Name',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: groupNameController,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Colors.grey[300]!,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Colors.grey[300]!,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Duration',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 0,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.grey[300]!,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: selectedDuration,
                      isExpanded: true,
                      underline: const SizedBox(),
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                      items: durations.map((String duration) {
                        return DropdownMenuItem<String>(
                          value: duration,
                          child: Text(duration),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            selectedDuration = newValue;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _startNfcSession();
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey[700],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  // Convert duration string to hours
                  final hours = int.parse(selectedDuration.split(' ')[0]);
                  await _createGroupAndJoin(
                    groupNameController.text,
                    peerData['creator_id'],
                    hours,
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Successfully joined the group!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error joining group: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } finally {
                  _startNfcSession();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Create Connection'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createGroupAndJoin(String groupName, String creatorId, int durationHours) async {
    try {
      debugPrint('Creating group chat: $groupName with duration: $durationHours hours');
      
      // Get current user's ID
      final currentUser = SupabaseService.client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Calculate expiry time based on selected duration
      final now = DateTime.now();
      final expiryTime = now.add(Duration(hours: durationHours));

      // Insert into chat table
      final chatResponse = await SupabaseService.client
          .from('chats')
          .insert({
            'name': groupName,
            'type': 'group',
            'created_at': now.toIso8601String(),
            'created_by': currentUser.id,
            'expiry_time': expiryTime.toIso8601String(),
          })
          .select()
          .single();

      if (chatResponse == null) {
        throw Exception('Failed to create group chat');
      }

      debugPrint('Group chat created: ${chatResponse['id']}');

      // Add current user as participant
      await SupabaseService.client
          .from('chat_participants')
          .insert({
            'user_id': currentUser.id,
            'chat_id': chatResponse['id'],
            'joined_at': now.toIso8601String(),
          });

      debugPrint('User added to group chat');
    } catch (e) {
      debugPrint('Error creating group chat: $e');
      rethrow;
    }
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

  @override
  Widget build(BuildContext context) {
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
              'NFC active. Hold your phone near another\nCrewTap device to connect.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            TextButton(
              onPressed: () {
                NFCService.stopNFCSession();
                setState(() {
                  _isNfcSessionStarted = false;
                });
              },
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
                    widget.displayName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.position,
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