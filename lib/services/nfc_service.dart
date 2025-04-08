import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';

class NFCService {
  static Future<bool> isNFCAvailable() async {
    try {
      final availability = await FlutterNfcKit.nfcAvailability;
      return availability == NFCAvailability.available;
    } catch (e) {
      return false;
    }
  }

  static Future<String?> scanNFCTag() async {
    try {
      // Start NFC session
      final tag = await FlutterNfcKit.poll();
      
      // Get the ID of the tag
      final tagId = tag.id;
      
      // Finish NFC session
      await FlutterNfcKit.finish();
      
      return tagId;
    } catch (e) {
      // If there's an error, make sure to finish the session
      try {
        await FlutterNfcKit.finish();
      } catch (_) {}
      return null;
    }
  }

  static Future<void> stopNFCSession() async {
    try {
      await FlutterNfcKit.finish();
    } catch (_) {}
  }
} 