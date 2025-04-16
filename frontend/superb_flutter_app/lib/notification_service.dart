import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> init(String userId) async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print("✅ 使用者已授權推播");

      String? token = await _messaging.getToken();
      print("🔥 FCM token: $token");

      await _uploadTokenIfNeeded(token, userId: userId);

      _messaging.onTokenRefresh.listen((newToken) async {
        print("🔁 Token 更新：$newToken");
        await _uploadTokenIfNeeded(newToken, userId: userId, isRefresh: true);
      });

      FirebaseMessaging.onMessage.listen((message) {
        print("📩 前景收到通知：${message.notification?.title}");
        // TODO: 可搭配 flutter_local_notifications 顯示通知
      });

      // ⬇️ 加這段
      RemoteMessage? initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _handleNotificationTap(message);
      });

    } else {
      print("🚫 使用者拒絕授權通知");
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
        Uri.parse('https://superb-backend-1041765261654.asia-east1.run.app/register_token'),
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
