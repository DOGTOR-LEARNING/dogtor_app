// frontend/superb_flutter_app/lib/login_page.dart
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_page.dart';

class LoginPage extends StatelessWidget {
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _handleSignIn(BuildContext context) async {
    try {
      // 使用 Google 登入
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      // 檢查 googleUser 是否為 null
      if (googleUser == null) {
        // 用戶取消了登入，您可以選擇顯示一條消息或執行其他操作
        print("Google sign-in was canceled.");
        return; // 退出方法
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 創建一個新的憑證
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 使用 Firebase 登入
      await _auth.signInWithCredential(credential);
      
      // 登入成功後導航到首頁
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