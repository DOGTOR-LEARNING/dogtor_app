import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'home_page.dart';
import 'onboarding_chat.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'notification_service.dart';
import 'dart:io';


class LoginPage extends StatelessWidget {
  // 使用您的 Google 客戶端 ID
  final String clientId = '1041765261654-hv85kemgu2pjrmclc66h0itpshrrk3p2.apps.googleusercontent.com';
  
  // 初始化 GoogleSignIn，並傳遞 clientId
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '1041765261654-hv85kemgu2pjrmclc66h0itpshrrk3p2.apps.googleusercontent.com',
    // clientId: Platform.isIOS
    //   ? '426092249907-e5ff9jmpceiads6n4sfkof2uemjcrhm5.apps.googleusercontent.com'
    //   : null,
    scopes: ['email'],
    serverClientId: '1041765261654-jgpu9igp4l421b562pbrk5lpe4otadd7.apps.googleusercontent.com', // 使用新項目的 Web 客戶端 ID
    // serverClientId: '426092249907-jgnr6rj7mr3gtjuuo0u6jsmifi7a822s.apps.googleusercontent.com', // 舊項目 ID，已停用
  );
  
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // API 端點，用於檢查和創建用戶
  final String apiUrl = 'https://superb-backend-1041765261654.asia-east1.run.app';

  // 檢查用戶是否已登入
  Future<bool> _checkIfUserIsLoggedIn() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('user_id');
    print("📱 用戶 ID: $userId");
    if (userId != null){ await NotificationService.init(userId); } //取得FCM token
    return userId != null;
  }

  // 保存用戶登入狀態到 SharedPreferences
  Future<void> _saveUserLoginState(String userId, String email, String displayName, [String photoUrl = '']) async {
    try {
      print("開始保存用戶登入狀態...");
      SharedPreferences prefs = await SharedPreferences.getInstance();
      
      // 保存用戶數據
      await prefs.setString('user_id', userId);
      await prefs.setString('email', email);
      await prefs.setString('display_name', displayName);
      await prefs.setString('photo_url', photoUrl);
      
      // 輸出保存的數據，用於調試
      print("已保存的用戶數據：");
      print("user_id: $userId");
      print("email: $email");
      print("display_name: $displayName");
      print("photo_url: $photoUrl");
      
      // 檢查數據是否成功保存
      print("檢查保存的數據：");
      print("user_id: ${prefs.getString('user_id')}");
      print("email: ${prefs.getString('email')}");
      print("display_name: ${prefs.getString('display_name')}");
      print("photo_url: ${prefs.getString('photo_url')}");
      
      print("用戶登入狀態已保存");
    } catch (e) {
      print("保存用戶登入狀態時出錯: $e");
    }
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
          final createUrl = '$apiUrl/users/create';
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
          
          if (createResponse.statusCode == 200) {
            final userData = jsonDecode(createResponse.body);
            print("用戶創建成功，保存登入狀態...");
            
            // 從響應中獲取用戶數據
            final user = userData['user'];
            await _saveUserLoginState(
              user['user_id'] ?? firebaseUser.uid,
              user['email'] ?? firebaseUser.email ?? '',
              user['name'] ?? firebaseUser.displayName ?? '',
              user['photo_url'] ?? firebaseUser.photoURL ?? '',
            );
          }
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
        firebaseUser.photoURL ?? '',
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
        firebaseUser.photoURL ?? '',
      );
    }
  }

  Future<void> _handleSignIn(BuildContext context) async {
    print("hi handleSignIn");
    try {

      // 清除 Google Sign-In 的 cache
      //await _googleSignIn.signOut();
      //print("✅ Google Sign-In cache 已清除");
      
      
      // 檢查用戶是否已登入
      bool isLoggedIn = await _checkIfUserIsLoggedIn();
      if (isLoggedIn) {
        
        // 用戶已登入，直接導航到首頁

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => OnboardingChat()),
        );
        return;
      }
      

      print("開始 Google 登入");

      // 使用 Google 登入
      print("🔍 嘗試執行 Google Sign-In...");
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print("❌ Google Sign-In 被取消或失敗");
        return; // 用戶取消了登入
      }

      print("✅ Google Sign-In 成功: ${googleUser.email}");

      // 獲取 Google 認證
      print("🔍 嘗試獲取 Google Authentication...");
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      print("✅ Google Authentication 成功: Access Token: ${googleAuth.accessToken}, ID Token: ${googleAuth.idToken}");

      // 創建 Firebase 憑證
      print("🔍 嘗試創建 Firebase 憑證...");
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 使用 Firebase 登入
      print("🔍 嘗試使用 Firebase 登入...");
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;
      
      if (user != null) {
        print("✅ Firebase 登入成功: UID: ${user.uid}, Email: ${user.email}");

        // 檢查用戶是否存在於數據庫，如果不存在則創建
        print("🔍 嘗試檢查並創建用戶在數據庫...");
        await _checkAndCreateUserInDatabase(user);

        SharedPreferences prefs = await SharedPreferences.getInstance();
        String? userId = prefs.getString('user_id');
        print("💾 SharedPreferences 中的用戶 ID: $userId");

        if (userId != null) {
          print("🔍 嘗試初始化通知服務...");
          await NotificationService.init(userId);
          print("✅ 通知服務初始化成功");
        }

        // 登入成功後導航到首頁
        print("🏠 導航到首頁...");
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => OnboardingChat()),
        );
      } else {
        print("❌ Firebase 用戶為 null");
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
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/login-sea.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 應用程式標誌或名稱
                    SvgPicture.asset(
                      'assets/images/dogtor_logo.svg',
                      width: 70,
                      height: 100,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 30),
                    SvgPicture.asset(
                      'assets/images/dogtor_eng_logo.svg',
                      width: 150,
                      height: 30,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 25),
                    // Google 登入按鈕
                    ElevatedButton.icon(
                      onPressed: () => _handleSignIn(context),
                      icon: SvgPicture.asset(
                        'assets/images/google_icon.svg',
                        width: 24,
                        height: 24,
                      ),
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
            Positioned(
              left: 0,
              right: 0,
              bottom: -20,
              child: Image.asset(
                'assets/images/question-corgi.png',
                height: 280,
                alignment: Alignment.bottomCenter,
                fit: BoxFit.fitHeight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 在顯示用戶頭像的地方
  Widget buildUserAvatar(String? avatarUrl) {
    return avatarUrl != null
        ? CircleAvatar(
            backgroundImage: NetworkImage(avatarUrl),
            radius: 30,
          )
        : CircleAvatar(
            // 使用默認頭像
            child: Icon(Icons.person),
            radius: 30,
          );
  }
}