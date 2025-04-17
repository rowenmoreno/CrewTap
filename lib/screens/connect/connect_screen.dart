import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'tabs/my_qr_tab.dart';
import 'tabs/scan_tab.dart';
import 'tabs/tap_tab.dart';
import 'connect_controller.dart';

class ConnectScreen extends StatelessWidget {
  const ConnectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ConnectController());

    return Obx(() {
      if (controller.isLoading.value) {
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      if (controller.errorMessage.value != null) {
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Error: ${controller.errorMessage.value}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: controller.loadUserProfile,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      }

      return Scaffold(
        appBar: AppBar(
          title: const Text('Connect'),
          bottom: TabBar(
            controller: controller.tabController,
            tabs: const [
              Tab(icon: Icon(Icons.qr_code), text: 'My QR'),
              Tab(icon: Icon(Icons.qr_code_scanner), text: 'Scan'),
              // Tab(icon: Icon(Icons.tap_and_play), text: 'Tap'),
            ],
          ),
        ),
        body: TabBarView(
          controller: controller.tabController,
          children: [
            MyQRTab(
              userId: controller.supabase.auth.currentUser!.id,
              displayName: controller.userProfile.value?['display_name'] ?? "Name",
              position: controller.userProfile.value?['position'] ?? "Role",
            ),
            const ScanTab(),
            // TapTab(
            //   userId: controller.supabase.auth.currentUser!.id,
            //   displayName: controller.userProfile.value?['display_name'] ?? "Name",
            //   position: controller.userProfile.value?['position'] ?? "Role",
            // ),
          ],
        ),
      );
    });
  }
} 