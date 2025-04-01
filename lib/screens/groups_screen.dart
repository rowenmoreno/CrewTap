import 'package:flutter/material.dart';

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 8,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue[100],
                child: Icon(
                  Icons.group,
                  color: Colors.blue[700],
                ),
              ),
              title: Text('Group ${index + 1}'),
              subtitle: Text('${index + 5} members'),
              trailing: IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () {},
              ),
              onTap: () {},
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.group_add),
      ),
    );
  }
} 