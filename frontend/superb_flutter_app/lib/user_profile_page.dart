import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';

class UserProfilePage extends StatefulWidget {
  @override
  _UserProfilePageState createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  String _userId = '';
  String _email = '';
  String _displayName = '';
  String _photoUrl = '';
  String _role = '學生'; // 預設身份
  String _bio = '這個人很懶，什麼都沒有留下...'; // 預設自我介紹

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // 從 SharedPreferences 加載用戶數據
  Future<void> _loadUserData() async {
    try {
      print("開始加載用戶數據...");
      SharedPreferences prefs = await SharedPreferences.getInstance();
      
      // 輸出所有保存的鍵值對，用於調試
      print("SharedPreferences 中的所有鍵：${prefs.getKeys()}");
      prefs.getKeys().forEach((key) {
        print("$key: ${prefs.get(key)}");
      });
      
      setState(() {
        _userId = prefs.getString('user_id') ?? '';
        _email = prefs.getString('email') ?? '';
        _displayName = prefs.getString('display_name') ?? '';
        _photoUrl = prefs.getString('photo_url') ?? '';
        
        print("加載的用戶數據：");
        print("用戶 ID: $_userId");
        print("電子郵件: $_email");
        print("顯示名稱: $_displayName");
        print("頭像 URL: $_photoUrl");
      });
      print("用戶數據加載完成");
    } catch (e) {
      print("加載用戶數據時出錯: $e");
    }
  }

  // 登出並清除本地存儲的用戶數據
  Future<void> _logout(BuildContext context) async {
    try {
      print("開始登出...");
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // 清除所有保存的數據
      print("已清除所有用戶數據");

      // 導航回登入頁面，並清除導航堆疊
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginPage()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      print("登出時出錯: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('用戶中心', style: TextStyle(color: Colors.black)),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 用戶頭像
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade200,
                image: _photoUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(_photoUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _photoUrl.isEmpty
                  ? Icon(Icons.person, size: 80, color: Colors.grey.shade400)
                  : null,
            ),
            SizedBox(height: 20),
            
            // 用戶名稱
            Text(
              _displayName.isNotEmpty ? _displayName : '未知用戶',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            
            // 用戶身份
            Container(
              padding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _role,
                style: TextStyle(
                  color: Colors.blue.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: 30),
            
            // 用戶信息卡片
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 電子郵件
                  _buildInfoRow(Icons.email, '電子郵件', _email),
                  Divider(),
                  
                  // 用戶 ID
                  _buildInfoRow(Icons.fingerprint, '用戶 ID', _userId),
                  Divider(),
                  
                  // 自我介紹
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '自我介紹',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        _bio,
                        style: TextStyle(
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 40),
            
            // 登出按鈕
            ElevatedButton(
              onPressed: () => _logout(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Text(
                '登出',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 構建信息行的輔助方法
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue.shade700, size: 22),
          SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              SizedBox(height: 5),
              Text(
                value.isNotEmpty ? value : '未設置',
                style: TextStyle(
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}