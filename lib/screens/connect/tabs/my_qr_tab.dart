import 'dart:math';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/supabase_service.dart';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:ui' as ui;

class MyQRTab extends StatefulWidget {
  const MyQRTab({
    super.key, 
    required this.userId,
    required this.displayName,
    required this.position,
  });

  final String userId;
  final String displayName;
  final String position;

  @override
  State<MyQRTab> createState() => _MyQRTabState();
}

class _MyQRTabState extends State<MyQRTab> {
  String? _qrData;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  User? _userData;
  Map<String, dynamic>? _userProfile;
  String? _groupName;

  @override
  void initState() {
    super.initState();
    _generateQRData();
  }

  String _generateGroupName() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return List.generate(8, (index) => chars[random.nextInt(chars.length)]).join();
  }

  void _generateQRData() {
    try {
      final groupName = _generateGroupName();
      setState(() {
        _groupName = groupName;
        _qrData = 'crewtap://join/group/$groupName/${widget.userId}/${widget.displayName}/${widget.position}';
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error generating QR data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _shareQRCode() async {
    if (_qrData == null) return;

    try {
      final qrImage = await QrPainter(
        data: _qrData!,
        version: QrVersions.auto,
        gapless: false,
        color: Colors.black,
        emptyColor: Colors.white,
      ).toImage(200);

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/qr_code.png');
      final byteData = await qrImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        await file.writeAsBytes(byteData.buffer.asUint8List());
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Join my CrewTap group: $_groupName',
        );
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error sharing QR code: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to share QR code')),
        );
      }
    }
  }

  Future<void> _downloadQRCode() async {
    if (_qrData == null) return;

    try {
      final qrImage = await QrPainter(
        data: _qrData!,
        version: QrVersions.auto,
        gapless: false,
        color: Colors.black,
        emptyColor: Colors.white,
      ).toImage(200);

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/qr_code.png');
      final byteData = await qrImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        await file.writeAsBytes(byteData.buffer.asUint8List());
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Join my CrewTap group: $_groupName',
        );
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error saving QR code: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save QR code')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isLoading)
                  const CircularProgressIndicator()
                else if (_hasError)
                  Column(
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
                        onPressed: _generateQRData,
                        child: const Text('Retry'),
                      ),
                    ],
                  )
                else if (_qrData != null)
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withValues(alpha: 0.2),
                              spreadRadius: 2,
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            QrImageView(
                              data: _qrData!,
                              version: QrVersions.auto,
                              size: 200.0,
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                            ),
                            const Text(
                              'Show this code to quickly connect with\ncrew.',
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
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _shareQRCode,
                              icon: const Icon(Icons.share),
                              label: const Text('Share QR'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 