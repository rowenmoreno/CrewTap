import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class ThemeService extends GetxService {
  static ThemeService get to => Get.find();
  
  final _isDarkMode = false.obs;
  final _themeMode = ThemeMode.system.obs;
  
  bool get isDarkMode => _isDarkMode.value;
  ThemeMode get themeMode => _themeMode.value;
  
  @override
  void onInit() {
    super.onInit();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedThemeMode = prefs.getString('theme_mode');
      
      if (savedThemeMode != null) {
        switch (savedThemeMode) {
          case 'light':
            _themeMode.value = ThemeMode.light;
            _isDarkMode.value = false;
            break;
          case 'dark':
            _themeMode.value = ThemeMode.dark;
            _isDarkMode.value = true;
            break;
          case 'system':
          default:
            _themeMode.value = ThemeMode.system;
            _isDarkMode.value = Get.isPlatformDarkMode;
            break;
        }
      }
    } catch (e) {
      // If there's an error loading the theme, default to system theme
      _themeMode.value = ThemeMode.system;
      _isDarkMode.value = Get.isPlatformDarkMode;
    }
  }

  Future<void> changeThemeMode(ThemeMode mode) async {
    _themeMode.value = mode;
    _isDarkMode.value = mode == ThemeMode.dark;
    
    // Save the theme preference
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.toString().split('.').last);
    
    // Update the app theme
    Get.changeThemeMode(mode);
  }

  String getCurrentThemeName() {
    switch (_themeMode.value) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
      default:
        return 'System Default';
    }
  }

  ThemeMode getThemeModeFromName(String name) {
    switch (name.toLowerCase()) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system default':
      default:
        return ThemeMode.system;
    }
  }
} 