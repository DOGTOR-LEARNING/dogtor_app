import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationStatusPage extends StatefulWidget {
  const NotificationStatusPage({super.key});

  @override
  _NotificationStatusPageState createState() => _NotificationStatusPageState();
}

class _NotificationStatusPageState extends State<NotificationStatusPage> {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  Map<String, dynamic>? _notificationStatus;
  String? _currentToken;
  String? _errorMessage;
  List<Map<String, dynamic>> _validTokens = [];
  List<Map<String, dynamic>> _invalidTokens = [];

  @override
  void initState() {
    super.initState();
    _checkNotificationPermission();
    _getCurrentToken();
  }

  Future<void> _checkNotificationPermission() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final settings = await _messaging.getNotificationSettings();
      final status = settings.authorizationStatus;

      setState(() {
        _notificationStatus = {
          'authorizationStatus': status.toString(),
          'isAuthorized': status == AuthorizationStatus.authorized,
          'showAlert': settings.alert.toString(),
          'showBadge': settings.badge.toString(),
          'showSound': settings.sound.toString(),
        };
      });
    } catch (e) {
      setState(() {
        _errorMessage = '檢查通知權限時出錯：$e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _getCurrentToken() async {
    try {
      final token = await _messaging.getToken();
      setState(() {
        _currentToken = token;
      });
      print('Current FCM token: $token');
    } catch (e) {
      print('獲取FCM令牌時出錯：$e');
    }
  }

  Future<void> _registerToken() async {
    if (_currentToken == null || _auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('無法註冊令牌：未登入或令牌為空')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = _auth.currentUser!;
      final response = await http.post(
        Uri.parse(
            'https://superb-backend-1041765261654.asia-east1.run.app/notifications/register_token'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': user.uid,
          'firebase_token': _currentToken,
          'device_info': 'Flutter App ${DateTime.now().toIso8601String()}'
        }),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(jsonData['message'] ?? '令牌註冊成功')),
        );
      } else {
        throw Exception('註冊令牌失敗：狀態碼 ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = '註冊令牌時出錯：$e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('註冊令牌時出錯：$e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkTokensValidity() async {
    if (_auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('請先登入')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _validTokens = [];
      _invalidTokens = [];
    });

    try {
      final user = _auth.currentUser!;
      final response = await http.post(
        Uri.parse(
            'https://superb-backend-1041765261654.asia-east1.run.app/validate_tokens'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': user.uid,
        }),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData['success'] == true) {
          setState(() {
            _validTokens =
                List<Map<String, dynamic>>.from(jsonData['valid_tokens'] ?? []);
            _invalidTokens = List<Map<String, dynamic>>.from(
                jsonData['invalid_tokens'] ?? []);
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    '令牌驗證完成：有效 ${jsonData['valid_tokens_count']}，無效 ${jsonData['invalid_tokens_count']}')),
          );
        } else {
          throw Exception(jsonData['message'] ?? '驗證令牌失敗');
        }
      } else {
        throw Exception('驗證令牌失敗：狀態碼 ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = '驗證令牌時出錯：$e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('驗證令牌時出錯：$e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendTestNotification() async {
    if (_currentToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('無法發送測試通知：令牌為空')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse(
            'https://superb-backend-1041765261654.asia-east1.run.app/notifications/send_test_push'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'token': _currentToken,
          'title': '測試通知',
          'body': '這是一條測試通知，時間：${DateTime.now().toString()}'
        }),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(jsonData['success'] == true
                  ? '測試通知已發送，請查看通知欄'
                  : '測試通知發送失敗：${jsonData['message']}')),
        );
      } else {
        throw Exception('發送測試通知失敗：狀態碼 ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = '發送測試通知時出錯：$e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('發送測試通知時出錯：$e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('通知系統狀態'),
        backgroundColor: Color(0xFF319cb6),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 通知權限狀態卡片
                  _buildCard(
                    title: '通知權限狀態',
                    child: _notificationStatus != null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildStatusItem('授權狀態',
                                  _notificationStatus!['authorizationStatus']),
                              _buildStatusItem(
                                  '是否已授權',
                                  _notificationStatus!['isAuthorized']
                                      .toString()),
                              _buildStatusItem(
                                  '顯示通知', _notificationStatus!['showAlert']),
                              _buildStatusItem(
                                  '顯示角標', _notificationStatus!['showBadge']),
                              _buildStatusItem(
                                  '播放聲音', _notificationStatus!['showSound']),
                              SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: _checkNotificationPermission,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF319cb6),
                                ),
                                child: Text('刷新權限狀態'),
                              ),
                            ],
                          )
                        : Text('無法獲取通知權限狀態'),
                  ),

                  SizedBox(height: 16),

                  // 推送令牌卡片
                  _buildCard(
                    title: '推送令牌',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '當前令牌:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _currentToken ?? '未獲取到令牌',
                            style: TextStyle(fontSize: 12),
                            softWrap: true,
                          ),
                        ),
                        SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton(
                              onPressed: _getCurrentToken,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF319cb6),
                              ),
                              child: Text('刷新令牌'),
                            ),
                            ElevatedButton(
                              onPressed: _registerToken,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFFf59b03),
                              ),
                              child: Text('註冊令牌'),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton(
                              onPressed: _sendTestNotification,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF4CAF50),
                              ),
                              child: Text('發送測試通知'),
                            ),
                            ElevatedButton(
                              onPressed: _checkTokensValidity,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF9C27B0),
                              ),
                              child: Text('檢查令牌有效性'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  if (_validTokens.isNotEmpty || _invalidTokens.isNotEmpty)
                    SizedBox(height: 16),

                  // 有效令牌列表
                  if (_validTokens.isNotEmpty)
                    _buildCard(
                      title: '有效令牌 (${_validTokens.length})',
                      child: Column(
                        children: _validTokens.map((token) {
                          return ListTile(
                            title: Text('${token['token_prefix']}...'),
                            subtitle:
                                Text('上次更新: ${token['last_updated'] ?? '未知'}'),
                            leading:
                                Icon(Icons.check_circle, color: Colors.green),
                          );
                        }).toList(),
                      ),
                    ),

                  if (_invalidTokens.isNotEmpty) SizedBox(height: 16),

                  // 無效令牌列表
                  if (_invalidTokens.isNotEmpty)
                    _buildCard(
                      title: '無效令牌 (${_invalidTokens.length})',
                      child: Column(
                        children: _invalidTokens.map((token) {
                          return ListTile(
                            title: Text('${token['token_prefix']}...'),
                            subtitle: Text('錯誤: ${token['error'] ?? '未知'}'),
                            leading: Icon(Icons.error, color: Colors.red),
                          );
                        }).toList(),
                      ),
                    ),

                  if (_errorMessage != null) SizedBox(height: 16),

                  // 錯誤信息
                  if (_errorMessage != null)
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red[900]),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0777B1),
              ),
            ),
            Divider(),
            SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: TextStyle(
              color: value.toLowerCase().contains('authorize') ||
                      value.toLowerCase() == 'true'
                  ? Colors.green
                  : value.toLowerCase() == 'false' ||
                          value.toLowerCase().contains('denied')
                      ? Colors.red
                      : Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
