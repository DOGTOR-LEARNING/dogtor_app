import 'package:flutter/material.dart';

class FriendProfilePage extends StatelessWidget {
  final Map<String, dynamic> friend;

  // 定義主題顏色
  static const Color primaryBlue = Color(0xFF319cb6);  // 海洋藍
  static const Color accentOrange = Color(0xFFf59b03);  // 強調橙色
  static const Color backgroundWhite = Color(0xFFFFF9F7);  // 白色背景
  static const Color textBlue = Color(0xFF0777B1);     // 深藍色文字
  static const Color cardBlue = Color(0xFFECF6F9);     // 卡片背景色

  const FriendProfilePage({Key? key, required this.friend}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundWhite,
      appBar: AppBar(
        title: Text(
          '好友檔案',
          style: TextStyle(
            color: textBlue,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: backgroundWhite,
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
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    backgroundWhite,
                    cardBlue.withOpacity(0.3),
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
                          color: primaryBlue.withOpacity(0.3),
                          blurRadius: 15,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 60,
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
                  SizedBox(height: 8),
                  // 用戶暱稱（如果有）
                  if (friend['nickname'] != null && friend['nickname'].toString().isNotEmpty)
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: 16),
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: accentOrange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        friend['nickname'],
                        style: TextStyle(
                          fontSize: 16,
                          color: accentOrange,
                          fontWeight: FontWeight.bold,
                        ),
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
                      color: textBlue,
                    ),
                  ),
                  SizedBox(height: 16),
                  if (friend['email'] != null && friend['email'].toString().isNotEmpty)
                    _buildProfileCard(
                      icon: Icons.email,
                      title: '電子郵件',
                      content: friend['email'].toString(),
                    ),
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
                    color: primaryBlue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
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
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: backgroundWhite,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                content,
                style: TextStyle(
                  color: textBlue.withOpacity(0.8),
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