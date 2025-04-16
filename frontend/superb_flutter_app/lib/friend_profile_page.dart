import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendProfilePage extends StatefulWidget {
  final Map<String, dynamic> friend;

  // 定義主題顏色
  static const Color primaryBlue = Color(0xFF319cb6);  // 海洋藍
  static const Color accentOrange = Color(0xFFf59b03);  // 強調橙色
  static const Color backgroundWhite = Color(0xFFFFF9F7);  // 白色背景
  static const Color textBlue = Color(0xFF0777B1);     // 深藍色文字
  static const Color cardBlue = Color(0xFFECF6F9);     // 卡片背景色
  static const Color progressGreen = Color(0xFF4CAF50); // 進度綠色

  const FriendProfilePage({Key? key, required this.friend}) : super(key: key);

  @override
  _FriendProfilePageState createState() => _FriendProfilePageState();
}

class _FriendProfilePageState extends State<FriendProfilePage> {
  Map<String, dynamic> learningStats = {
    'streak_days': 0,
    'current_streak_days': 0,
    'max_streak_days': 0,
    'total_completed_questions': 0,
    'today_completed_levels': 0,
  };
  bool isLoading = true;
  bool isSendingNotification = false;
  
  // 學習記錄日期集合
  Set<DateTime> _learningDays = {};
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _fetchLearningStats();
    _fetchLearningDays();
  }

  // 獲取學習天數記錄
  Future<void> _fetchLearningDays() async {
    try {
      final String userId = widget.friend['user_id'];
      final response = await http.get(
        Uri.parse('https://superb-backend-1041765261654.asia-east1.run.app/get_learning_days/$userId'),
        headers: {'Accept': 'application/json; charset=utf-8'},
      );
      
      if (response.statusCode == 200) {
        final jsonString = utf8.decode(response.bodyBytes);
        final data = json.decode(jsonString);
        print('學習日期記錄響應: $data');
        
        if (data['success'] == true) {
          setState(() {
            // 獲取當前連續學習天數
            if (data.containsKey('current_streak')) {
              learningStats['current_streak_days'] = data['current_streak'] ?? 0;
              // 同時更新顯示用的streak_days
              learningStats['streak_days'] = data['current_streak'] ?? 0;
            }
            
            // 獲取歷史最高連續學習天數
            if (data.containsKey('total_streak')) {
              learningStats['max_streak_days'] = data['total_streak'] ?? 0;
            }
            
            // 轉換日期字符串到 DateTime 對象
            if (data.containsKey('learning_days') && data['learning_days'] != null) {
              _learningDays = Set<DateTime>.from(
                (data['learning_days'] as List).map((dateStr) {
                  final date = DateTime.parse(dateStr);
                  // 只保留年月日部分，去除時分秒
                  return DateTime(date.year, date.month, date.day);
                })
              );
              print('學習日期集合: $_learningDays');
            }
          });
        }
      }
    } catch (e) {
      print('獲取學習日期記錄時出錯: $e');
    }
  }

  // 檢查特定日期是否有學習記錄
  bool _isLearningDay(DateTime day) {
    // 只比較年月日，忽略時分秒
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final result = _learningDays.contains(normalizedDay);
    print('檢查日期 $normalizedDay 是否學習: $result');
    return result;
  }

  Future<void> _fetchLearningStats() async {
    setState(() {
      isLoading = true;
    });

    try {
      // 獲取每週學習統計
      final String userId = widget.friend['user_id'];
      final weeklyStatsResponse = await http.get(
        Uri.parse('https://superb-backend-1041765261654.asia-east1.run.app/get_weekly_stats/$userId'),
        headers: {'Accept': 'application/json; charset=utf-8'},
      );
      
      if (weeklyStatsResponse.statusCode == 200) {
        final jsonString = utf8.decode(weeklyStatsResponse.bodyBytes);
        final weeklyStatsData = json.decode(jsonString);
        print('weeklyStatsData: $weeklyStatsData');
        
        // 獲取今日完成的關卡數
        final today = DateTime.now().toString().split(' ')[0]; // 獲取當前日期 (YYYY-MM-DD)
        
        // 檢查是否有今天的數據
        int todayCompletedLevels = 0;
        if (weeklyStatsData.containsKey('daily_stats') && 
            weeklyStatsData['daily_stats'] != null) {
          final dailyStats = weeklyStatsData['daily_stats'] as List;
          for (var stat in dailyStats) {
            if (stat['date'] == today) {
              todayCompletedLevels = stat['completed_levels'] ?? 0;
              break;
            }
          }
        }
        
        // 嘗試獲取用戶整體統計
        final userStatsResponse = await http.post(
          Uri.parse('https://superb-backend-1041765261654.asia-east1.run.app/get_user_stats'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'user_id': userId}),
        );
        
        if (userStatsResponse.statusCode == 200) {
          final userStatsData = json.decode(userStatsResponse.body);
          print('userStatsData: $userStatsData');
          
          setState(() {
            // 從用戶統計獲取已完成問題數量 (保留但不顯示)
            learningStats['total_completed_questions'] = 
                userStatsData['stats']?['total_levels'] ?? 0;
            
            // 設置今日完成關卡數
            learningStats['today_completed_levels'] = todayCompletedLevels;
            
            isLoading = false;
          });
        } else {
          throw Exception('無法獲取用戶統計數據');
        }
      } else {
        throw Exception('無法獲取每週統計數據');
      }
    } catch (e) {
      print('獲取學習統計出錯: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  // 發送學習提醒通知
  Future<void> _sendLearningReminder() async {
    if (isSendingNotification) return;
    
    setState(() {
      isSendingNotification = true;
    });

    try {
      // 獲取當前登入用戶的 ID
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('未登入');
      }

      final String userId = widget.friend['user_id'];
      final response = await http.post(
        Uri.parse('https://superb-backend-1041765261654.asia-east1.run.app/send_learning_reminder'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userId,
          'sender_id': currentUser.uid,
          'message': '你的朋友 ${currentUser.displayName ?? '某人'} 提醒你該學習了！'
        }),
      );

      final jsonData = json.decode(response.body);
      print('學習提醒響應: $jsonData');
      
      if (response.statusCode == 200 && jsonData['success'] == true) {
        // 顯示成功提示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(jsonData['message'] ?? '學習提醒已成功發送！'),
            backgroundColor: FriendProfilePage.progressGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } else {
        // 後端返回錯誤但狀態碼是200
        final errorMessage = jsonData['message'] ?? '無法發送提醒通知';
        
        // 如果是權限或未註冊的問題，顯示特殊處理
        if (errorMessage.contains('尚未註冊推送通知') || 
            errorMessage.contains('無法接收通知')) {
          _showNotificationPermissionDialog(errorMessage);
        } else {
          throw Exception(errorMessage);
        }
      }
    } catch (e) {
      print('發送學習提醒出錯: $e');
      // 顯示錯誤提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().contains('Exception:') 
              ? e.toString().split('Exception:')[1].trim() 
              : '無法發送學習提醒，請稍後再試'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      setState(() {
        isSendingNotification = false;
      });
    }
  }
  
  // 顯示通知權限對話框
  void _showNotificationPermissionDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('無法發送提醒'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            SizedBox(height: 16),
            Text(
              '可能的原因：',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• 您的好友尚未登入應用程式'),
            Text('• 您的好友未允許推送通知權限'),
            Text('• 您的好友長時間未使用應用程式'),
            SizedBox(height: 16),
            Text(
              '您可以透過其他方式（例如訊息或電話）提醒他們。',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('我知道了'),
            style: TextButton.styleFrom(
              foregroundColor: FriendProfilePage.primaryBlue,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FriendProfilePage.backgroundWhite,
      appBar: AppBar(
        title: Text(
          '好友檔案',
          style: TextStyle(
            color: FriendProfilePage.textBlue,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: FriendProfilePage.backgroundWhite,
        elevation: 0,
        iconTheme: IconThemeData(color: FriendProfilePage.textBlue),
        actions: [
          // 添加發送提醒按鈕
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: isSendingNotification
                ? Container(
                    width: 40,
                    height: 40,
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          FriendProfilePage.primaryBlue),
                    ),
                  )
                : IconButton(
                    icon: Icon(CupertinoIcons.bell_fill),
                    color: FriendProfilePage.accentOrange,
                    tooltip: '提醒學習',
                    onPressed: _sendLearningReminder,
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 頭像和名字區域
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    FriendProfilePage.backgroundWhite,
                    FriendProfilePage.cardBlue.withOpacity(0.3),
                  ],
                ),
              ),
              child: Column(
                children: [
                  // 用戶頭像
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: FriendProfilePage.primaryBlue.withOpacity(0.3),
                          blurRadius: 15,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: FriendProfilePage.primaryBlue,
                      backgroundImage: widget.friend['photo_url'] != null && widget.friend['photo_url'].isNotEmpty
                          ? NetworkImage(widget.friend['photo_url'])
                          : null,
                      child: widget.friend['photo_url'] == null || widget.friend['photo_url'].isEmpty
                          ? Text(
                              (widget.friend['name'] ?? widget.friend['nickname'] ?? '?')[0].toUpperCase(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                  ),
                  SizedBox(height: 24),
                  // 用戶名稱
                  Text(
                    widget.friend['name'] ?? '',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: FriendProfilePage.textBlue,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  // 用戶暱稱（如果有）
                  if (widget.friend['nickname'] != null && widget.friend['nickname'].toString().isNotEmpty)
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: 16),
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: FriendProfilePage.accentOrange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.friend['nickname'],
                        style: TextStyle(
                          fontSize: 16,
                          color: FriendProfilePage.accentOrange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  SizedBox(height: 8),
                  // 歷史最高連續學習天數標籤
                  if (!isLoading && learningStats['max_streak_days'] > 0)
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: 16),
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: FriendProfilePage.progressGreen.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: FriendProfilePage.progressGreen.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.emoji_events,
                            color: FriendProfilePage.accentOrange,
                            size: 18,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '歷史最高連續 ${learningStats['max_streak_days']} 天',
                            style: TextStyle(
                              fontSize: 14,
                              color: FriendProfilePage.textBlue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            
            // 資訊卡片區域
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '用戶資訊',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: FriendProfilePage.textBlue,
                    ),
                  ),
                  SizedBox(height: 16),
                  if (widget.friend['email'] != null && widget.friend['email'].toString().isNotEmpty)
                    _buildProfileCard(
                      icon: Icons.email,
                      title: '電子郵件',
                      content: widget.friend['email'].toString(),
                    ),
                  if (widget.friend['year_grade'] != null && widget.friend['year_grade'].toString().isNotEmpty)
                    _buildProfileCard(
                      icon: Icons.school,
                      title: '年級',
                      content: widget.friend['year_grade'].toString(),
                    ),
                  if (widget.friend['introduction'] != null && widget.friend['introduction'].toString().isNotEmpty)
                    _buildProfileCard(
                      icon: Icons.person,
                      title: '自我介紹',
                      content: widget.friend['introduction'].toString(),
                    ),
                ],
              ),
            ),
            
            // 學習連續性區塊
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '學習進度',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: FriendProfilePage.textBlue,
                    ),
                  ),
                  SizedBox(height: 16),
                  isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            color: FriendProfilePage.primaryBlue,
                          ),
                        )
                      : _buildLearningStreakCard(),
                ],
              ),
            ),
            
            // 底部留白
            SizedBox(height: 32),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _sendLearningReminder,
        backgroundColor: FriendProfilePage.primaryBlue,
        icon: Icon(Icons.notifications_active, color: Colors.white),
        label: Text(
          '提醒學習',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // 學習連續性卡片
  Widget _buildLearningStreakCard() {
    final int currentStreakDays = learningStats['current_streak_days'] ?? 0;
    final int todayCompletedLevels = learningStats['today_completed_levels'] ?? 0;
    
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: FriendProfilePage.cardBlue,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 3),
          )
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 當前連續學習天數
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: FriendProfilePage.primaryBlue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.local_fire_department,
                        color: FriendProfilePage.accentOrange,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      '當前連續學習',
                      style: TextStyle(
                        color: FriendProfilePage.textBlue,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: FriendProfilePage.accentOrange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$currentStreakDays 天',
                    style: TextStyle(
                      fontSize: 16,
                      color: FriendProfilePage.accentOrange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            // 今日完成關卡數
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: FriendProfilePage.progressGreen.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.today,
                        color: FriendProfilePage.progressGreen,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      '今日完成關卡',
                      style: TextStyle(
                        color: FriendProfilePage.textBlue,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: FriendProfilePage.progressGreen.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$todayCompletedLevels 關',
                    style: TextStyle(
                      fontSize: 16,
                      color: FriendProfilePage.progressGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            
            // 近4週學習記錄日曆
            Text(
              '近期學習記錄',
              style: TextStyle(
                color: FriendProfilePage.textBlue,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 12),
            _buildLearningCalendar(),
          ],
        ),
      ),
    );
  }
  
  // 學習日曆組件
  Widget _buildLearningCalendar() {
    // 獲取過去7天日期
    final now = DateTime.now();
    final pastDays = List.generate(7, (index) => 
      DateTime(now.year, now.month, now.day - (6 - index)));
    
    // 星期幾的顯示文字
    final weekdayNames = ['一', '二', '三', '四', '五', '六', '日'];
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          )
        ],
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // 標題
          Text(
            '近7天學習記錄',
            style: TextStyle(
              color: FriendProfilePage.textBlue,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          // 日期圓點
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: pastDays.map((date) {
              final isToday = date.year == now.year && 
                             date.month == now.month && 
                             date.day == now.day;
              final hasLearned = _isLearningDay(date);
              
              // 決定顯示的顏色
              final baseColor = hasLearned 
                  ? FriendProfilePage.accentOrange
                  : Colors.grey.shade200;
              
              return Column(
                children: [
                  // 星期幾
                  Text(
                    weekdayNames[date.weekday - 1],
                    style: TextStyle(
                      color: isToday
                          ? FriendProfilePage.primaryBlue
                          : Colors.grey.shade700,
                      fontSize: 14,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  SizedBox(height: 8),
                  // 圓點或日期
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: baseColor,
                      border: isToday
                          ? Border.all(
                              color: FriendProfilePage.primaryBlue,
                              width: 2,
                            )
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        date.day.toString(),
                        style: TextStyle(
                          color: hasLearned ? Colors.white : Colors.grey.shade700,
                          fontWeight: isToday || hasLearned 
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  // 有學習記錄的顯示勾
                  if (hasLearned)
                    Icon(
                      Icons.check_circle,
                      color: FriendProfilePage.progressGreen,
                      size: 16,
                    )
                  else
                    SizedBox(height: 16),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: FriendProfilePage.cardBlue,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 3),
          )
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: FriendProfilePage.primaryBlue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: FriendProfilePage.primaryBlue,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    color: FriendProfilePage.textBlue,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FriendProfilePage.backgroundWhite,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                content,
                style: TextStyle(
                  color: FriendProfilePage.textBlue.withOpacity(0.8),
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}