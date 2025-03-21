// frontend/superb_flutter_app/lib/login_page.dart
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'home_page.dart';

class LoginPage extends StatelessWidget {
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<void> _handleSignIn(BuildContext context) async {
    try {
      await _googleSignIn.signIn();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomePage()),
      );
    } catch (error) {
      print("Login failed: $error");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => _handleSignIn(context),
          child: Text('使用 Google 登入'),
        ),
      ),
    );
  }
}