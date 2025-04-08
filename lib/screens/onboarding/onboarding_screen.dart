import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/onboarding_carousel.dart';
import 'widgets/profile_setup_form.dart';
import '../auth/auth_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  String _currentStep = 'tutorial';

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingComplete = prefs.getBool('onboardingComplete') ?? false;
    
    if (onboardingComplete) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    }
  }

  void _handleTutorialComplete() {
    setState(() {
      _currentStep = 'auth';
    });
  }

  void _handleAuthComplete() {
    setState(() {
      _currentStep = 'profile';
    });
  }

  Future<void> _handleProfileComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingComplete', true);
    
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 24.0),
              child: Text(
                'CrewTap',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // Image.asset(
              //   'assets/images/logo.png',
              //   height: 40,
              // ),
            ),
            Expanded(
              child: _buildCurrentStep(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 'tutorial':
        return OnboardingCarousel(
          onComplete: _handleTutorialComplete,
        );
      case 'auth':
        return AuthScreen(
          onAuthComplete: _handleAuthComplete,
        );
      case 'profile':
        return ProfileSetupForm(
          onComplete: _handleProfileComplete,
        );
      default:
        return const SizedBox.shrink();
    }
  }
} 