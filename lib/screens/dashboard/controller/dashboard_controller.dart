import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import '../../../services/api_helper.dart';
import '../../../services/supabase_service.dart';

class DashboardController extends GetxController {
  final Rx<Position?> currentPosition = Rx<Position?>(null);
  final RxString locationMessage = 'Getting location...'.obs;
  final RxBool isLoading = true.obs;
  final Rx<Map<String, dynamic>?> nearestAirport = Rx<Map<String, dynamic>?>(null);
  final RxBool isLoadingAirport = false.obs;
  final RxString? errorMessage = RxString('');
  final RxString? airportPasscode = RxString('');
  final RxBool isLoadingPasscode = false.obs;
  final RxBool showPasscode = false.obs;
  final RxString userInitials = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadUserProfile();
    getCurrentLocation();
  }

  Future<void> loadUserProfile() async {
    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) return;

      final profile = await SupabaseService.getProfile(user.id);
      if (profile != null) {
        final displayName = profile['display_name'] ?? 'User';
        userInitials.value = getInitials(displayName);
        isLoading.value = false;
      }
    } catch (e) {
      isLoading.value = false;
    }
  }

  String getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, 2).toUpperCase();
  }

  Future<void> getCurrentLocation() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        locationMessage.value = 'Location services are disabled. Please enable them in your device settings.';
        isLoading.value = false;
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          locationMessage.value = 'Location permissions are denied. Please enable them in your device settings.';
          isLoading.value = false;
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        locationMessage.value = 'Location permissions are permanently denied. Please enable them in your device settings.';
        isLoading.value = false;
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Location request timed out. Please try again.');
        },
      );

      currentPosition.value = position;
      locationMessage.value = 'Location obtained successfully';
      isLoading.value = false;
      errorMessage?.value = '';

      await findNearestAirport(position.latitude, position.longitude);
    } catch (e) {
      locationMessage.value = 'Error getting location: $e';
      isLoading.value = false;
    }
  }

  Future<void> findNearestAirport(double latitude, double longitude) async {
    isLoadingAirport.value = true;
    errorMessage?.value = '';

    try {
      final airports = await ApiHelper().findNearestAirport(latitude, longitude);
      if (airports.isEmpty) {
        throw Exception('No airports found');
      }
      
      nearestAirport.value = airports.first;
      isLoadingAirport.value = false;

      await fetchAirportPasscode(nearestAirport.value!['airport_code']);
    } catch (e) {
      isLoadingAirport.value = false;
      errorMessage?.value = e.toString();
    }
  }

  Future<void> fetchAirportPasscode(String airportCode) async {
    isLoadingPasscode.value = true;

    try {
      final passcode = await ApiHelper().getAirportPasscode(airportCode);
      airportPasscode?.value = passcode ?? '';
      isLoadingPasscode.value = false;
    } catch (e) {
      isLoadingPasscode.value = false;
      errorMessage?.value = 'Error fetching passcode: $e';
    }
  }

  void togglePasscodeVisibility() {
    showPasscode.value = !showPasscode.value;
  }
} 