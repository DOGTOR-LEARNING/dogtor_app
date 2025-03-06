import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'profile.dart'; // Import the ProfilePage
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthPage extends StatefulWidget {
  @override
  _AuthPageState createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _gradeController = TextEditingController();
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final session = _supabase.auth.currentSession;
    if (session != null) {
      _navigateToProfile();
    }
  }

  Future<void> _register() async {
    final response = await http.post(
      Uri.parse('http://127.0.0.1:8000/register'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        'email': _emailController.text,
        'password': _passwordController.text,
        'name': _nameController.text,
        'grade': _gradeController.text,
      }),
    );

    if (response.statusCode == 200) {
      _login(); // Automatically log in after registration
    } else {
      // Handle registration error
    }
  }

  Future<void> _login() async {
    final response = await http.post(
      Uri.parse('http://127.0.0.1:8000/login'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        'email': _emailController.text,
        'password': _passwordController.text,
      }),
    );

    if (response.statusCode == 200) {
      _navigateToProfile();
    } else {
      // Handle login error
    }
  }

Future<void> _loginWithGoogle() async {
  final supabase = Supabase.instance.client; // 取得 Supabase 用戶端
  try {
    await supabase.auth.signInWithOAuth( 
      OAuthProvider.google, // 這裡的 Provider.google 來自 supabase_flutter
      //redirectTo: 'io.supabase.flutter://login-callback/',
    );
  } catch (e) {
    print('Error: $e');  // 只在 debug 模式下使用 print
  }
}


  void _navigateToProfile() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => ProfilePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('User Authentication')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
          
            ElevatedButton(
              onPressed: _register,
              child: Text('Register'),
            ),
            ElevatedButton(
              onPressed: _login,
              child: Text('Login'),
            ),
            ElevatedButton(
              onPressed: _loginWithGoogle,
              child: Text('Continue with Google'),
            ),
          ],
        ),
      ),
    );
  }
} 