import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  String? _errorMessage;

  // Controllers
  final _displayNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _employeeNumberController = TextEditingController();
  final _companyNameController = TextEditingController();

  // Toggle states
  bool _sharePhoneNumber = false;
  bool _shareEmployeeNumber = false;
  bool _shareLocation = false;
  bool _autoDeleteMessages = false;
  bool _enableNotifications = false;

  // Dropdown values
  String _selectedPosition = 'Captain';
  String _selectedAvailability = 'Available';

  // Airlines data
  List<Map<String, dynamic>> _airlines = [];
  bool _isLoadingAirlines = false;
  String? _airlinesError;

  // Constants
  final List<String> _positions = [
    'Captain',
    'First Officer',
    'Flight Attendant',
    'Lead FA',
    'Purser',
    'Dispatcher'
  ];

  final List<String> _availabilityOptions = [
    'Available',
    'Unavailable',
    'On Duty',
    'Off Duty'
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadAirlines();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _phoneNumberController.dispose();
    _employeeNumberController.dispose();
    _companyNameController.dispose();
    super.dispose();
  }

  Future<void> _loadAirlines() async {
    try {
      setState(() {
        _isLoadingAirlines = true;
        _airlinesError = null;
      });

      final airlines = await SupabaseService.getAirlines();
      setState(() {
        _airlines = airlines;
        _isLoadingAirlines = false;
      });
    } catch (e) {
      setState(() {
        _airlinesError = e.toString();
        _isLoadingAirlines = false;
      });
    }
  }

  Future<void> _loadProfile() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final user = SupabaseService.client.auth.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      final profile = await SupabaseService.getProfile(user.id);
      if (profile != null) {
        setState(() {
          _displayNameController.text = profile['display_name'] ?? '';
          _phoneNumberController.text = profile['phone_number'] ?? '';
          _employeeNumberController.text = profile['employee_number'] ?? '';
          _companyNameController.text = profile['company_name'] ?? '';
          _sharePhoneNumber = profile['share_phone'] ?? false;
          _shareEmployeeNumber = profile['share_employee_number'] ?? false;
          _shareLocation = profile['allow_location_sharing'] ?? false;
          _selectedPosition = profile['position'] ?? 'Captain';
          _selectedAvailability = profile['availability_status'] ?? 'Available';
          _autoDeleteMessages = profile['auto_delete_messages'] ?? false;
          _enableNotifications = profile['notifications_enabled'] ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final user = SupabaseService.client.auth.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      await SupabaseService.updateProfile(
        userId: user.id,
        data: {
          'display_name': _displayNameController.text,
          'phone_number': _phoneNumberController.text,
          'employee_number': _employeeNumberController.text,
          'company_name': _companyNameController.text,
          'share_phone': _sharePhoneNumber,
          'share_employee_number': _shareEmployeeNumber,
          'allow_location_sharing': _shareLocation,
          'position': _selectedPosition,
          'availability_status': _selectedAvailability,
          'auto_delete_messages': _autoDeleteMessages,
          'notifications_enabled': _enableNotifications,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _saveProfile,
            child: const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              Row(
                children: [
                  Icon(Icons.person),
                  Text('Personal Information', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _displayNameController,
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your display name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneNumberController,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  border: const OutlineInputBorder(),
                  suffixIcon: Switch(
                    value: _sharePhoneNumber,
                    onChanged: (value) {
                      setState(() {
                        _sharePhoneNumber = value;
                      });
                    },
                  ),
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _employeeNumberController,
                decoration: InputDecoration(
                  labelText: 'Employee Number',
                  border: const OutlineInputBorder(),
                  suffixIcon: Switch(
                    value: _shareEmployeeNumber,
                    onChanged: (value) {
                      setState(() {
                        _shareEmployeeNumber = value;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Autocomplete<Map<String, dynamic>>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return _airlines;
                  }
                  return _airlines.where((airline) {
                    final name = airline['name'].toString().toLowerCase();
                    final code = airline['code'].toString().toLowerCase();
                    final query = textEditingValue.text.toLowerCase();
                    return name.contains(query) || code.contains(query);
                  });
                },
                displayStringForOption: (option) => '${option['name']}',
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Company Name',
                      border: OutlineInputBorder(),
                      hintText: 'Start typing to search airlines...',
                    ),
                  );
                },
                onSelected: (option) {
                  _companyNameController.text = option['name'];
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedPosition,
                decoration: const InputDecoration(
                  labelText: 'Position',
                  border: OutlineInputBorder(),
                ),
                items: _positions.map((String position) {
                  return DropdownMenuItem<String>(
                    value: position,
                    child: Text(position),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedPosition = newValue;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedAvailability,
                decoration: const InputDecoration(
                  labelText: 'Availability',
                  border: OutlineInputBorder(),
                ),
                items: _availabilityOptions.map((String availability) {
                  return DropdownMenuItem<String>(
                    value: availability,
                    child: Text(availability),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedAvailability = newValue;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Location Sharing'),
                subtitle: const Text('Allow others to see your location'),
                value: _shareLocation,
                onChanged: (bool value) {
                  setState(() {
                    _shareLocation = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.settings),
                  Text('App Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Auto-delete messages'),
                subtitle: const Text('Messages will be automatically deleted when chats expire'),
                value: _autoDeleteMessages,
                onChanged: (bool value) {
                  setState(() {
                    _autoDeleteMessages = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Enable Notifications'),
                subtitle: const Text('Receive notifications for new messages'),
                value: _enableNotifications,
                onChanged: (bool value) {
                  setState(() {
                    _enableNotifications = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
} 