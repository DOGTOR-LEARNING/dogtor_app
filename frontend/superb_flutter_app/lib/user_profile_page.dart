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
  bool _isLoading = true; // 添加加載狀態
  bool _isEditingBio = false;
  final TextEditingController _bioController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  // 保存自我介紹
  Future<void> _saveBio() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('bio', _bioController.text);
      setState(() {
        _bio = _bioController.text;
        _isEditingBio = false;
      });
    } catch (e) {
      print("保存自我介紹時出錯: $e");
    }
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
        _userId = prefs.getString('user_id') ?? 'USER-0000';
        _email = prefs.getString('email') ?? 'example@email.com';
        _displayName = prefs.getString('display_name') ?? '未知用戶';
        _photoUrl = prefs.getString('photo_url') ?? '';
        _bio = prefs.getString('bio') ?? '這個人很懶，什麼都沒有留下...';
        _bioController.text = _bio;
        _isLoading = false;
        
        print("加載的用戶數據：");
        print("用戶 ID: $_userId");
        print("電子郵件: $_email");
        print("顯示名稱: $_displayName");
        print("頭像 URL: $_photoUrl");
        print("自我介紹: $_bio");
      });
      print("用戶數據加載完成");
    } catch (e) {
      print("加載用戶數據時出錯: $e");
      setState(() {
        _userId = 'TEST-USER-001';
        _email = 'test@example.com';
        _displayName = '測試用戶';
        _photoUrl = '';
        _bio = '這是一個測試用戶的自我介紹...';
        _bioController.text = _bio;
        _isLoading = false;
      });
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
    print("Building UserProfilePage with data:");
    print("Email: $_email");
    print("Bio: $_bio");
    print("User ID: $_userId");
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '用戶中心',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 10),
                  
                  // 用戶身份
                  Row(
                    children: [
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
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '高中生',
                          style: TextStyle(
                            color: Colors.blue.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '文組',
                          style: TextStyle(
                            color: Colors.blue.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
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
                        _buildInfoRow(Icons.person_outline, '自我介紹', _bio, isEditable: true),
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
  Widget _buildInfoRow(IconData icon, String label, String value, {bool isEditable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            padding: icon == Icons.person_outline ? EdgeInsets.only(top: 13) : null,
            child: Icon(icon, color: Colors.blue.shade700, size: 22),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (isEditable)
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                        icon: Icon(
                          _isEditingBio ? Icons.save : Icons.edit,
                          size: 20,
                          color: Colors.blue.shade700,
                        ),
                        onPressed: () {
                          if (_isEditingBio) {
                            _saveBio();
                          } else {
                            setState(() {
                              _isEditingBio = true;
                            });
                          }
                        },
                      ),
                  ],
                ),
                SizedBox(height: 4),
                if (isEditable && _isEditingBio)
                  Container(
                    margin: EdgeInsets.only(top: 4),
                    child: TextField(
                      controller: _bioController,
                      maxLines: 3,
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: '請輸入自我介紹',
                        hintStyle: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  )
                else
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}