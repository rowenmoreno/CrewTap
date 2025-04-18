import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import '../../../services/supabase_service.dart';
import '../../message/message_details/message_details_screen.dart';
import '../connect_controller.dart';

class ScanController extends GetxController {
  final ImagePicker _picker = ImagePicker();
  final hasScanned = false.obs;
  final isProcessing = false.obs;
  final selectedDuration = '24 hours'.obs;
  final durations = ['24 hours', '48 hours', '72 hours'];

  MobileScannerController get cameraController => Get.find<ConnectController>().cameraController;

  @override
  void onInit() {
    super.onInit();
  }

  @override
  void onClose() {
    super.onClose();
  }

  String generateUniqueGroupName() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');
    
    return 'Crew-${month}${day}-${hour}${minute}';
  }

  Future<String?> createGroupAndJoin(String groupName, String userId, String creatorId) async {
    try {
      final currentUser = SupabaseService.client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final now = DateTime.now().toUtc();
      final expiryTime = now.add(const Duration(hours: 24));
      final expiryTimeStr = expiryTime.toIso8601String();

      // Insert into chat table
      final chatResponse = await SupabaseService.client
          .from('chats')
          .insert({
            'name': groupName,
            'type': 'group',
            'created_at': now.toIso8601String(),
            'created_by': currentUser.id,
            'expiry_time': expiryTimeStr,
          })
          .select()
          .single();

      if (chatResponse == null) {
        throw Exception('Failed to create group chat');
      }

      debugPrint('Group chat created: ${chatResponse['id']}');

      // Add current user as participant
      await SupabaseService.client
          .from('chat_participants')
          .insert({
            'user_id': currentUser.id,
            'chat_id': chatResponse['id'],
            'joined_at': now.toIso8601String(),
          });

      await SupabaseService.client
          .from('chat_participants')
          .insert({
            'user_id': creatorId,
            'chat_id': chatResponse['id'],
            'joined_at': now.toIso8601String(),
          });

      debugPrint('User added to group chat');
      return chatResponse['id'];
    } catch (e) {
      debugPrint('Error creating group chat: $e');
      rethrow;
    }
  }

  Future<void> handleDetection(BarcodeCapture capture) async {
    if (hasScanned.value) return; // Prevent multiple scans

    final List<Barcode> barcodes = capture.barcodes;
    debugPrint('Barcode detection: ${barcodes.length} barcodes found');
    
    for (final barcode in barcodes) {
      if (barcode.rawValue == null) {
        debugPrint('Warning: Barcode with null raw value found');
        continue;
      }

      try {
        debugPrint('Processing barcode: ${barcode.rawValue}');
        final uri = Uri.parse(barcode.rawValue!);
        
        if (uri.scheme != 'crewtap') {
          debugPrint('Error: Invalid QR code format');
          Get.snackbar(
            'Error',
            'Invalid QR code format',
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
          continue;
        }

        // Handle group join QR codes
        if (uri.pathSegments[0] == 'join' && uri.pathSegments[1] == 'group') {
          final chatId = uri.pathSegments[2];
          final groupName = uri.pathSegments[3];
          
          await joinGroup(chatId, groupName);
          return;
        }

        // Handle crew connection QR codes
        final groupName = uri.pathSegments[1];
        final creatorId = uri.pathSegments[2];
        final creatorName = uri.pathSegments.length > 3 ? uri.pathSegments[3] : 'Name';
        final creatorRole = uri.pathSegments.length > 4 ? uri.pathSegments[4] : 'Role';
        
        debugPrint('Decoded QR data - Group: $groupName, Creator: $creatorId, Name: $creatorName, Role: $creatorRole');

        hasScanned.value = true;

        // Show dialog with creator's data from QR code
        showUserDataDialog({
          'group_name': groupName,
          'creator_id': creatorId,
          'creator_name': creatorName,
          'role': creatorRole,
        });
        
      } catch (e) {
        debugPrint('Error processing QR code: $e');
        Get.snackbar(
          'Error',
          'Invalid QR code format',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    }
  }

  Future<void> joinGroup(String chatId, String groupName) async {
    try {
      final currentUser = SupabaseService.client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Check if user is already in the group
      final existingParticipant = await SupabaseService.client
          .from('chat_participants')
          .select()
          .eq('chat_id', chatId)
          .eq('user_id', currentUser.id)
          .maybeSingle();

      if (existingParticipant != null) {
        Get.snackbar(
          'Info',
          'You are already a member of "$groupName"',
          backgroundColor: Colors.blue,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        // Navigate to the existing group chat
        Get.to(() => MessageDetailsScreen(
          chatId: chatId,
          recipientName: groupName,
          recipientId: chatId,
        ));
        return;
      }

      // Add user to chat participants
      await SupabaseService.client
          .from('chat_participants')
          .insert({
            'user_id': currentUser.id,
            'chat_id': chatId,
            'joined_at': DateTime.now().toIso8601String(),
          });

      Get.snackbar(
        'Success',
        'Successfully joined the group "$groupName"!',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      // Navigate to the newly joined group chat
      Get.to(() => MessageDetailsScreen(
        chatId: chatId,
        recipientName: groupName,
        recipientId: chatId,
      ));
    } catch (e) {
      debugPrint('Error joining group: $e');
      Get.snackbar(
        'Error',
        'Error joining group: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      hasScanned.value = false;
      Get.find<ConnectController>().startCamera();
    }
  }

  void showUserDataDialog(Map<String, dynamic> userData) {
    final TextEditingController groupNameController = TextEditingController(
      text: generateUniqueGroupName(),
    );
    
    Get.dialog(
      StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text(
            'QR Code Detected',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Connect with ${userData['creator_name']} (${userData['role']})',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Group Name',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: groupNameController,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Colors.grey[300]!,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Colors.grey[300]!,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Duration',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 0,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.grey[300]!,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Obx(() => DropdownButton<String>(
                      value: selectedDuration.value,
                      isExpanded: true,
                      underline: const SizedBox(),
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                      items: durations.map((String duration) {
                        return DropdownMenuItem<String>(
                          value: duration,
                          child: Text(duration),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          selectedDuration.value = newValue;
                        }
                      },
                    )),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Get.back();
                hasScanned.value = false;
                Get.find<ConnectController>().startCamera();
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey[700],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  // Convert duration string to hours
                  final hours = int.parse(selectedDuration.value.split(' ')[0]);
                  final chatId = await createGroupAndJoin(
                    groupNameController.text,
                    userData['creator_id'],
                    userData['creator_id'],
                  );
                  if (chatId != null) {
                    Get.back();
                    Get.snackbar(
                      'Success',
                      'Successfully joined the group!',
                      backgroundColor: Colors.green,
                      snackPosition: SnackPosition.BOTTOM,  
                      colorText: Colors.white,
                    );
                    // Navigate to the new group chat
                    Get.to(() => MessageDetailsScreen(
                      chatId: chatId,
                      recipientName: groupNameController.text,
                      recipientId: chatId,
                    ));
                  }
                } catch (e) {
                  Get.snackbar(
                    'Error',
                    'Error joining group: ${e.toString()}',
                    snackPosition: SnackPosition.BOTTOM, 
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                  );
                } finally {
                  hasScanned.value = false;
                  Get.find<ConnectController>().startCamera();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Create Connection'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> pickImage() async {
    try {
      isProcessing.value = true;
      final connectController = Get.find<ConnectController>();

      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) {
        isProcessing.value = false;
        return;
      }

      // Process the picked image using MobileScanner
      await connectController.stopCamera();
      await connectController.startCamera();
      await cameraController.analyzeImage(image.path);

      // The result will come through the normal onDetect callback
      // We don't need to process it here
      
    } catch (e) {
      debugPrint('Error processing image: $e');
      Get.snackbar(
        'Error',
        'Error processing image',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isProcessing.value = false;
    }
  }
} 