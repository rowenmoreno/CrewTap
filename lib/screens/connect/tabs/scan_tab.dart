import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:image_picker/image_picker.dart';

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
    
    for (final barcode in barcodes) {
      if (barcode.rawValue == null) continue;

      try {
        final userData = jsonDecode(barcode.rawValue!);
        developer.log('QR Code scanned', 
            name: 'ScanTab',
            error: 'Data: ${userData.toString()}');

        setState(() {
          _hasScanned = true;
        });

        _showUserDataDialog(userData);
      } catch (e) {
        developer.log('Error processing QR code',
            name: 'ScanTab',
            error: e.toString());
        
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Crew Member Found'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.shade100,
                child: const Icon(Icons.person, color: Colors.blue),
              ),
              title: Text(userData['display_name'] ?? 'No Name'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${userData['role'] ?? 'Role'} • ${userData['company'] ?? 'Company'}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
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
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement connection request
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Connection request sent!'),
                  backgroundColor: Colors.green,
                ),
              );
              setState(() {
                _hasScanned = false;
              });
            },
            child: const Text('Connect'),
          ),
        ],
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
                bottom: 100,
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