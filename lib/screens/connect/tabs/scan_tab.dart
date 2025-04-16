import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import '../../../services/supabase_service.dart';
import '../../message/message_details_screen.dart';

class ScanTab extends StatefulWidget {
  const ScanTab({super.key});

  @override
  State<ScanTab> createState() => _ScanTabState();
}

class _ScanTabState extends State<ScanTab> with WidgetsBindingObserver {
  final MobileScannerController cameraController = MobileScannerController();
  final ImagePicker _picker = ImagePicker();
  bool _hasScanned = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    cameraController.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    cameraController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      cameraController.start();
    } else {
      cameraController.stop();
    }
  }

  String _generateUniqueGroupName() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');
    
    return 'Crew-${month}${day}-${hour}${minute}';
  }

  Future<void> _createGroupAndJoin(String groupName, String userId, String creatorId) async {
    try {
      final currentUser = SupabaseService.client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final now = DateTime.now().toUtc();
      final expiryTime = now.add(const Duration(hours: 24));
      final expiryTimeStr = expiryTime.toIso8601String();


      // Insert into chat table
      final chatResponse = await SupabaseService.client
          .from('chats')
          .insert({
            'name': groupName,
            'type': 'group',
            'created_at': now.toIso8601String(),
            'created_by': currentUser.id,
            'expiry_time': expiryTimeStr,
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

      await SupabaseService.client
          .from('chat_participants')
          .insert({
            'user_id': creatorId,
            'chat_id': chatResponse['id'],
            'joined_at': now.toIso8601String(),
          });

      debugPrint('User added to group chat');
    } catch (e) {
      debugPrint('Error creating group chat: $e');
      rethrow;
    }
  }

  Future<void> _handleDetection(BarcodeCapture capture) async {
    if (_hasScanned) return; // Prevent multiple scans

    final List<Barcode> barcodes = capture.barcodes;
    debugPrint('Barcode detection: ${barcodes.length} barcodes found');
    
    for (final barcode in barcodes) {
      if (barcode.rawValue == null) {
        debugPrint('Warning: Barcode with null raw value found');
        continue;
      }

      try {
        debugPrint('Processing barcode: ${barcode.rawValue}');
        final uri = Uri.parse(barcode.rawValue!);
        
        if (uri.scheme != 'crewtap') {
          debugPrint('Error: Invalid QR code format');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid QR code format'),
              backgroundColor: Colors.red,
            ),
          );
          continue;
        }

        // Handle group join QR codes
        if (uri.pathSegments[0] == 'join' && uri.pathSegments[1] == 'group') {
          final chatId = uri.pathSegments[2];
          final groupName = uri.pathSegments[3];
          
          await _joinGroup(chatId, groupName);
          return;
        }

        // Handle crew connection QR codes
        final groupName = uri.pathSegments[1];
        final creatorId = uri.pathSegments[2];
        final creatorName = uri.pathSegments.length > 3 ? uri.pathSegments[3] : 'Name';
        final creatorRole = uri.pathSegments.length > 4 ? uri.pathSegments[4] : 'Role';
        
        debugPrint('Decoded QR data - Group: $groupName, Creator: $creatorId, Name: $creatorName, Role: $creatorRole');

        setState(() {
          _hasScanned = true;
        });

        // Show dialog with creator's data from QR code
        _showUserDataDialog({
          'group_name': groupName,
          'creator_id': creatorId,
          'creator_name': creatorName,
          'role': creatorRole,
        });
        
      } catch (e) {
        debugPrint('Error processing QR code: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid QR code format'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _joinGroup(String chatId, String groupName) async {
    try {
      final currentUser = SupabaseService.client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Check if user is already in the group
      final existingParticipant = await SupabaseService.client
          .from('chat_participants')
          .select()
          .eq('chat_id', chatId)
          .eq('user_id', currentUser.id)
          .maybeSingle();

      if (existingParticipant != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('You are already a member of "$groupName"'),
              backgroundColor: Colors.blue,
            ),
          );
          // Navigate to the existing group chat
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MessageDetailsScreen(
                chatId: chatId,
                recipientName: groupName,
                recipientId: chatId, // Using chatId as recipientId for group chats
              ),
            ),
          );
        }
        return;
      }

      // Add user to chat participants
      await SupabaseService.client
          .from('chat_participants')
          .insert({
            'user_id': currentUser.id,
            'chat_id': chatId,
            'joined_at': DateTime.now().toIso8601String(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully joined the group "$groupName"!'),
            backgroundColor: Colors.green,
          ),
        );
        // Navigate to the newly joined group chat
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MessageDetailsScreen(
              chatId: chatId,
              recipientName: groupName,
              recipientId: chatId, // Using chatId as recipientId for group chats
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error joining group: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error joining group: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _hasScanned = false;
      });
      cameraController.start();
    }
  }

  void _showUserDataDialog(Map<String, dynamic> userData) {
    final TextEditingController groupNameController = TextEditingController(
      text: _generateUniqueGroupName(),
    );
    
    // Duration state
    String selectedDuration = '24 hours';
    final List<String> durations = ['24 hours', '48 hours', '72 hours'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text(
            'QR Code Detected',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Connect with ${userData['creator_name']} (${userData['role']})',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
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
                setState(() {
                  _hasScanned = false;
                });
                cameraController.start();
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
                    userData['creator_id'],
                    userData['creator_id'],
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
                  setState(() {
                    _hasScanned = false;
                  });
                  cameraController.start();
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
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      setState(() {
        _isProcessing = true;
      });

      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) {
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      // Process the picked image using MobileScanner
      final result = await cameraController.stop();
      await cameraController.start();
      await cameraController.analyzeImage(image.path);

      // The result will come through the normal onDetect callback
      // We don't need to process it here
      
    } catch (e) {
      debugPrint('Error processing image: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error processing image'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MobileScanner(
          controller: cameraController,
          onDetect: _handleDetection,
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
          ),
          child: Stack(
            children: [
              Center(
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              Positioned(
                bottom: 80,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    const Text(
                      'Align QR code within the frame',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _pickImage,
                      icon: _isProcessing 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.image),
                      label: Text(_isProcessing ? 'Processing...' : 'Upload QR Image'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
} 