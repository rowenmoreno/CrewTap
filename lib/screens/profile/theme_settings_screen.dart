import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../theme/app_theme.dart';
import '../../services/theme_service.dart';

class ThemeSettingsScreen extends GetView<ThemeService> {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Theme Settings'),
      ),
      body: ListView(
        children: [
          _buildSectionHeader('App Theme'),
          _buildThemeOption('Light'),
          _buildThemeOption('Dark'),
          _buildThemeOption('System Default'),
          const SizedBox(height: 16),
          // _buildSectionHeader('Preview'),
          // _buildThemePreview(context),
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

  Widget _buildThemeOption(String theme) {
    return Obx(() => RadioListTile<String>(
      title: Text(theme),
      value: theme,
      groupValue: controller.getCurrentThemeName(),
      onChanged: (String? value) {
        if (value != null) {
          final themeMode = controller.getThemeModeFromName(value);
          controller.changeThemeMode(themeMode);
        }
      },
      activeColor: AppColors.skyBlue,
    ));
  }

  Widget _buildThemePreview(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preview',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'This is how your app will look with the selected theme.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPreviewItem(
                icon: Icons.message_outlined,
                label: 'Messages',
                context: context,
              ),
              _buildPreviewItem(
                icon: Icons.group_outlined,
                label: 'Groups',
                context: context,
              ),
              _buildPreviewItem(
                icon: Icons.person_outline,
                label: 'Profile',
                context: context,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewItem({
    required IconData icon,
    required String label,
    required BuildContext context,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
} 