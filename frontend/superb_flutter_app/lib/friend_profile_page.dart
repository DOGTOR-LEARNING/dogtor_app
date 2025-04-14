import 'package:flutter/material.dart';

class FriendProfilePage extends StatelessWidget {
  final Map<String, dynamic> friend;

  // 定義主題顏色
  static const Color primaryBlue = Color(0xFF4A90E2);  // 海洋藍
  static const Color lightBlue = Color(0xFFE3F2FD);    // 淺藍色背景
  static const Color textBlue = Color(0xFF5B8DB9);     // 文字藍色
  static const Color cardBlue = Color(0xFFF5F9FF);     // 卡片背景色

  const FriendProfilePage({Key? key, required this.friend}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          '好友檔案',
          style: TextStyle(
            color: textBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: textBlue),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 頭像和名字區域
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  // 用戶頭像
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: primaryBlue,
                    backgroundImage: friend['photo_url'] != null && friend['photo_url'].isNotEmpty
                        ? NetworkImage(friend['photo_url'])
                        : null,
                    child: friend['photo_url'] == null || friend['photo_url'].isEmpty
                        ? Text(
                            (friend['name'] ?? friend['nickname'] ?? '?')[0].toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  SizedBox(height: 24),
                  // 用戶名稱
                  Text(
                    friend['name'] ?? '',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: textBlue,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            // 資訊卡片區域
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  if (friend['year_grade'] != null && friend['year_grade'].toString().isNotEmpty)
                    _buildProfileCard(
                      icon: Icons.school,
                      title: '年級',
                      content: friend['year_grade'].toString(),
                    ),
                  if (friend['introduction'] != null && friend['introduction'].toString().isNotEmpty)
                    _buildProfileCard(
                      icon: Icons.person,
                      title: '自我介紹',
                      content: friend['introduction'].toString(),
                    ),
                ],
              ),
            ),
            // 底部留白
            SizedBox(height: 32),
          ],
        ),
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
        color: cardBlue,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: primaryBlue,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    color: textBlue,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              content,
              style: TextStyle(
                color: textBlue,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 