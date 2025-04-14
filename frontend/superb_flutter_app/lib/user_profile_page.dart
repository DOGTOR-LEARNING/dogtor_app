import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class UserProfilePage extends StatefulWidget {
  @override
  _UserProfilePageState createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  String _userId = '';
  String _email = '';
  String _displayName = '';
  String _photoUrl = '';
  String _yearGrade = ''; // 用戶年級
  String _nickname = ''; // 用戶暱稱
  String _introduction = '這個人很懶，什麼都沒有留下...'; // 自我介紹
  bool _isLoading = true; // 加載狀態
  bool _isEditingIntroduction = false;
  bool _isEditingNickname = false;
  bool _isEditingYearGrade = false;

  final TextEditingController _introductionController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();
  
  // 年級選項
  final List<String> _gradeOptions = ['G1', 'G2', 'G3', 'G4', 'G5', 'G6', 'G7', 'G8', 'G9', 'G10', 'G11', 'G12', 'teacher', 'parent'];
  // 年級顯示名稱
  final Map<String, String> _gradeDisplayNames = {
    'G1': '小一', 'G2': '小二', 'G3': '小三', 'G4': '小四', 'G5': '小五', 'G6': '小六',
    'G7': '國一', 'G8': '國二', 'G9': '國三', 'G10': '高一', 'G11': '高二', 'G12': '高三',
    'teacher': '老師', 'parent': '家長'
  };

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _introductionController.dispose();
    _nicknameController.dispose();
    super.dispose();
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
        _introduction = prefs.getString('introduction') ?? '這個人很懶，什麼都沒有留下...';
        _nickname = prefs.getString('nickname') ?? '';
        _yearGrade = prefs.getString('year_grade') ?? 'G10'; // 預設高一
        
        _introductionController.text = _introduction;
        _nicknameController.text = _nickname;
        
        _isLoading = false;
        
        print("加載的用戶數據：");
        print("用戶 ID: $_userId");
        print("電子郵件: $_email");
        print("顯示名稱: $_displayName");
        print("頭像 URL: $_photoUrl");
        print("自我介紹: $_introduction");
        print("暱稱: $_nickname");
        print("年級: $_yearGrade");
      });
      print("用戶數據加載完成");
    } catch (e) {
      print("加載用戶數據時出錯: $e");
      setState(() {
        _userId = 'TEST-USER-001';
        _email = 'test@example.com';
        _displayName = '測試用戶';
        _photoUrl = '';
        _introduction = '這是一個測試用戶的自我介紹...';
        _nickname = '測試暱稱';
        _yearGrade = 'G10';
        
        _introductionController.text = _introduction;
        _nicknameController.text = _nickname;
        
        _isLoading = false;
      });
    }
  }

  // 保存用戶資料到本地和後端
  Future<void> _saveUserData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      
      // 保存到本地
      await prefs.setString('introduction', _introductionController.text);
      await prefs.setString('nickname', _nicknameController.text);
      await prefs.setString('year_grade', _yearGrade);
      
      // 更新 UI
      setState(() {
        _introduction = _introductionController.text;
        _nickname = _nicknameController.text;
        _isEditingIntroduction = false;
        _isEditingNickname = false;
        _isEditingYearGrade = false;
      });
      
      // 保存到後端
      await _updateUserInBackend();
      
    } catch (e) {
      print("保存用戶數據時出錯: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失敗，請稍後再試')),
      );
    }
  }

  // 更新後端數據
  Future<void> _updateUserInBackend() async {
    try {
      final response = await http.put(
        Uri.parse('https://superb-backend-1041765261654.asia-east1.run.app/users/$_userId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': _userId,
          'email': _email,
          'name': _displayName,
          'photo_url': _photoUrl,
          'nickname': _nickname,
          'year_grade': _yearGrade,
          'introduction': _introduction
        }),
      );
      
      if (response.statusCode != 200) {
        print('更新用戶數據失敗: ${response.statusCode}');
        print('響應內容: ${response.body}');
        throw Exception('更新用戶數據失敗');
      }
      
      print('用戶數據更新成功');
    } catch (e) {
      print('更新用戶數據時出錯: $e');
      throw e;
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

  // 顯示年級選擇對話框
  void _showGradeSelector() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.blue.shade100, Colors.white],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: Text(
                  '選擇年級',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _gradeOptions.length,
                  itemBuilder: (context, index) {
                    final grade = _gradeOptions[index];
                    final displayName = _gradeDisplayNames[grade] ?? grade;
                    final isSelected = _yearGrade == grade;
                    
                    return Container(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blue.shade400 : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isSelected ? [
                          BoxShadow(
                            color: Colors.blue.shade200.withOpacity(0.5),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ] : null,
                      ),
                      child: ListTile(
                        title: Text(
                          displayName,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.blue.shade800,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        selected: isSelected,
                        onTap: () {
                          setState(() {
                            _yearGrade = grade;
                            _isEditingYearGrade = false;
                          });
                          Navigator.pop(context);
                          _saveUserData();
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    print("Building UserProfilePage with data:");
    print("Email: $_email");
    print("Introduction: $_introduction");
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
          : Stack(
              children: [
                SingleChildScrollView(
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
                      
                      // 用戶身份標籤
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _gradeDisplayNames[_yearGrade] ?? _yearGrade,
                              style: TextStyle(
                                color: Colors.blue.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (_nickname.isNotEmpty) SizedBox(width: 8),
                          if (_nickname.isNotEmpty)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _nickname,
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
                            
                            // 年級
                            _buildInfoRow(
                              Icons.school, 
                              '年級', 
                              _gradeDisplayNames[_yearGrade] ?? _yearGrade,
                              isEditable: true,
                              onEdit: () {
                                setState(() {
                                  _isEditingYearGrade = true;
                                });
                                _showGradeSelector();
                              },
                            ),
                            Divider(),
                            
                            // 暱稱
                            _buildInfoRow(
                              Icons.person_pin, 
                              '暱稱', 
                              _nickname.isEmpty ? '尚未設置暱稱' : _nickname,
                              isEditable: true,
                              isEditingState: _isEditingNickname,
                              textController: _nicknameController,
                              onEdit: () {
                                setState(() {
                                  _isEditingNickname = !_isEditingNickname;
                                  if (!_isEditingNickname) {
                                    _saveUserData();
                                  }
                                });
                              },
                            ),
                            Divider(),
                            
                            // 自我介紹
                            _buildInfoRow(
                              Icons.person_outline, 
                              '自我介紹 (50字內)', 
                              _introduction,
                              isEditable: true,
                              isEditingState: _isEditingIntroduction,
                              textController: _introductionController,
                              onEdit: () {
                                setState(() {
                                  _isEditingIntroduction = !_isEditingIntroduction;
                                  if (!_isEditingIntroduction) {
                                    _saveUserData();
                                  }
                                });
                              },
                              maxLength: 50,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 100), // 增加底部高度，避免被保存按鈕遮擋
                      
                      // 登出按鈕
                      Center(
                        child: ElevatedButton(
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
                      ),
                      SizedBox(height: 20),
                    ],
                  ),
                ),
                
                // 懸浮的保存按鈕（當正在編輯時顯示）
                if (_isEditingNickname || _isEditingIntroduction)
                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              spreadRadius: 1,
                              blurRadius: 10,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.save),
                          label: Text('保存更改'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            textStyle: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _isEditingNickname = false;
                              _isEditingIntroduction = false;
                            });
                            _saveUserData();
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  // 構建信息行的輔助方法
  Widget _buildInfoRow(
    IconData icon, 
    String label, 
    String value, 
    {
      bool isEditable = false,
      bool isEditingState = false,
      TextEditingController? textController,
      VoidCallback? onEdit,
      int? maxLength,
    }
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.blue.shade700, size: 18),
            alignment: Alignment.center,
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
                        fontSize: 16,
                        color: Colors.black87,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (isEditable && onEdit != null)
                      Container(
                        decoration: BoxDecoration(
                          color: isEditingState ? Colors.green.shade100 : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.all(8),
                          constraints: BoxConstraints(),
                          icon: Icon(
                            isEditingState ? Icons.check : Icons.edit,
                            size: 20,
                            color: isEditingState ? Colors.green.shade700 : Colors.blue.shade700,
                          ),
                          onPressed: onEdit,
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 8),
                if (isEditable && isEditingState && textController != null)
                  Container(
                    margin: EdgeInsets.only(top: 4),
                    child: TextField(
                      controller: textController,
                      maxLines: maxLength != null ? null : 3,
                      maxLength: maxLength,
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        hintText: label.contains('暱稱') ? '請輸入暱稱' : '請輸入自我介紹（50字內）',
                        hintStyle: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.blue.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                        ),
                      ),
                    ),
                  )
                else
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
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