import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:image_picker/image_picker.dart';
import '../../../services/supabase_service.dart';

class ScanTab extends StatefulWidget {
  const ScanTab({super.key, required this.isActive});

  final bool isActive;

  @override
  State<ScanTab> createState() => _ScanTabState();
}

class _ScanTabState extends State<ScanTab> {
  final MobileScannerController cameraController = MobileScannerController();
  final ImagePicker _picker = ImagePicker();
  bool _hasScanned = false;
  bool _isProcessing = false;
  String? _errorMessage;
  bool _hasError = false;
  Map<String, dynamic>? _scannedData;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ScanTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        cameraController.start();
        setState(() {
          _hasScanned = false;
        });
      } else {
        cameraController.stop();
      }
    }
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
        
        if (uri.scheme != 'crewlink' || uri.host != 'join' || uri.pathSegments[0] != 'group') {
          debugPrint('Error: Invalid QR code format');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid QR code format'),
              backgroundColor: Colors.red,
            ),
          );
          continue;
        }

        final groupName = uri.pathSegments[1];
        final creatorId = uri.pathSegments[2];
        debugPrint('Decoded QR data - Group: $groupName, Creator: $creatorId');

        setState(() {
          _hasScanned = true;
        });

        // Fetch creator's profile
        try {
          final profileResponse = await SupabaseService.client
              .from('profiles')
              .select()
              .eq('id', creatorId)
              .single();

          if (profileResponse == null) {
            throw Exception('Creator profile not found');
          }

          debugPrint('Creator profile found: $profileResponse');

          // Show dialog with creator's profile data
          _showUserDataDialog({
            'group_name': groupName,
            'creator_id': creatorId,
            'creator_name': profileResponse['display_name'] ?? 'Unknown',
            'role': profileResponse['position'] ?? 'Unknown',
          });
        } catch (e) {
          debugPrint('Error fetching creator profile: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error fetching creator profile'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _hasScanned = false;
          });
        }
        
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

  void _showUserDataDialog(Map<String, dynamic> userData) {
    final TextEditingController groupNameController = TextEditingController(
      text: 'Connection with ${userData['creator_name']}',
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
      developer.log('Error processing image', name: 'ScanTab', error: e.toString());
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

  Future<void> _processQRCode(String? qrData) async {
    if (qrData == null) {
      setState(() {
        _errorMessage = 'No QR code data found';
        _hasError = true;
      });
      return;
    }

    try {
      // Parse the URL format: crewlink://join/group/{group_name}/{creator_id}
      final uri = Uri.parse(qrData);
      if (uri.scheme != 'crewlink') {
        print(uri.scheme);
        throw Exception('Invalid QR code format');
      }

      final groupName = uri.pathSegments[1];
      final creatorId = uri.pathSegments[2];

      // Fetch creator's profile from Supabase
      final profileResponse = await SupabaseService.client
          .from('profiles')
          .select()
          .eq('id', creatorId)
          .single();

      if (profileResponse == null) {
        throw Exception('Creator profile not found');
      }

      setState(() {
        _scannedData = {
          'group_name': groupName,
          'creator_id': creatorId,
          'creator_name': profileResponse['display_name'] ?? 'Unknown',
          'creator_email': profileResponse['email'] ?? 'Unknown',
        };
        _hasError = false;
      });
    } catch (e) {
      debugPrint('Error processing QR code: $e');
      setState(() {
        _errorMessage = e.toString();
        _hasError = true;
      });
    }
  }

  void _showResultDialog() {
    if (_scannedData == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Group Name: ${_scannedData!['group_name']}'),
            const SizedBox(height: 8),
            Text('Created by: ${_scannedData!['creator_name']}'),
            Text('Email: ${_scannedData!['creator_email']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetScan();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement group joining logic
              Navigator.pop(context);
              _resetScan();
            },
            child: const Text('Join Group'),
          ),
        ],
      ),
    );
  }

  void _resetScan() {
    setState(() {
      _hasScanned = false;
      _errorMessage = null;
      _hasError = false;
      _scannedData = null;
    });
  }

  Future<void> _onBarcodeDetect(List<Barcode> barcodes) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      if (barcodes.isNotEmpty) {
        final qrData = barcodes.first.rawValue;
        await _processQRCode(qrData);
        if (!_hasError) {
          _showResultDialog();
        }
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        MobileScanner(
          controller: cameraController,
          onDetect: _handleDetection,
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
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