import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _messageNotifications = true;
  bool _groupNotifications = true;
  bool _mentionNotifications = true;
  bool _emailNotifications = false;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
      ),
      body: ListView(
        children: [
          // Push Notifications Section
          _buildSectionHeader('Push Notifications'),
          _buildSwitchTile(
            title: 'Message Notifications',
            subtitle: 'Receive notifications for new messages',
            value: _messageNotifications,
            onChanged: (value) {
              setState(() {
                _messageNotifications = value;
              });
            },
          ),

          // Notification Preferences Section
          // _buildSectionHeader('Notification Preferences'),
          // _buildSwitchTile(
          //   title: 'Sound',
          //   subtitle: 'Play sound for notifications',
          //   value: _soundEnabled,
          //   onChanged: (value) {
          //     setState(() {
          //       _soundEnabled = value;
          //     });
          //   },
          // ),
          // _buildSwitchTile(
          //   title: 'Vibration',
          //   subtitle: 'Vibrate for notifications',
          //   value: _vibrationEnabled,
          //   onChanged: (value) {
          //     setState(() {
          //       _vibrationEnabled = value;
          //     });
          //   },
          // ),
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

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.skyBlue,
    );
  }
} 