import 'package:flutter/material.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 10,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue[100],
                child: Text('U${index + 1}'),
              ),
              title: Text('User ${index + 1}'),
              subtitle: Text('Last message from User ${index + 1}'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${index + 1}:00 PM',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  if (index % 2 == 0)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              onTap: () {},
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.message),
      ),
    );
  }
} 