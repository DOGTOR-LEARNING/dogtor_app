import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AuthPage extends StatefulWidget {
  @override
  _AuthPageState createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _gradeController = TextEditingController();

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
      // Handle successful registration
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
      // Handle successful login
    } else {
      // Handle login error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('User Authentication')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: _gradeController,
              decoration: InputDecoration(labelText: 'Grade'),
            ),
            ElevatedButton(
              onPressed: _register,
              child: Text('Register'),
            ),
            ElevatedButton(
              onPressed: _login,
              child: Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
} 