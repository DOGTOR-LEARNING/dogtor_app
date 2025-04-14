import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_svg/flutter_svg.dart';
import 'friend_profile_page.dart';

class FriendsPage extends StatefulWidget {
  @override
  _FriendsPageState createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> with SingleTickerProviderStateMixin {
  TabController? _tabController;
  String? _userId;
  List<Map<String, dynamic>> _friendsList = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _isLoading = true;

  // 定義主題顏色
  final Color primaryBlue = Color(0xFF319cb6);  // 新的主藍色
  final Color accentOrange = Color(0xFFf59b03);  // 新的強調橙色
  final Color backgroundWhite = Color(0xFFFFF9F7);  // 新的背景白色
  final Color darkBlue = Color(0xFF0777B1);  // 新的深藍色

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserId().then((_) {
      _loadFriends();
      _loadPendingRequests();
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString('user_id');
    });
  }

  Future<void> _loadFriends() async {
    if (_userId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('https://superb-backend-1041765261654.asia-east1.run.app/get_friends/$_userId'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json; charset=utf-8',
        },
      );

      if (response.statusCode == 200) {
        // 確保使用 UTF-8 解碼
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['status'] == 'success') {
          setState(() {
            _friendsList = List<Map<String, dynamic>>.from(data['friends']);
            // 處理年級顯示格式
            for (var friend in _friendsList) {
              if (friend['year_grade'] != null && friend['year_grade'].toString().startsWith('G')) {
                final gradeNum = friend['year_grade'].toString().substring(1);
                friend['year_grade'] = '$gradeNum年級';
              }
            }
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? '載入好友列表失敗')),
          );
        }
      } else {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('無法載入好友列表: ${response.statusCode}')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加載好友列表時出錯: $e')),
      );
    }
  }

  Future<void> _loadPendingRequests() async {
    if (_userId == null) return;

    try {
      final response = await http.get(
        Uri.parse('https://superb-backend-1041765261654.asia-east1.run.app/get_friend_requests/$_userId'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json; charset=utf-8',
        },
      );

      print('載入好友請求響應狀態碼: ${response.statusCode}');
      print('載入好友請求響應內容: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['status'] == 'success') {
          setState(() {
            _pendingRequests = List<Map<String, dynamic>>.from(data['requests'] ?? []);
            
            // 確保每個請求都有id屬性
            for (var i = 0; i < _pendingRequests.length; i++) {
              var request = _pendingRequests[i];
              // 確保id欄位存在且為字符串格式
              if (request['id'] == null) {
                print('警告: 請求 #$i 沒有id欄位, 嘗試使用request_id');
                if (request['request_id'] != null) {
                  request['id'] = request['request_id'].toString();
                } else {
                  print('錯誤: 請求 #$i 既沒有id欄位也沒有request_id欄位');
                }
              } else if (request['id'] is! String) {
                request['id'] = request['id'].toString();
              }
              
              print('處理後的請求 #$i: ${request['id']}, ${request['requester_name']}');
            }
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? '載入好友請求失敗'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('無法載入好友請求: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('加載好友請求時出錯: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('加載好友請求時出錯: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 新增一個輔助函數來處理API返回的ID格式問題
  String _getRequestId(Map<String, dynamic> request) {
    // 檢查是否有id字段
    if (request.containsKey('id') && request['id'] != null) {
      return request['id'].toString();
    }
    
    // 檢查是否有request_id字段
    if (request.containsKey('request_id') && request['request_id'] != null) {
      return request['request_id'].toString();
    }
    
    // 都沒有，返回空字符串
    print('警告: 無法找到請求ID: $request');
    return '';
  }

  Future<void> _searchFriends(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final response = await http.post(
        Uri.parse('https://superb-backend-1041765261654.asia-east1.run.app/search_users'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json; charset=utf-8',
        },
        body: json.encode({
          'query': query,
          'current_user_id': _userId,
        }),
      );

      if (response.statusCode == 200) {
        // 確保使用 UTF-8 解碼
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['status'] == 'success') {
          setState(() {
            _searchResults = List<Map<String, dynamic>>.from(data['users']);
            // 打印搜索結果以進行調試
            for (var user in _searchResults) {
              print('用戶 ID: ${user['user_id']}, 姓名: ${user['name']}, 好友狀態: ${user['friend_status']}');
              if (user['friend_status'] == 'pending') {
                print('請求 ID: ${user['request_id']}');
              }
            }
            _isSearching = false;
          });
        } else {
          setState(() {
            _isSearching = false;
            _searchResults = [];
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? '搜尋用戶失敗'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        setState(() {
          _isSearching = false;
          _searchResults = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('搜尋用戶時發生錯誤: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('搜尋用戶時出錯: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendFriendRequest(String friendId) async {
    if (_userId == null) return;

    try {
      final response = await http.post(
        Uri.parse('https://superb-backend-1041765261654.asia-east1.run.app/send_friend_request'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'requester_id': _userId,
          'addressee_id': friendId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? '好友請求已發送'),
              backgroundColor: primaryBlue,
            ),
          );
          // 重新載入搜尋結果
          _searchFriends(_searchController.text);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? '無法發送好友請求'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('發送好友請求失敗: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('發送好友請求時出錯: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 添加收回好友請求的功能
  Future<void> _cancelFriendRequest(String requestId, String userId) async {
    if (_userId == null) {
      print('無法收回請求：用戶ID為空');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('無法收回請求：用戶資訊不完整'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    print('正在嘗試收回請求，請求ID: $requestId, 用戶ID: $userId');

    try {
      // 首先嘗試使用請求ID
      if (requestId != null && requestId.isNotEmpty) {
        final response = await http.post(
          Uri.parse('https://superb-backend-1041765261654.asia-east1.run.app/respond_friend_request'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'request_id': requestId,
            'status': 'canceled',
          }),
        );

        print('收回請求響應狀態碼: ${response.statusCode}');
        print('收回請求響應內容: ${response.body}');

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == 'success') {
            _showSuccessMessage();
            return;
          }
        }
      }
      
      // 如果請求ID方法失敗，嘗試使用用戶ID
      final cancelByUserResponse = await http.post(
        Uri.parse('https://superb-backend-1041765261654.asia-east1.run.app/cancel_friend_request'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'requester_id': _userId,
          'addressee_id': userId,
        }),
      );
      
      print('通過用戶ID取消的響應: ${cancelByUserResponse.statusCode}');
      print('通過用戶ID取消的內容: ${cancelByUserResponse.body}');
      
      if (cancelByUserResponse.statusCode == 200) {
        final data = json.decode(cancelByUserResponse.body);
        if (data['status'] == 'success') {
          _showSuccessMessage();
          return;
        }
      }
      
      // 如果兩種方法都失敗
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('無法收回好友請求，請稍後再試'),
          backgroundColor: Colors.red,
        ),
      );
      
    } catch (e) {
      print('收回好友請求時出錯: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('收回好友請求時出錯，請稍後再試'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  void _showSuccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已收回好友請求'),
        backgroundColor: primaryBlue,
      ),
    );
    // 重新載入搜尋結果
    _searchFriends(_searchController.text);
  }

  Future<void> _respondToFriendRequest(String requestId, String status) async {
    print('處理好友請求，請求ID: $requestId, 狀態: $status');
    
    if (requestId == null || requestId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('無效的請求ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://superb-backend-1041765261654.asia-east1.run.app/respond_friend_request'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'request_id': requestId,
          'status': status,
        }),
      );

      print('回應好友請求響應狀態碼: ${response.statusCode}');
      print('回應好友請求響應內容: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(status == 'accepted' ? '已接受好友請求' : '已拒絕好友請求'),
              backgroundColor: status == 'accepted' ? Colors.green : Colors.orange,
            ),
          );
          // 重新載入好友和請求列表
          _loadFriends();
          _loadPendingRequests();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? '處理好友請求失敗'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('處理好友請求失敗: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('處理好友請求時出錯: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('處理好友請求時出錯: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '好友',
          style: TextStyle(
            color: darkBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: backgroundWhite,
        elevation: 0,
        iconTheme: IconThemeData(color: darkBlue),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: accentOrange,
          labelColor: darkBlue,
          unselectedLabelColor: Colors.grey.shade600,
          tabs: [
            Tab(text: '好友列表'),
            Tab(text: '好友請求'),
            Tab(text: '查詢好友'),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              backgroundWhite,
              Color(0xFFE8F6F8), // 淡藍色漸變效果
            ],
          ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildFriendsListTab(),
            _buildFriendRequestsTab(),
            _buildSearchFriendsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsListTab() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
      ));
    }
    
    if (_friendsList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 120,
              color: primaryBlue.withOpacity(0.5),
            ),
            SizedBox(height: 24),
            Text(
              '還沒有好友',
              style: TextStyle(
                color: darkBlue,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              '在「查詢好友」頁面尋找新朋友',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _friendsList.length,
      itemBuilder: (context, index) {
        final friend = _friendsList[index];
        return Card(
          elevation: 2,
          margin: EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          color: Colors.white,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  backgroundWhite,
                  Color(0xFFECF6F9), // 淡藍色漸變效果
                ],
              ),
            ),
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              leading: CircleAvatar(
                radius: 28,
                backgroundImage: friend['photo_url'] != null && friend['photo_url'].isNotEmpty
                    ? NetworkImage(friend['photo_url'])
                    : null,
                child: friend['photo_url'] == null || friend['photo_url'].isEmpty
                    ? Text(
                        (friend['name'] ?? friend['nickname'] ?? '?')[0].toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
                backgroundColor: primaryBlue,
              ),
              title: Text(
                '${friend['nickname'] ?? ''}${friend['nickname'] != null && friend['name'] != null ? ' (' : ''}${friend['name'] ?? ''}${friend['nickname'] != null && friend['name'] != null ? ')' : ''}',
                style: TextStyle(
                  color: darkBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 4),
                  Text(
                    friend['email'] ?? '',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  if (friend['year_grade'] != null || friend['introduction'] != null)
                    Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        '${friend['year_grade'] ?? ''} ${friend['introduction'] ?? ''}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FriendProfilePage(friend: friend),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildFriendRequestsTab() {
    if (_pendingRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_add_disabled,
              size: 120,
              color: primaryBlue.withOpacity(0.5),
            ),
            SizedBox(height: 24),
            Text(
              '沒有待處理的好友請求',
              style: TextStyle(
                color: darkBlue,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _pendingRequests.length,
      itemBuilder: (context, index) {
        final request = _pendingRequests[index];
        // 使用輔助函數獲取請求ID
        final requestId = _getRequestId(request);
        print('請求#$index - ID: $requestId, 請求者: ${request['requester_name']}');
        
        return Card(
          elevation: 2,
          margin: EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  backgroundWhite,
                  Color(0xFFECF6F9), // 淡藍色漸變效果
                ],
              ),
            ),
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              leading: CircleAvatar(
                radius: 28,
                backgroundImage: request['requester_photo'] != null && request['requester_photo'].isNotEmpty
                    ? NetworkImage(request['requester_photo'])
                    : null,
                child: request['requester_photo'] == null || request['requester_photo'].isEmpty
                    ? Icon(Icons.person, color: Colors.white, size: 30)
                    : null,
                backgroundColor: primaryBlue,
              ),
              title: Text(
                request['requester_name'] ?? '未知用戶',
                style: TextStyle(
                  color: darkBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  '${request['requester_grade'] ?? ''} ${request['requester_intro'] ?? ''}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: primaryBlue,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.check, color: Colors.white),
                      onPressed: () {
                        print('接受按鈕點擊 - 請求ID: $requestId');
                        if (requestId.isNotEmpty) {
                          _respondToFriendRequest(requestId, 'accepted');
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('無效的請求ID'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      tooltip: '接受',
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: accentOrange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        print('拒絕按鈕點擊 - 請求ID: $requestId');
                        if (requestId.isNotEmpty) {
                          _respondToFriendRequest(requestId, 'rejected');
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('無效的請求ID'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      tooltip: '拒絕',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchFriendsTab() {
    return Column(
      children: [
        Container(
          margin: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: darkBlue),
                  decoration: InputDecoration(
                    hintText: '搜尋用戶電子郵件',
                    hintStyle: TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: Icon(Icons.search, color: primaryBlue),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: primaryBlue),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchResults = [];
                                _isSearching = false;
                              });
                            },
                          )
                        : null,
                  ),
                  onSubmitted: (value) {
                    if (value.isNotEmpty) {
                      _searchFriends(value);
                    }
                  },
                ),
              ),
              Container(
                margin: EdgeInsets.only(right: 8),
                child: IconButton(
                  icon: Icon(Icons.search, color: Colors.white),
                  onPressed: () {
                    if (_searchController.text.isNotEmpty) {
                      _searchFriends(_searchController.text);
                    }
                  },
                  style: IconButton.styleFrom(
                    backgroundColor: primaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isSearching
              ? Center(child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
                ))
              : _searchResults.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchController.text.isEmpty
                                ? Icons.person_search
                                : Icons.person_off,
                            size: 120,
                            color: primaryBlue.withOpacity(0.5),
                          ),
                          SizedBox(height: 24),
                          Text(
                            _searchController.text.isEmpty
                                ? '輸入完整電子郵件帳號搜尋'
                                : '沒有找到符合的用戶',
                            style: TextStyle(
                              color: darkBlue,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final user = _searchResults[index];
                        final bool isFriend = _friendsList.any((friend) => friend['user_id'] == user['user_id']);
                        final bool requestSent = user['friend_status'] == 'pending';
                        
                        return Card(
                          elevation: 2,
                          margin: EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          color: Colors.white,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  backgroundWhite,
                                  Color(0xFFECF6F9), // 淡藍色漸變效果
                                ],
                              ),
                            ),
                            child: ListTile(
                              contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              leading: CircleAvatar(
                                radius: 28,
                                backgroundImage: user['photo_url'] != null && user['photo_url'].isNotEmpty
                                    ? NetworkImage(user['photo_url'])
                                    : null,
                                child: user['photo_url'] == null || user['photo_url'].isEmpty
                                    ? Text(
                                        (user['name'] ?? user['nickname'] ?? '?')[0].toUpperCase(),
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                                backgroundColor: primaryBlue,
                              ),
                              title: Text(
                                '${user['nickname'] ?? ''}${user['nickname'] != null && user['name'] != null ? ' (' : ''}${user['name'] ?? ''}${user['nickname'] != null && user['name'] != null ? ')' : ''}',
                                style: TextStyle(
                                  color: darkBlue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (user['year_grade'] != null || user['introduction'] != null)
                                    Padding(
                                      padding: EdgeInsets.only(top: 4),
                                      child: Text(
                                        '${user['year_grade'] ?? ''} ${user['introduction'] ?? ''}',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: isFriend
                                  ? Container(
                                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: primaryBlue,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.check_circle, color: Colors.white, size: 20),
                                          SizedBox(width: 4),
                                          Text(
                                            '已是好友',
                                            style: TextStyle(color: Colors.white),
                                          ),
                                        ],
                                      ),
                                    )
                                  : requestSent
                                      ? user['is_requester'] == false
                                          ? Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  decoration: BoxDecoration(
                                                    color: primaryBlue,
                                                    borderRadius: BorderRadius.circular(20),
                                                  ),
                                                  child: IconButton(
                                                    icon: Icon(Icons.check, color: Colors.white),
                                                    onPressed: () {
                                                      final requestId = _getRequestId(user);
                                                      print('接受好友申請按鈕點擊 - ID: $requestId');
                                                      if (requestId.isNotEmpty) {
                                                        _respondToFriendRequest(requestId, 'accepted');
                                                      } else {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(
                                                            content: Text('無效的請求ID'),
                                                            backgroundColor: Colors.red,
                                                          ),
                                                        );
                                                      }
                                                    },
                                                    tooltip: '接受',
                                                  ),
                                                ),
                                                SizedBox(width: 8),
                                                Container(
                                                  decoration: BoxDecoration(
                                                    color: accentOrange,
                                                    borderRadius: BorderRadius.circular(20),
                                                  ),
                                                  child: IconButton(
                                                    icon: Icon(Icons.close, color: Colors.white),
                                                    onPressed: () {
                                                      final requestId = _getRequestId(user);
                                                      print('拒絕好友申請按鈕點擊 - ID: $requestId');
                                                      if (requestId.isNotEmpty) {
                                                        _respondToFriendRequest(requestId, 'rejected');
                                                      } else {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(
                                                            content: Text('無效的請求ID'),
                                                            backgroundColor: Colors.red,
                                                          ),
                                                        );
                                                      }
                                                    },
                                                    tooltip: '拒絕',
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Container(
                                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: accentOrange,
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: InkWell(
                                            onTap: () {
                                              // 使用輔助函數獲取請求ID
                                              final requestId = _getRequestId(user);
                                              print('收回好友請求點擊 - 請求ID: $requestId, 用戶ID: ${user['user_id']}');
                                              
                                              // 檢查請求ID是否存在
                                              if (requestId.isEmpty && (user['user_id'] == null || user['user_id'].isEmpty)) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('無法收回請求：請求ID和用戶ID均不存在'),
                                                    backgroundColor: Colors.red,
                                                  ),
                                                );
                                                return;
                                              }
                                              
                                              // 顯示確認對話框
                                              showDialog(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  backgroundColor: backgroundWhite,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(15.0),
                                                  ),
                                                  title: Text(
                                                    '收回好友請求',
                                                    style: TextStyle(
                                                      color: darkBlue,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  content: Text(
                                                    '確定要收回發送給${user['name'] ?? '此用戶'}的好友請求嗎？',
                                                    style: TextStyle(
                                                      color: darkBlue.withOpacity(0.8),
                                                    ),
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(context),
                                                      child: Text(
                                                        '取消',
                                                        style: TextStyle(
                                                          color: Colors.grey.shade600,
                                                        ),
                                                      ),
                                                    ),
                                                    TextButton(
                                                      onPressed: () {
                                                        Navigator.pop(context);
                                                        // 收回好友請求
                                                        _cancelFriendRequest(requestId, user['user_id']);
                                                      },
                                                      child: Text(
                                                        '確定',
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                      style: TextButton.styleFrom(
                                                        foregroundColor: accentOrange,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                            borderRadius: BorderRadius.circular(20),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.schedule, color: Colors.white, size: 20),
                                                SizedBox(width: 4),
                                                Text(
                                                  '已發送',
                                                  style: TextStyle(color: Colors.white),
                                                ),
                                                SizedBox(width: 2),
                                                Icon(Icons.cancel_outlined, color: Colors.white, size: 18),
                                              ],
                                            ),
                                          ),
                                        )
                                      : Container(
                                          decoration: BoxDecoration(
                                            color: primaryBlue,
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: IconButton(
                                            icon: Icon(Icons.person_add, color: Colors.white),
                                            onPressed: () => _sendFriendRequest(user['user_id']),
                                          ),
                                        ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
} 