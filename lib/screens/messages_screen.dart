import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; // For date formatting
import '../../services/supabase_service.dart';
import 'dart:async'; // For Timer
import 'message_details_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _chats = [];
  final _supabase = SupabaseService.client;
  StreamSubscription<List<Map<String, dynamic>>>? _chatsSubscription;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initializeMessagesScreen();
    _startTimer();
  }

  @override
  void dispose() {
    _chatsSubscription?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    // Update remaining time every second
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {}); // Trigger rebuild to update remaining time
      }
    });
  }

  void _initializeMessagesScreen() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = "User not logged in.";
      });
      return;
    }

    // Listen for real-time changes in chats and messages
    final chatsStream = _supabase
        .from('chats')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false); // Adjust order as needed


    _chatsSubscription = chatsStream.listen((chatsData) async {
       if (!mounted) return;
      setState(() {
        _isLoading = true; // Set loading true while processing new data
      });
      try {
         final userChats = await _supabase
            .from('chat_participants')
            .select('chat_id')
            .eq('user_id', userId);

         final chatIds = userChats.map((p) => p['chat_id'] as String).toList();

         if (chatIds.isEmpty) {
           setState(() {
                _chats = [];
                _isLoading = false;
            });
            return;
         }

        // Filter chatsData based on user participation
        final filteredChatsData = chatsData.where((chat) => chatIds.contains(chat['id'])).toList();


        List<Map<String, dynamic>> updatedChats = [];
        for (var chat in filteredChatsData) {
          // Fetch last message for each chat
          final lastMessageResponse = await _supabase
              .from('chat_messages')
              .select('content, created_at')
              .eq('chat_id', chat['id'])
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle(); // Use maybeSingle to handle chats with no messages

            chat['last_message'] = lastMessageResponse?['content'] ?? 'No messages yet';
            chat['last_message_time'] = lastMessageResponse?['created_at'];

            // Fetch participants to determine if it's a private chat and get the other user's name if so
            if (chat['type'] == 'private') {
                 final participants = await _supabase
                    .from('chat_participants')
                    .select('user_id')
                    .eq('chat_id', chat['id']);

                 if(participants.length == 2) {
                    final otherUserId = participants.firstWhere((p) => p['user_id'] != userId)['user_id'];
                    final otherUserProfile = await _supabase
                        .from('profiles')
                        .select('display_name')
                        .eq('id', otherUserId)
                        .single();
                    chat['name'] = otherUserProfile['display_name'] ?? 'Private Chat'; // Use display name if available
                 } else {
                     chat['name'] = 'Private Chat'; // Fallback name
                 }

            } // Group chats should already have a 'name'

          updatedChats.add(chat);
        }

         // Filter out expired chats before setting state
          final now = DateTime.now();
          updatedChats = updatedChats.where((chat) {
              final expiryTimeStr = chat['expiry_time'] as String?;
              if (expiryTimeStr == null) return true; // Never expires
              final expiryTime = DateTime.tryParse(expiryTimeStr);
              return expiryTime != null && expiryTime.isAfter(now);
          }).toList();


        // Sort chats by last message time (most recent first)
        updatedChats.sort((a, b) {
             final timeA = a['last_message_time'] != null ? DateTime.parse(a['last_message_time']) : DateTime(1970);
             final timeB = b['last_message_time'] != null ? DateTime.parse(b['last_message_time']) : DateTime(1970);
             return timeB.compareTo(timeA); // Descending order
        });


        setState(() {
          _chats = updatedChats;
          _isLoading = false;
          _errorMessage = null;
        });
      } catch (e) {
        if (mounted) {
            setState(() {
                _isLoading = false;
                _errorMessage = "Failed to load chats: ${e.toString()}";
            });
        }
        debugPrint("Error fetching chat data: $e");
      }
    }, onError: (error) {
       if (mounted) {
            setState(() {
                _isLoading = false;
                _errorMessage = "Error listening to chats: ${error.toString()}";
            });
       }
       debugPrint("Error in chat stream: $error");
    });
  }

 String _formatRemainingTime(String? expiryTimeString) {
    if (expiryTimeString == null) {
      return 'Never expires'; // Or return empty string: ''
    }
    final expiryTime = DateTime.tryParse(expiryTimeString);
    if (expiryTime == null) {
      return 'Invalid date';
    }

    final now = DateTime.now();
    final difference = expiryTime.difference(now);

    if (difference.isNegative) {
      return 'Expired';
    }

    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;
    final seconds = difference.inSeconds % 60;

    if (days > 0) {
        return '$days day${days > 1 ? 's' : ''}, $hours hr${hours > 1 ? 's' : ''} left';
    } else if (hours > 0) {
      return '$hours hr${hours > 1 ? 's' : ''}, $minutes min${minutes > 1 ? 's' : ''} left';
    } else if (minutes > 0) {
      return '$minutes min${minutes > 1 ? 's' : ''}, $seconds sec${seconds > 1 ? 's' : ''} left';
    } else {
      return '$seconds sec${seconds > 1 ? 's' : ''} left';
    }
  }

  String _formatLastMessageTime(String? timeString) {
      if (timeString == null) return '';
      try {
        final dateTime = DateTime.parse(timeString).toLocal();
        final now = DateTime.now();
        final difference = now.difference(dateTime);

        if (difference.inDays > 0) {
          return DateFormat.Md().format(dateTime); // e.g., "7/10"
        } else {
          return DateFormat.jm().format(dateTime); // e.g., "10:30 AM"
        }
      } catch (e) {
        return ''; // Handle parsing error
      }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        // Add actions like 'New Group' if needed
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search messages',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              // Add onChanged handler for search functionality later
            ),
          ),
          Expanded(
            child: _buildChatList(),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Error: $_errorMessage Please try again later.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red[700]),
          ),
        ),
      );
    }

    if (_chats.isEmpty) {
      return _buildEmptyState(); // Use the existing empty state widget
    }

    // Use ListView.separated for dividers
    return ListView.separated(
      itemCount: _chats.length,
      separatorBuilder: (context, index) => Divider(height: 1, indent: 72, color: Colors.grey[200]), // Add dividers
      itemBuilder: (context, index) {
        final chat = _chats[index];
        return _buildChatListItem(chat);
      },
    );
  }

  Widget _buildChatListItem(Map<String, dynamic> chat) {
    final isGroup = chat['type'] == 'group';
    final chatName = chat['name'] ?? (isGroup ? 'Group Chat' : 'Private Chat');
    final lastMessage = chat['last_message'] as String? ?? '';
    final lastMessageTime = _formatLastMessageTime(chat['last_message_time'] as String?);
    final remainingTime = _formatRemainingTime(chat['expiry_time'] as String?);
    final bool hasExpired = remainingTime == 'Expired';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.grey[300],
        child: Icon(
          isGroup ? Icons.group : Icons.person,
          color: Colors.white,
        ),
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              chatName,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: hasExpired ? Colors.grey : Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (lastMessageTime.isNotEmpty)
            Text(
              lastMessageTime,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
        ],
      ),
      subtitle: Row(
         mainAxisAlignment: MainAxisAlignment.spaceBetween,
         children: [
            Expanded(
                child: Text(
                    lastMessage,
                    style: TextStyle(color: hasExpired ? Colors.grey : Colors.grey[700]),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                ),
            ),
            if (chat['expiry_time'] != null && !hasExpired)
                 Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Text(
                       remainingTime,
                       style: const TextStyle(
                          fontSize: 11,
                          color: Colors.orange,
                          fontWeight: FontWeight.w500
                        ),
                    ),
                 )
             else if (hasExpired)
                  Padding(
                     padding: const EdgeInsets.only(left: 8.0),
                     child: Text(
                       'Expired',
                       style: TextStyle(
                          fontSize: 11,
                          color: Colors.red[400],
                          fontWeight: FontWeight.w500
                        ),
                     ),
                  )
         ],
      ),
      onTap: hasExpired ? null : () {
        // Get the recipient ID for private chats
        String recipientId = '';
        if (!isGroup) {
          final participants = chat['participants'] as List<dynamic>?;
          if (participants != null) {
            final currentUserId = _supabase.auth.currentUser?.id;
            recipientId = participants.firstWhere(
              (p) => p['user_id'] != currentUserId,
              orElse: () => {'user_id': ''},
            )['user_id'];
          }
        }
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MessageDetailsScreen(
              chatId: chat['id'],
              recipientName: chatName,
              recipientId: recipientId,
            ),
          ),
        );
      },
      tileColor: hasExpired ? Colors.grey[100] : null,
    );
  }


   Widget _buildEmptyState() {
     // Reusing the existing empty state design
     return Center(
       child: Column(
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
           Container(
             width: 48,
             height: 48,
             decoration: BoxDecoration(
               shape: BoxShape.circle,
               color: Colors.grey[200],
             ),
             child: Icon(
               Icons.chat_bubble_outline,
               color: Colors.grey[400],
               size: 24,
             ),
           ),
           const SizedBox(height: 16),
           const Text(
             'No conversations yet',
             style: TextStyle(
               fontSize: 16,
               fontWeight: FontWeight.w500,
               color: Colors.black87,
             ),
           ),
           const SizedBox(height: 8),
           Text(
             'Scan a QR code or tap a device to get\nstarted', // Updated text
             textAlign: TextAlign.center,
             style: TextStyle(
               fontSize: 14,
               color: Colors.grey[600],
               height: 1.5,
             ),
           ),
           // Optionally remove or redirect the 'Create a Group' button
           // if group creation happens elsewhere
           /*
           const SizedBox(height: 24),
           ElevatedButton(
             onPressed: () {
               // TODO: Implement or navigate to group creation
             },
             style: ElevatedButton.styleFrom(
               backgroundColor: Colors.white,
               foregroundColor: Colors.black87,
               elevation: 0,
               side: BorderSide(color: Colors.grey[300]!),
               padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
               shape: RoundedRectangleBorder(
                 borderRadius: BorderRadius.circular(8),
               ),
             ),
             child: const Text(
               'Create a Group',
               style: TextStyle(
                 fontSize: 14,
                 fontWeight: FontWeight.w500,
               ),
             ),
           ),
           */
         ],
       ),
     );
   }
}

// TODO: Create ChatDetailScreen widget for navigation
