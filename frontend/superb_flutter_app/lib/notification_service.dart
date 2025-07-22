import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> init(String userId) async {
    try {
      print("🔧 初始化通知服務，用戶ID: $userId");
      
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        criticalAlert: false,
        provisional: false,
      );

      print("📋 通知權限狀態: ${settings.authorizationStatus}");

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print("✅ 使用者已授權推播");

        String? token = await _messaging.getToken();
        if (token != null) {
          print("🔥 FCM token: ${token.substring(0, 20)}...");

          await _uploadTokenIfNeeded(token, userId: userId);

          _messaging.onTokenRefresh.listen((newToken) async {
            print("🔁 Token 更新：${newToken.substring(0, 20)}...");
            await _uploadTokenIfNeeded(newToken, userId: userId, isRefresh: true);
          });

          FirebaseMessaging.onMessage.listen((message) {
            print("📩 前景收到通知：${message.notification?.title}");
            // 當應用在前景時收到通知，可以在這裡顯示本地通知
            if (message.notification != null) {
              print("📱 通知內容: ${message.notification!.body}");
            }
          });

          // 處理應用冷啟動時的通知
          RemoteMessage? initialMessage = await _messaging.getInitialMessage();
          if (initialMessage != null) {
            print("🚀 應用冷啟動收到通知");
            _handleNotificationTap(initialMessage);
          }

          // 處理應用在背景時點擊通知
          FirebaseMessaging.onMessageOpenedApp.listen((message) {
            print("👆 用戶點擊了背景通知");
            _handleNotificationTap(message);
          });
        } else {
          print("❌ 無法獲取 FCM token");
        }

      } else if (settings.authorizationStatus == AuthorizationStatus.denied) {
        print("🚫 使用者拒絕授權通知");
      } else if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        print("❓ 通知權限尚未確定");
      }
    } catch (e) {
      print("❌ 初始化通知服務失敗: $e");
    }
  }

  static void _handleNotificationTap(RemoteMessage message) {
    final data = message.data; // notification 點擊時附帶的 data payload

    print("🧭 使用者點了通知：${message.notification?.title}");
    print("📦 附帶資料：$data");

    // 範例：導頁到某個錯題詳情頁面（你可以根據 data 做對應路由處理）
    // Navigator.of(context).pushNamed('/review', arguments: data['questionId']);
  }

  static Future<void> _uploadTokenIfNeeded(String? newToken,
      {required String userId, bool isRefresh = false}) async {
    if (newToken == null) return;

    final prefs = await SharedPreferences.getInstance();
    final lastToken = prefs.getString('firebase_token_last');

    // 如果沒變就略過（但 refresh 時例外）
    if (newToken == lastToken && !isRefresh) {
      print("ℹ️ Token 未變更，不需要上傳");
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://superb-backend-1041765261654.asia-east1.run.app/notifications/register_token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "user_id": userId,
          "firebase_token": newToken,
          "old_token": isRefresh ? lastToken : null,
          "device_info": "Flutter App / Android or iOS"
        }),
      );

      if (response.statusCode == 200) {
        print("✅ Token 上傳成功：$newToken");
        await prefs.setString('firebase_token_last', newToken);
      } else {
        print("❌ Token 上傳失敗：${response.body}");
      }
    } catch (e) {
      print("❌ 上傳 token 發生錯誤：$e");
    }
  }
}
