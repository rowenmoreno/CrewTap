import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/supabase_service.dart';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class MyQRTab extends StatefulWidget {
  const MyQRTab({super.key});

  @override
  State<MyQRTab> createState() => _MyQRTabState();
}

class _MyQRTabState extends State<MyQRTab> {
  Map<String, dynamic>? userData;
  Map<String, dynamic>? userProfile;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
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

      // Prepare user data for QR code
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
      developer.log('Error loading user data', name: 'MyQRTab', error: e.toString());
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadQRCode() async {
    try {
      final qrPainter = QrPainter(
        data: jsonEncode(userData),
        version: QrVersions.auto,
        gapless: false,
        color: Colors.black,
        emptyColor: Colors.white,
      );

      final imageData = await qrPainter.toImageData(2048);
      if (imageData == null) {
        throw Exception('Failed to generate QR code image');
      }
      
      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/crew_link_qr.png');
      await tempFile.writeAsBytes(imageData.buffer.asUint8List());

      // Share the file with a specific message for saving
      await Share.shareXFiles(
        [XFile(tempFile.path)],
        text: 'Save my CrewLink QR code',
      );

      // Clean up
      await tempFile.delete();
    } catch (e) {
      developer.log('Error saving QR code', name: 'MyQRTab', error: e.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save QR code'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _shareQRCode() async {
    try {
      final qrPainter = QrPainter(
        data: jsonEncode(userData),
        version: QrVersions.auto,
        gapless: false,
        color: Colors.black,
        emptyColor: Colors.white,
      );

      final imageData = await qrPainter.toImageData(2048);
      if (imageData == null) {
        throw Exception('Failed to generate QR code image');
      }
      
      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/crew_link_qr.png');
      await tempFile.writeAsBytes(imageData.buffer.asUint8List());

      // Share the file
      await Share.shareXFiles(
        [XFile(tempFile.path)],
        text: 'Connect with me on CrewLink!',
      );

      // Clean up
      await tempFile.delete();
    } catch (e) {
      developer.log('Error sharing QR code', name: 'MyQRTab', error: e.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to share QR code'),
          backgroundColor: Colors.red,
        ),
      );
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
                  QrImageView(
                    data: jsonEncode(userData),
                    version: QrVersions.auto,
                    size: 200.0,
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                  const SizedBox(height: 24),
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
            const SizedBox(height: 20),
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
      ),
    );
  }
} 