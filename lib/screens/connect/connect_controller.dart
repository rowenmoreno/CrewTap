import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/supabase_service.dart';

class ConnectController extends GetxController with GetSingleTickerProviderStateMixin {
  final supabase = SupabaseService.client;
  late TabController tabController;
  
  final isLoading = true.obs;
  final errorMessage = RxnString();
  final userProfile = Rxn<Map<String, dynamic>>();

  @override
  void onInit() {
    super.onInit();
    tabController = TabController(length: 2, vsync: this);
    loadUserProfile();
  }

  @override
  void onClose() {
    tabController.dispose();
    super.onClose();
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