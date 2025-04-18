import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:math';
import '../../services/supabase_service.dart';
import '../passcode/airport_passcode_screen.dart';
import '../profile/profile_screen.dart';
import 'controller/dashboard_controller.dart';
import '../../theme/app_theme.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(DashboardController());
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          PopupMenuButton<String>(
            offset: const Offset(0, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0, left: 16),
              child: Obx(() => CircleAvatar(
                backgroundColor: AppColors.skyBlue.withOpacity(0.15),
                child: Text(
                  controller.userInitials.value,
                  style: TextStyle(
                    color: AppColors.skyBlue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )),
            ),
            onSelected: (value) async {
              if (value == 'profile') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                ).then((_) => controller.loadUserProfile());
              } else if (value == 'logout') {
                await SupabaseService.client.auth.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person),
                    SizedBox(width: 8),
                    Text('Profile'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Current Airport Section
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.airplanemode_active,
                              size: 32,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Current Airport',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  if (controller.nearestAirport.value != null) ...[
                                    Text(
                                      controller.nearestAirport.value!['airport_name'],
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      controller.nearestAirport.value!['airport_code'],
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (controller.isLoadingPasscode.value)
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(),
                          )
                        else if (controller.airportPasscode?.value != null)
                          Container(
                            margin: const EdgeInsets.only(top: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Door Pass',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        controller.showPasscode.value
                                            ? controller.airportPasscode!.value
                                            : '••••••••',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        controller.showPasscode.value
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: Colors.blue,
                                      ),
                                      onPressed: controller.togglePasscodeVisibility,
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit,
                                        color: Colors.blue,
                                      ),
                                      onPressed: () {
                                        if (controller.nearestAirport.value != null) {
                                          Get.to(() => AirportPasscodeScreen(
                                            initialAirportCode:
                                                controller.nearestAirport.value!['airport_code'],
                                          ));
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Quick Access Grid
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  children: [
                    _buildQuickAccessCard(
                      icon: Icons.door_front_door,
                      title: 'Door Passes',
                      subtitle: 'Access airport doors',
                      color: Colors.blue,
                      onTap: () async {
                        await Get.to(() => const AirportPasscodeScreen());
                        controller.fetchAirportPasscode(controller.nearestAirport.value!['airport_code']);
                      },
                    ),
                    // _buildQuickAccessCard(
                    //   icon: Icons.chat,
                    //   title: 'Crew Chat',
                    //   subtitle: 'Connect with crew',
                    //   color: Colors.green,
                    //   onTap: () {
                    //     Get.to(() => const CrewConnectScreen());
                    //   },
                    // ),
                    _buildQuickAccessCard(
                      icon: Icons.restaurant,
                      title: 'Meal Discounts',
                      subtitle: 'Find food deals',
                      color: Colors.orange,
                      onTap: () {
                        // TODO: Implement meal discounts navigation
                      },
                    ),
                    _buildQuickAccessCard(
                      icon: Icons.hotel,
                      title: 'Crew Hotels',
                      subtitle: 'Book accommodations',
                      color: Colors.purple,
                      onTap: () {
                        // TODO: Implement crew hotels navigation
                      },
                    ),
                    _buildQuickAccessCard(
                      icon: Icons.map,
                      title: 'Terminal Map',
                      subtitle: 'Navigate the airport',
                      color: Colors.red,
                      onTap: () {
                        // TODO: Implement terminal map navigation
                      },
                    ),
                    // _buildQuickAccessCard(
                    //   icon: Icons.emergency,
                    //   title: 'Emergency Contacts',
                    //   subtitle: 'Important numbers',
                    //   color: Colors.red,
                    //   onTap: () {
                    //     // TODO: Implement emergency contacts navigation
                    //   },
                    // ),
                  ],
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildQuickAccessCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String generateRandomString(int length) {
    const characters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(Iterable.generate(
      length,
      (_) => characters.codeUnitAt(random.nextInt(characters.length)),
  ));
}
} 