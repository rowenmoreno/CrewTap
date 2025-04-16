import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get/get.dart';
import 'screens/qr_scanner_screen.dart';
import 'screens/main_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'config/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  
  await dotenv.load(fileName: ".env");
  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CrewTap',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),      initialRoute: '/',
      routes: {
        '/': (context) => const AuthWrapper(),
        '/home': (context) => const MainScreen(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // If there's an active session, show the main screen
        if (snapshot.hasData && snapshot.data!.session != null) {
          return const MainScreen();
        }
        // If there's no session, show the onboarding screen
        return const OnboardingScreen();
      },
    
    );
  }
}
