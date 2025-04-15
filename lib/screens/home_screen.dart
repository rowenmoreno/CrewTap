import 'package:flutter/material.dart';
import 'dart:math';
import '../services/supabase_service.dart';
import 'profile_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'airport_passcode_screen.dart';
import '../services/api_helper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _userInitials = '';
  bool _isLoading = true;
  Position? _currentPosition;
  String _locationMessage = 'Getting location...';
  Map<String, dynamic>? _nearestAirport;
  bool _isLoadingAirport = false;
  String? _errorMessage;
  String? _airportPasscode;
  bool _isLoadingPasscode = false;
  bool _showPasscode = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) return;

      final profile = await SupabaseService.getProfile(user.id);
      if (profile != null && mounted) {
        final displayName = profile['display_name'] ?? 'User';
        setState(() {
          _userInitials = _getInitials(displayName);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, min(2, name.length)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            // Image.asset(
            //   'assets/images/logo.png',
            //   height: 24,
            // ),
            // const SizedBox(width: 8),
            const Text('Home'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.location_on),
            onPressed: () {
              Navigator.pushNamed(context, '/location');
            },
          ),
          PopupMenuButton<String>(
            offset: const Offset(0, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0,left: 16),
              child: CircleAvatar(
                backgroundColor: Colors.grey[200],
                child: Text(_userInitials),
              ),
            ),
            onSelected: (value) async {
              if (value == 'profile') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                ).then((_) => _loadUserProfile());
              } else if (value == 'logout') {
                await SupabaseService.client.auth.signOut();
                if (mounted) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline),
                    SizedBox(width: 8),
                    Text('View Profile'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
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
                        // _buildQuickAccessCard(
                        //   icon: Icons.chat,
                        //   title: 'Crew Chat',
                        //   subtitle: 'Connect with your crew',
                        //   color: Colors.green,
                        //   onTap: () => Get.to(() => const CrewConnectScreen()),
                        // ),
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
}


  


class CrewMemberTile extends StatelessWidget {
  final String initials;
  final String name;
  final Color color;
  final bool isOnline;

  const CrewMemberTile({
    super.key,
    required this.initials,
    required this.name,
    required this.color,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withOpacity(0.2),
              child: Text(
                initials,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (isOnline)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: const TextStyle(
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class ChatMessage extends StatelessWidget {
  final String? sender;
  final String message;
  final String time;
  final bool isCurrentUser;

  const ChatMessage({
    super.key,
    this.sender,
    required this.message,
    required this.time,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment:
            isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isCurrentUser && sender != null)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 4),
              child: Text(
                sender!,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isCurrentUser ? Colors.blue[900] : Colors.blue[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    color: isCurrentUser ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 12,
                    color: isCurrentUser ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 