import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePage extends StatelessWidget {
  final _supabase = Supabase.instance.client;

  Future<void> _logout(BuildContext context) async {
    await _supabase.auth.signOut();
    Navigator.pushReplacementNamed(context, '/auth');
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage: NetworkImage(user?.userMetadata?['avatar_url'] ?? ''),
            ),
            SizedBox(height: 16),
            Text(
              user?.userMetadata?['name'] ?? 'User Name',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              user?.userMetadata?['description'] ?? 'No description available.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              'Learning Badges',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            // Add badges here
            Spacer(),
            ElevatedButton(
              onPressed: () => _logout(context),
              child: Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
} 