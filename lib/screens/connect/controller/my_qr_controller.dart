import 'dart:math';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class MyQRController extends GetxController {
  final String userId;
  final String displayName;
  final String position;

  MyQRController({
    required this.userId,
    required this.displayName,
    required this.position,
  });

  final isLoading = true.obs;
  final hasError = false.obs;
  final errorMessage = RxnString();
  final qrData = RxnString();
  final groupName = RxnString();

  @override
  void onInit() {
    super.onInit();
    generateQRData();
  }

  String generateRandomGroupName() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return List.generate(8, (index) => chars[random.nextInt(chars.length)]).join();
  }

  void generateQRData() {
    try {
      final name = generateRandomGroupName();
      groupName.value = name;
      qrData.value = 'crewtap://join/group/$name/$userId/$displayName/$position';
      isLoading.value = false;
    } catch (e) {
      debugPrint('Error generating QR data: $e');
      isLoading.value = false;
      hasError.value = true;
      errorMessage.value = e.toString();
    }
  }

  Future<void> shareQRCode() async {
    if (qrData.value == null) return;

    try {
      final qrImage = await QrPainter(
        data: qrData.value!,
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
          text: 'Join my CrewTap group: ${groupName.value}',
        );
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error sharing QR code: $e');
      Get.snackbar(
        'Error',
        'Failed to share QR code',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> downloadQRCode() async {
    if (qrData.value == null) return;

    try {
      final qrImage = await QrPainter(
        data: qrData.value!,
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
          text: 'Join my CrewTap group: ${groupName.value}',
        );
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error saving QR code: $e');
      Get.snackbar(
        'Error',
        'Failed to save QR code',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
} 