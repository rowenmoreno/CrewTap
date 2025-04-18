import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get/get.dart';
import 'screens/qr_scanner_screen.dart';
import 'screens/main_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'config/supabase_config.dart';
import 'theme/app_theme.dart';
import 'services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await dotenv.load(fileName: ".env");
  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  
  // Initialize ThemeService
  final themeService = Get.put(ThemeService());
  
  runApp(GetMaterialApp(
    title: 'CrewLink',
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    themeMode: themeService.themeMode,
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('An error occurred'),
            );
          }

          final session = snapshot.data?.session;
          if (session == null) {
            return const OnboardingScreen();
          }

          return const MainScreen();
        },
      ),
    ),
    routes: {
      '/qr_scanner': (context) => const QRScannerScreen(),
    },
  ));
}
