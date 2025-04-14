import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import '../services/api_helper.dart';
import 'dart:math';

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
    } catch (e) {
      setState(() {
        _isLoadingAirport = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Airport Location'),
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
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 48,
                              color: Colors.blue,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Your Current Location',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            if (_currentPosition != null) ...[
                              Text(
                                'Latitude: ${_currentPosition!.latitude.toStringAsFixed(6)}',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              Text(
                                'Longitude: ${_currentPosition!.longitude.toStringAsFixed(6)}',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              Text(
                                'Accuracy: ${_currentPosition!.accuracy.toStringAsFixed(2)} meters',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_errorMessage != null)
                      Card(
                        color: Colors.red.shade100,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    if (_isLoadingAirport)
                      const Center(child: CircularProgressIndicator())
                    else if (_nearestAirport != null)
                      Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.airplanemode_active,
                                size: 48,
                                color: Colors.green,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Current Airport',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 16),
                              ListTile(
                                leading: const Icon(Icons.airport_shuttle),
                                title: const Text('Airport Name'),
                                subtitle: Text(
                                  _nearestAirport!['airport_name'],
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                              ListTile(
                                leading: const Icon(Icons.code),
                                title: const Text('Airport Code'),
                                subtitle: Text(
                                  _nearestAirport!['airport_code'],
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                              ListTile(
                                leading: const Icon(Icons.directions),
                                title: const Text('Distance'),
                                subtitle: Text(
                                  '${_nearestAirport!['distance_km'].toStringAsFixed(2)} km',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    const Text(
                                      'Airport Pass Code',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _nearestAirport!['airport_code'] + '1234', // Example pass code
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (_currentPosition != null) {
                          _findNearestAirport(_currentPosition!.latitude, _currentPosition!.longitude);
                        }
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh Airport Info'),
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