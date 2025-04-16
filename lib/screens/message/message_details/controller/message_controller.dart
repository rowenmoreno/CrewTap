import 'package:get/get.dart';

class MessageController extends GetxController {
  final Rx<String> _currentMessage = ''.obs;
  
  String get currentMessage => _currentMessage.value;

  void updateMessage(String message) {
    _currentMessage.value = message;
  } 
}
