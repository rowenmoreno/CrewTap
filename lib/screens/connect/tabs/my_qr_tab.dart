import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class MyQRTab extends StatelessWidget {
  const MyQRTab({super.key});

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> userData = {
      'id': '12345',
      'name': 'John Doe',
      'email': 'john.doe@example.com',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: QrImageView(
              data: Uri.encodeFull(userData.toString()),
              version: QrVersions.auto,
              size: 200.0,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Colors.black,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Colors.black,
              ),
            ),
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
          OutlinedButton.icon(
            onPressed: () {
              // TODO: Implement share functionality
            },
            icon: const Icon(Icons.share, size: 20),
            label: const Text('Share My QR Code'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue,
              minimumSize: const Size(double.infinity, 48),
              side: const BorderSide(color: Colors.blue),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
} 