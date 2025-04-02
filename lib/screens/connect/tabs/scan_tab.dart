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

  void _handleDetection(BarcodeCapture capture) {
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
        
        if (uri.scheme != 'crewlink') {
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

        _showUserDataDialog({
          'group_name': groupName,
          'creator_id': creatorId,
        });

        cameraController.start();
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You\'ve been added to a new temporary group.'),
        backgroundColor: Colors.green,
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