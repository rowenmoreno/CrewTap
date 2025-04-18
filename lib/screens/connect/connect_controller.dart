import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/supabase_service.dart';

class ConnectController extends GetxController with GetSingleTickerProviderStateMixin {
  final supabase = SupabaseService.client;
  late TabController tabController;
  final cameraController = MobileScannerController();
  final isCameraRunning = false.obs;
  
  final isLoading = true.obs;
  final errorMessage = RxnString();
  final userProfile = Rxn<Map<String, dynamic>>();

  @override
  void onInit() {
    super.onInit();
    tabController = TabController(length: 2, vsync: this);
    loadUserProfile();
    
    // Listen to tab changes to manage camera
    tabController.addListener(_handleTabChange);
  }

  @override
  void onClose() {
    tabController.removeListener(_handleTabChange);
    tabController.dispose();
    stopCamera();
    cameraController.dispose();
    super.onClose();
  }

  void _handleTabChange() {
    if (tabController.index == 1) { // Scan tab
      startCamera();
    } else {
      stopCamera();
    }
  }

  Future<void> startCamera() async {
    if (!isCameraRunning.value) {
      try {
        await cameraController.start();
        isCameraRunning.value = true;
      } catch (e) {
        debugPrint('Error starting camera: $e');
      }
    }
  }

  Future<void> stopCamera() async {
    if (isCameraRunning.value) {
      try {
        await cameraController.stop();
        isCameraRunning.value = false;
      } catch (e) {
        debugPrint('Error stopping camera: $e');
      }
    }
  }

  Future<void> loadUserProfile() async {
    try {
      isLoading.value = true;

      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      final profileResponse = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      userProfile.value = profileResponse;
      isLoading.value = false;
    } catch (e) {
      print('Error loading user profile: $e');
      errorMessage.value = e.toString();
      isLoading.value = false;
    }
  }
} 