import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/api_helper.dart';

class CrewConnectScreen extends StatefulWidget {
  const CrewConnectScreen({super.key});

  @override
  State<CrewConnectScreen> createState() => _CrewConnectScreenState();
}

class _CrewConnectScreenState extends State<CrewConnectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _crewIdController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  bool _showScanner = false;
  MobileScannerController? _scannerController;

  @override
  void dispose() {
    _crewIdController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  Future<void> _connectWithCrew(String crewId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // TODO: Implement crew connection logic
      await Future.delayed(const Duration(seconds: 1)); // Simulated API call
      
      setState(() {
        _successMessage = 'Successfully connected with crew!';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error connecting with crew: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect with Crew'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
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
                        Icons.group,
                        size: 48,
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Connect with Your Crew',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _showScanner = true;
                          });
                        },
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Scan Crew QR Code'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('OR'),
                      const SizedBox(height: 16),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _crewIdController,
                              decoration: const InputDecoration(
                                labelText: 'Enter Crew ID',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.group),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a crew ID';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      if (_formKey.currentState!.validate()) {
                                        _connectWithCrew(_crewIdController.text);
                                      }
                                    },
                              child: _isLoading
                                  ? const CircularProgressIndicator()
                                  : const Text('Connect'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_showScanner)
                Card(
                  elevation: 4,
                  child: SizedBox(
                    height: 300,
                    child: MobileScanner(
                      onDetect: (capture) {
                        final List<Barcode> barcodes = capture.barcodes;
                        for (final barcode in barcodes) {
                          if (barcode.rawValue != null) {
                            _connectWithCrew(barcode.rawValue!);
                            setState(() {
                              _showScanner = false;
                            });
                            break;
                          }
                        }
                      },
                    ),
                  ),
                ),
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
              if (_successMessage != null)
                Card(
                  color: Colors.green.shade100,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _successMessage!,
                      style: const TextStyle(color: Colors.green),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
} 