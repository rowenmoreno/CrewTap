import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/api_helper.dart';

class AirportPasscodeScreen extends StatefulWidget {
  final String? initialAirportCode;
  
  const AirportPasscodeScreen({
    super.key,
    this.initialAirportCode,
  });

  @override
  State<AirportPasscodeScreen> createState() => _AirportPasscodeScreenState();
}

class _AirportPasscodeScreenState extends State<AirportPasscodeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passcodeController = TextEditingController();
  bool _isLoading = false;
  bool _isLoadingAirports = true;
  String? _errorMessage;
  String? _successMessage;
  List<Map<String, dynamic>> _airports = [];
  String? _selectedAirportCode;

  @override
  void initState() {
    super.initState();
    _selectedAirportCode = widget.initialAirportCode;
    _loadAirports();
  }

  @override
  void dispose() {
    _passcodeController.dispose();
    super.dispose();
  }

  Future<void> _loadAirports() async {
    try {
      final airports = await ApiHelper().getAllAirports();
      setState(() {
        _airports = airports;
        _isLoadingAirports = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading airports: $e';
        _isLoadingAirports = false;
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAirportCode == null) {
      setState(() {
        _errorMessage = 'Please select an airport';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final result = await ApiHelper().updateAirportPasscode(
        _selectedAirportCode!,
        _passcodeController.text,
      );

      setState(() {
        _successMessage = result['message'];
        _isLoading = false;
      });

      // Clear form after successful submission
      _passcodeController.clear();
      setState(() {
        _selectedAirportCode = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Airport Passcodes'),
        
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
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
                          Icons.vpn_key,
                          size: 48,
                          color: Colors.blue,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Add/Update Airport Passcode',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 24),
                        if (_isLoadingAirports)
                          const Center(child: CircularProgressIndicator())
                        else
                          DropdownButtonFormField<String>(
                            value: _selectedAirportCode,
                            decoration: const InputDecoration(
                              labelText: 'Select Airport',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.airport_shuttle),
                            ),
                            isExpanded: true,
                            items: _airports.map((airport) {
                              return DropdownMenuItem<String>(
                                value: airport['airport_code'],
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                  Text(
                                    airport['airport_name'],
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    airport['airport_code'],
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                                                                ));
                            }).toList(),
                            selectedItemBuilder: (context) {
                              return _airports.map((airport) {
                                return Text(airport['airport_code']);
                              }).toList();
                            },
                            onChanged: (value) {
                              setState(() {
                                _selectedAirportCode = value;
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select an airport';
                              }
                              return null;
                            },
                          ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passcodeController,
                          decoration: const InputDecoration(
                            labelText: 'Passcode',
                            hintText: 'Enter passcode',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.lock),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a passcode';
                            }
                            if (value.length < 4) {
                              return 'Passcode must be at least 4 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        if (_successMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              _successMessage!,
                              style: const TextStyle(color: Colors.green),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _submitForm,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator()
                              : const Text('Save Passcode'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 