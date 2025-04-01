import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';

class TapTab extends StatefulWidget {
  const TapTab({super.key});

  @override
  State<TapTab> createState() => _TapTabState();
}

class _TapTabState extends State<TapTab> {
  bool _nfcAvailable = false;
  bool _isNfcSessionStarted = false;

  @override
  void initState() {
    super.initState();
    _checkNfcAvailability();
  }

  Future<void> _checkNfcAvailability() async {
    bool isAvailable = await NfcManager.instance.isAvailable();
    setState(() {
      _nfcAvailable = isAvailable;
    });
  }

  Future<void> _startNfcSession() async {
    setState(() {
      _isNfcSessionStarted = true;
    });

    NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        try {
          var ndef = Ndef.from(tag);
          if (ndef == null) {
            _showMessage('This NFC tag is not NDEF formatted');
            return;
          }

          var userData = {
            'id': '12345',
            'name': 'John Doe',
            'email': 'john.doe@example.com',
          };

          var message = NdefMessage([
            NdefRecord.createText(userData.toString()),
          ]);

          await ndef.write(message);
          _showMessage('Successfully shared contact info!');
        } catch (e) {
          _showMessage('Error: ${e.toString()}');
        }
      },
    );
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
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    NfcManager.instance.stopSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_nfcAvailable) {
      return Container(
        color: Colors.white,
        child: const Center(
          child: Text(
            'NFC is not available on this device',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    if (_isNfcSessionStarted) {
      return Container(
        color: Colors.white,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF002B5C),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.nfc_rounded,
                    size: 80,
                    color: const Color(0xFF002B5C),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'NFC active. Hold your phone near another\nCrewLink device to connect.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
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
        ),
      );
    }

    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.nfc_rounded,
              size: 120,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'Tap to enable NFC connection with nearby\ndevices.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _startNfcSession,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF002B5C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                minimumSize: const Size(200, 45),
              ),
              child: const Text(
                'Enable Tap to Connect',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 