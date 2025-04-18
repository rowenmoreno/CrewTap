import 'package:crewtap/screens/profile/theme_settings_screen.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'notification_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Account Settings Section
          _buildSectionHeader('Account'),
          _buildSettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Manage your notification preferences',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationSettingsScreen(),
                ),
              );
            },
          ),
          _buildSettingsTile(
            icon: Icons.lock_outline,
            title: 'Privacy',
            subtitle: 'Control your privacy settings',
            onTap: () {
              // TODO: Implement privacy settings
            },
          ),
          // _buildSettingsTile(
          //   icon: Icons.security_outlined,
          //   title: 'Security',
          //   subtitle: 'Manage your security settings',
          //   onTap: () {
          //     // TODO: Implement security settings
          //   },
          // ),

          // App Settings Section
          // _buildSectionHeader('App Settings'),
          // _buildSettingsTile(
          //   icon: Icons.language_outlined,
          //   title: 'Language',
          //   subtitle: 'Change app language',
          //   onTap: () {
          //     // TODO: Implement language settings
          //   },
          // ),
          // _buildSettingsTile(
          //   icon: Icons.dark_mode_outlined,
          //   title: 'Theme',
          //   subtitle: 'Change app theme',
          //   onTap: () {
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(
          //         builder: (context) => const ThemeSettingsScreen(),
          //       ),
          //     );
          //   },
          // ),
          // _buildSettingsTile(
          //   icon: Icons.storage_outlined,
          //   title: 'Storage',
          //   subtitle: 'Manage app storage',
          //   onTap: ()
          _buildSectionHeader('Support'),
          _buildSettingsTile(
            icon: Icons.feedback_outlined,
            title: 'Send Feedback',
            subtitle: 'Help us improve the app',
            onTap: () {
              // TODO: Implement feedback
            },
          ),
          _buildSettingsTile(
            icon: Icons.info_outline,
            title: 'About',
            subtitle: 'App version and information',
            onTap: () {
              // TODO: Implement about section
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.jetGrey,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.skyBlue),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
} 