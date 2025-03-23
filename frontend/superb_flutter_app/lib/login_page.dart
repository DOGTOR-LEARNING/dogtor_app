import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'home_page.dart';

class LoginPage extends StatelessWidget {
  // 使用您的 Google 客戶端 ID
  final String clientId = '426092249907-e5ff9jmpceiads6n4sfkof2uemjcrhm5.apps.googleusercontent.com';
  
  // 初始化 GoogleSignIn，並傳遞 clientId
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '426092249907-e5ff9jmpceiads6n4sfkof2uemjcrhm5.apps.googleusercontent.com',
  );
  
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // API 端點，用於檢查和創建用戶
  final String apiUrl = 'https://superb-backend-1041765261654.asia-east1.run.app';

  // 檢查用戶是否已登入
  Future<bool> _checkIfUserIsLoggedIn() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('user_id');
    return userId != null;
  }

  // 保存用戶登入狀態
  Future<void> _saveUserLoginState(String userId, String email, String displayName) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', userId);
    await prefs.setString('email', email);
    await prefs.setString('display_name', displayName);
  }

  // 檢查用戶是否存在於數據庫，如果不存在則創建
  Future<void> _checkAndCreateUserInDatabase(User firebaseUser) async {
    try {
      // 輸出詳細的請求信息
      final requestUrl = '$apiUrl/users/check?user_id=${firebaseUser.uid}';
      print("正在發送請求到: $requestUrl");
      print("用戶 ID: ${firebaseUser.uid}");
      print("完整 API URL: $apiUrl");
      
      // 檢查用戶是否存在
      final response = await http.get(
        Uri.parse(requestUrl),
        headers: {'Content-Type': 'application/json'},
      );
      
      // 輸出詳細的響應信息
      print("API 響應狀態碼: ${response.statusCode}");
      print("API 響應內容: ${response.body}");
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("解析後的響應數據: $data");
        
        // 安全地檢查 'exists' 字段
        bool exists = data != null && data['exists'] == true;
        print("用戶是否存在: $exists");
        
        if (!exists) {
          // 用戶不存在，創建新用戶
          print("用戶不存在，正在創建新用戶...");
          final createUrl = '$apiUrl/users';
          print("創建用戶請求 URL: $createUrl");
          
          final createResponse = await http.post(
            Uri.parse(createUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_id': firebaseUser.uid,
              'email': firebaseUser.email,
              'name': firebaseUser.displayName,
              'photo_url': firebaseUser.photoURL,
              'created_at': DateTime.now().toIso8601String(),
            }),
          );
          
          print("創建用戶響應狀態碼: ${createResponse.statusCode}");
          print("創建用戶響應內容: ${createResponse.body}");
        }
      } else {
        print("API 錯誤: ${response.statusCode} - ${response.body}");
        // 如果 API 調用失敗，我們仍然保存本地登入狀態
      }
      
      // 保存用戶登入狀態
      print("正在保存用戶登入狀態...");
      await _saveUserLoginState(
        firebaseUser.uid,
        firebaseUser.email ?? '',
        firebaseUser.displayName ?? '',
      );
      print("用戶登入狀態已保存");
    } catch (error) {
      print("數據庫操作失敗: $error");
      print("錯誤堆疊: ${StackTrace.current}");
      // 即使數據庫操作失敗，仍然保存本地登入狀態
      await _saveUserLoginState(
        firebaseUser.uid,
        firebaseUser.email ?? '',
        firebaseUser.displayName ?? '',
      );
    }
  }

  Future<void> _handleSignIn(BuildContext context) async {
    try {
      // 檢查用戶是否已登入
      bool isLoggedIn = await _checkIfUserIsLoggedIn();
      if (isLoggedIn) {
        // 用戶已登入，直接導航到首頁
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage()),
        );
        return;
      }

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
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;
      
      if (user != null) {
        // 檢查用戶是否存在於數據庫，如果不存在則創建
        await _checkAndCreateUserInDatabase(user);
        
        // 登入成功後導航到首頁
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage()),
        );
      }
    } catch (error) {
      print("Login failed: $error");
      // 顯示錯誤提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('登入失敗，請稍後再試'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade300, Colors.blue.shade700],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 應用程式標誌或名稱
              Icon(
                Icons.pets,  // 可以替換成你的應用圖標
                size: 100,
                color: Colors.white,
              ),
              const SizedBox(height: 20),
              Text(
                'Dogtor',  // 替換成你的應用名稱
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 50),
              // Google 登入按鈕
              ElevatedButton.icon(
                onPressed: () => _handleSignIn(context),
                icon: Icon(Icons.g_mobiledata, size: 24),
                label: Text(
                  '使用 Google 登入',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}