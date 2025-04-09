import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nearby_service/nearby_service.dart';
import '../../../services/supabase_service.dart';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:async';

enum AppState { idle, discovering, connected }

class TapTab extends StatefulWidget {
  const TapTab({
    super.key,
    required this.userId,
    required this.displayName,
    required this.position,
  });

  final String userId;
  final String displayName;
  final String position;

  @override
  State<TapTab> createState() => _TapTabState();
}

class _TapTabState extends State<TapTab> {
  bool _isNearbySessionStarted = false;
  final _nearbyService = NearbyService.getInstance(
    logLevel: NearbyServiceLogLevel.debug,
  );
  final _supabase = SupabaseService.client;
  List<NearbyDevice> _discoveredPeers = [];
  bool _isCreatingGroup = false;
  bool _isIosBrowser = true; // For iOS, we'll be the browser by default
  StreamSubscription? _peersSubscription;
  CommunicationChannelState _communicationChannelState = CommunicationChannelState.notConnected;
  NearbyDevice? _connectedDevice;
  AppState _state = AppState.idle;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _peersSubscription?.cancel();
    if (_isNearbySessionStarted) {
      _nearbyService.disconnectById('crew_link_group');
    }
    super.dispose();
  }

  Future<void> _initialize() async {
    await _nearbyService.initialize();
    _startNearbySession();
  }

  Future<void> _startNearbySession() async {
    try {
      // Check platform-specific requirements
      if (Platform.isIOS) {
        _nearbyService.ios?.setIsBrowser(value: _isIosBrowser);
      } else if (Platform.isAndroid) {
        final isGranted = await _nearbyService.android?.requestPermissions();
        final wifiEnabled = await _nearbyService.android?.checkWifiService();
        if (!(isGranted ?? false) || !(wifiEnabled ?? false)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permissions or WiFi not available')),
          );
          return;
        }
      }

      setState(() {
        _isNearbySessionStarted = true;
        _state = AppState.discovering;
      });

      // Start discovery
      final result = await _nearbyService.discover();
      if (result) {
        // Listen for peers
        _peersSubscription = _nearbyService.getPeersStream().listen((peers) {
          setState(() {
            _discoveredPeers = peers;
          });
        });
      }
    } catch (e) {
      developer.log('Error starting nearby session: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start nearby session: $e')),
      );
    }
  }

  Future<void> _connect(NearbyDevice device) async {
    try {
      final result = await _nearbyService.connectById(device.info.id);
      if (result || device.status.isConnected) {
        // Start communication channel
        _nearbyService.startCommunicationChannel(
          NearbyCommunicationChannelData(
            device.info.id,
            filesListener: NearbyServiceFilesListener(
              onData: (pack) {
                // Handle received files if needed
              },
            ),
            messagesListener: NearbyServiceMessagesListener(
              onData: _messagesListener,
              onCreated: () {
                setState(() {
                  _connectedDevice = device;
                  _state = AppState.connected;
                });
              },
              onError: (e, [StackTrace? s]) {
                developer.log('Communication error: $e');
                setState(() {
                  _connectedDevice = null;
                  _state = AppState.discovering;
                });
              },
              onDone: () {
                setState(() {
                  _connectedDevice = null;
                  _state = AppState.discovering;
                });
              },
            ),
          ),
        );
      }
    } catch (e) {
      developer.log('Error connecting to peer: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to connect: $e')),
      );
    }
  }

  void _messagesListener(ReceivedNearbyMessage<NearbyMessageContent> message) {
    

      message.content.byType(
      onTextRequest: (request) {
        try {
        final messageText = request.value;
        developer.log('Received message: $messageText');

        // Parse the user info from the message
        final userInfo = <String, String>{};
        final parts = messageText.split(',');
        for (final part in parts) {
          final keyValue = part.split(':');
          if (keyValue.length == 2) {
            userInfo[keyValue[0].trim()] = keyValue[1].trim();
          }
        }

        if (userInfo.isNotEmpty) {
          _showGroupChatDialog(userInfo);
        }
      } catch (e) {
        developer.log('Error parsing message: $e');
      }
      },
      onTextResponse: (response) {
      },
      onFilesRequest: (request) {
      },
      onFilesResponse: (response) {
      },
    );
  }

  Future<void> _showGroupChatDialog(Map<String, String> userInfo) async {
    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Group Chat Invitation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('User: ${userInfo['displayName']}'),
            Text('Position: ${userInfo['position']}'),
            Text('Role: ${userInfo['role']}'),
            const SizedBox(height: 16),
            const Text('Would you like to join this group chat?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Decline'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Accept'),
          ),
        ],
      ),
    );

    if (result == true) {
      // User accepted the invitation
      if (userInfo['userId'] != null) {
        final selectedPeers = [
          {
            'userId': userInfo['userId'],
            'displayName': userInfo['displayName'],
            'position': userInfo['position'],
          }
        ];
        await _createGroupChat(selectedPeers);
      }
    }
  }

  Future<void> _disconnect() async {
    try {
      if (_connectedDevice != null) {
        await _nearbyService.disconnectById(_connectedDevice!.info.id);
      }
      await _nearbyService.endCommunicationChannel();
      await _nearbyService.stopDiscovery();
      await _peersSubscription?.cancel();
      setState(() {
        _connectedDevice = null;
        _state = AppState.idle;
        _discoveredPeers = [];
      });
    } catch (e) {
      developer.log('Error disconnecting: $e');
    }
  }

  Future<void> _sendUserInfoToPeer(NearbyDevice device) async {
    try {
      final userInfo = {
        'userId': widget.userId,
        'displayName': widget.displayName,
        'position': widget.position,
        'role': _isIosBrowser ? 'browser' : 'advertiser',
      };

      // Start a new communication channel to send the user info
      _nearbyService.startCommunicationChannel(
        NearbyCommunicationChannelData(
          device.info.id,
          messagesListener: NearbyServiceMessagesListener(
            onData: _messagesListener,
            onCreated: () {
              developer.log('Communication channel created for sending user info: $userInfo');
              // The message will be sent through the channel
            },
          ),
        ),
      );
    } catch (e) {
      developer.log('Error sending user info: $e');
    }
  }

  Future<void> _createGroupChat(List<Map<String, dynamic>> selectedPeers) async {
    if (_isCreatingGroup) return;

    setState(() {
      _isCreatingGroup = true;
    });

    try {
      // Send user info to the connected peer
      if (_connectedDevice != null) {
        await _sendUserInfoToPeer(_connectedDevice!);
      }

      // Create a new chat
      final chatResponse = await _supabase.from('chats').insert({
        'type': 'group',
        'name': 'Group Chat',
        'created_by': widget.userId,
      }).select().single();

      final chatId = chatResponse['id'];

      // Add all participants
      final participants = [
        {'user_id': widget.userId, 'chat_id': chatId},
        ...selectedPeers.map((peer) => {
          'user_id': peer['userId'],
          'chat_id': chatId,
        }),
      ];

      await _supabase.from('chat_participants').insert(participants);

      // Stop nearby session
      if (_isNearbySessionStarted) {
        await _nearbyService.disconnectById('crew_link_group');
        await _nearbyService.endCommunicationChannel();
        await _nearbyService.stopDiscovery();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group chat created successfully')),
        );
        Navigator.pop(context, true); // Return to previous screen with success
      }
    } catch (e) {
      developer.log('Error creating group chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create group chat: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingGroup = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_state == AppState.idle) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (Platform.isIOS) ...[
            const Text(
              'Select Your Role',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  RadioListTile<bool>(
                    title: const Text('Browser'),
                    subtitle: const Text('Search for nearby devices'),
                    value: true,
                    groupValue: _isIosBrowser,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _isIosBrowser = value;
                          _nearbyService.ios?.setIsBrowser(value: value);
                        });
                      }
                    },
                  ),
                  RadioListTile<bool>(
                    title: const Text('Advertiser'),
                    subtitle: const Text('Make yourself discoverable'),
                    value: false,
                    groupValue: _isIosBrowser,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _isIosBrowser = value;
                          _nearbyService.ios?.setIsBrowser(value: value);
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          ElevatedButton(
            onPressed: _startNearbySession,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: Text(Platform.isIOS 
              ? 'Start ${_isIosBrowser ? 'Browsing' : 'Advertising'}'
              : 'Start Discovery'),
          ),
        ],
      );
    } else if (_state == AppState.discovering) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (Platform.isIOS)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isIosBrowser ? Icons.search : Icons.broadcast_on_personal,
                    color: Colors.blue[900],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'You are ${_isIosBrowser ? 'Browser' : 'Advertiser'}',
                    style: TextStyle(
                      color: Colors.blue[900],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          // const Text(
          //   'Discovered Peers:',
          //   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          // ),
          // const SizedBox(height: 16),
          Expanded(
            child: _discoveredPeers.isEmpty
                ? const Center(child: Text('Searching for peers...'))
                : ListView.builder(
                    itemCount: _discoveredPeers.length,
                    itemBuilder: (context, index) {
                      final peer = _discoveredPeers[index];
                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person),
                        ),
                        title: Text(peer.info.displayName),
                        // subtitle: Text(peer.info.extraData['position'] ?? ''),
                        trailing: IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () => _connect(peer),
                        ),
                      );
                    },
                  ),
          ),
          if (_discoveredPeers.length >= 2)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: _isCreatingGroup
                    ? null
                    : () => _createGroupChat(_discoveredPeers.map((peer) => {
                          'userId': peer.info.id,
                          'displayName': peer.info.displayName,
                          // 'position': peer.info.extraData['position'],
                        }).toList()),
                child: _isCreatingGroup
                    ? const CircularProgressIndicator()
                    : const Text('Create Group with All Peers'),
              ),
            ),
        ],
      );
    } else if (_state == AppState.connected) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(_connectedDevice!.info.displayName),
            // subtitle: Text(_connectedDevice!.info.extraData['position'] ?? ''),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              onPressed: _disconnect,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isCreatingGroup
                ? null
                : () => _createGroupChat([{
                      'userId': _connectedDevice!.info.id,
                      'displayName': _connectedDevice!.info.displayName,
                      // 'position': _connectedDevice!.info.extraData['position'],
                    }]),
            child: _isCreatingGroup
                ? const CircularProgressIndicator()
                : const Text('Create Group Chat'),
          ),
        ],
      );
    }
    return Container();
  }
} 