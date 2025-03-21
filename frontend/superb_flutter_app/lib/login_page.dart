import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_page.dart';

class LoginPage extends StatelessWidget {
  // 使用您的 Google 客戶端 ID
  final String clientId = '426092249907-e5ff9jmpceiads6n4sfkof2uemjcrhm5.apps.googleusercontent.com';
  
  // 初始化 GoogleSignIn，並傳遞 clientId
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '426092249907-e5ff9jmpceiads6n4sfkof2uemjcrhm5.apps.googleusercontent.com',
  );
  
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _handleSignIn(BuildContext context) async {
    try {
      // 使用 Google 登入
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print("Google sign-in was canceled.");
        return; // 用戶取消了登入
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