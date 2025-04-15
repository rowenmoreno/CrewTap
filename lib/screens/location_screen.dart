import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import '../services/api_helper.dart';
import 'dart:math';
import 'airport_passcode_screen.dart';
import 'crew_connect_screen.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  Position? _currentPosition;
  String _locationMessage = 'Getting location...';
  bool _isLoading = true;
  Map<String, dynamic>? _nearestAirport;
  bool _isLoadingAirport = false;
  String? _errorMessage;
  String? _airportPasscode;
  bool _isLoadingPasscode = false;
  bool _showPasscode = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationMessage = 'Location services are disabled. Please enable them in your device settings.';
          _isLoading = false;
        });
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationMessage = 'Location permissions are denied. Please enable them in your device settings.';
            _isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationMessage = 'Location permissions are permanently denied. Please enable them in your device settings.';
          _isLoading = false;
        });
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

      setState(() {
        _currentPosition = position;
        _locationMessage = 'Location obtained successfully';
        _isLoading = false;
        _errorMessage = null;
      });

      await _findNearestAirport(position.latitude, position.longitude);
    } catch (e) {
      setState(() {
        _locationMessage = 'Error getting location: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _findNearestAirport(double latitude, double longitude) async {
    setState(() {
      _isLoadingAirport = true;
      _errorMessage = null;
    });

    try {
      final airports = await ApiHelper().findNearestAirport(latitude, longitude);
      if (airports.isEmpty) {
        throw Exception('No airports found');
      }
      
      setState(() {
        _nearestAirport = airports.first;
        _isLoadingAirport = false;
      });

      // Fetch the passcode for the nearest airport
      await _fetchAirportPasscode(_nearestAirport!['airport_code']);
    } catch (e) {
      setState(() {
        _isLoadingAirport = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _fetchAirportPasscode(String airportCode) async {
    setState(() {
      _isLoadingPasscode = true;
    });

    try {
      final passcode = await ApiHelper().getAirportPasscode(airportCode);
      setState(() {
        _airportPasscode = passcode;
        _isLoadingPasscode = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingPasscode = false;
        _errorMessage = 'Error fetching passcode: $e';
      });
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CrewTap Dashboard'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                                      if (_nearestAirport != null) ...[
                                        Text(
                                          _nearestAirport!['airport_name'],
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          _nearestAirport!['airport_code'],
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
                            if (_isLoadingPasscode)
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(),
                              )
                            else if (_airportPasscode != null)
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
                                            _showPasscode ? _airportPasscode! : '••••••••',
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
                                            _showPasscode ? Icons.visibility_off : Icons.visibility,
                                            color: Colors.blue,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _showPasscode = !_showPasscode;
                                            });
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit,
                                            color: Colors.blue,
                                          ),
                                          onPressed: () {
                                            if (_nearestAirport != null) {
                                              Get.to(() => AirportPasscodeScreen(
                                                initialAirportCode: _nearestAirport!['airport_code'],
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
                    
                    // Quick Access Section
                    Text(
                      'Quick Access',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      children: [
                        _buildQuickAccessCard(
                          icon: Icons.vpn_key,
                          title: 'Door Passes',
                          subtitle: 'Access all airport door codes',
                          color: Colors.blue,
                          onTap: () => Get.to(() => const AirportPasscodeScreen()),
                        ),
                        _buildQuickAccessCard(
                          icon: Icons.chat,
                          title: 'Crew Chat',
                          subtitle: 'Connect with your crew',
                          color: Colors.green,
                          onTap: () => Get.to(() => const CrewConnectScreen()),
                        ),
                        // _buildQuickAccessCard(
                        //   icon: Icons.restaurant,
                        //   title: 'Meal Discounts',
                        //   subtitle: 'View crew meal deals',
                        //   color: Colors.orange,
                        //   onTap: () {
                        //     // TODO: Navigate to meal discounts
                        //   },
                        // ),
                        // _buildQuickAccessCard(
                        //   icon: Icons.hotel,
                        //   title: 'Crew Hotels',
                        //   subtitle: 'Find crew accommodations',
                        //   color: Colors.purple,
                        //   onTap: () {
                        //     // TODO: Navigate to crew hotels
                        //   },
                        // ),
                        // _buildQuickAccessCard(
                        //   icon: Icons.map,
                        //   title: 'Terminal Map',
                        //   subtitle: 'Navigate the airport',
                        //   color: Colors.red,
                        //   onTap: () {
                        //     // TODO: Navigate to terminal map
                        //   },
                        // ),
                        // _buildQuickAccessCard(
                        //   icon: Icons.emergency,
                        //   title: 'Emergency',
                        //   subtitle: 'Important contacts',
                        //   color: Colors.red,
                        //   onTap: () {
                        //     // TODO: Navigate to emergency contacts
                        //   },
                        // ),
                      ],
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