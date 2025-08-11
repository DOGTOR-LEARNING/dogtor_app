import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'home_page.dart';

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
      Uri.parse(
          'https://superb-backend-1041765261654.asia-east1.run.app/register'),
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
    try {
      final response = await http.post(
        Uri.parse(
            'https://superb-backend-1041765261654.asia-east1.run.app/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'email': _emailController.text,
          'password': _passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        // 登入成功後導向首頁
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage()),
        );
      } else {
        // 顯示錯誤提示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('登入失敗：${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('網路錯誤：$e')),
      );
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
