import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_svg/flutter_svg.dart';

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
  final Color primaryBlue = Color(0xFF1E88E5);
  final Color accentOrange = Color(0xFFFF9800);
  final Color backgroundBlue = Color(0xFFE3F2FD);
  final Color darkBlue = Color(0xFF1565C0);

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
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _friendsList = List<Map<String, dynamic>>.from(data['friends']);
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
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _pendingRequests = List<Map<String, dynamic>>.from(data['requests']);
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? '載入好友請求失敗')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('無法載入好友請求: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加載好友請求時出錯: $e')),
      );
    }
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
      print('發送搜尋請求: $query'); // 調試日誌
      final response = await http.post(
        Uri.parse('https://superb-backend-1041765261654.asia-east1.run.app/search_users'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'query': query,
          'current_user_id': _userId,
        }),
      );

      print('收到回應: ${response.statusCode}'); // 調試日誌
      print('回應內容: ${response.body}'); // 調試日誌

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _searchResults = List<Map<String, dynamic>>.from(data['users']);
            _isSearching = false;
          });
          print('搜尋結果數量: ${_searchResults.length}'); // 調試日誌
        } else {
          setState(() {
            _isSearching = false;
            _searchResults = [];
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? '搜尋用戶失敗')),
          );
        }
      } else {
        setState(() {
          _isSearching = false;
          _searchResults = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('搜尋用戶時發生錯誤: ${response.statusCode}')),
        );
      }
    } catch (e) {
      print('搜尋出錯: $e'); // 調試日誌
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('搜尋用戶時出錯: $e')),
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
            SnackBar(content: Text(data['message'] ?? '好友請求已發送')),
          );
          // 重新載入搜尋結果
          _searchFriends(_searchController.text);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? '無法發送好友請求')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('發送好友請求失敗: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('發送好友請求時出錯: $e')),
      );
    }
  }

  Future<void> _respondToFriendRequest(String requestId, String status) async {
    try {
      final response = await http.post(
        Uri.parse('https://superb-backend-1041765261654.asia-east1.run.app/respond_friend_request'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'request_id': requestId,
          'status': status,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(status == 'accepted' ? '已接受好友請求' : '已拒絕好友請求')),
          );
          // 重新載入好友和請求列表
          _loadFriends();
          _loadPendingRequests();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? '處理好友請求失敗')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('處理好友請求失敗: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('處理好友請求時出錯: $e')),
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
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: darkBlue),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: accentOrange,
          labelColor: darkBlue,
          unselectedLabelColor: Colors.grey,
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
              Colors.white,
              backgroundBlue,
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: CircleAvatar(
              radius: 25,
              backgroundImage: friend['photo_url'] != null && friend['photo_url'].isNotEmpty
                  ? NetworkImage(friend['photo_url'])
                  : null,
              child: friend['photo_url'] == null || friend['photo_url'].isEmpty
                  ? Icon(Icons.person, color: Colors.white, size: 30)
                  : null,
              backgroundColor: primaryBlue,
            ),
            title: Text(
              friend['name'] ?? friend['nickname'] ?? '未知用戶',
              style: TextStyle(
                color: darkBlue,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Text(
              '${friend['year_grade'] ?? ''} ${friend['introduction'] ?? ''}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            trailing: Container(
              decoration: BoxDecoration(
                color: accentOrange,
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: Icon(Icons.message, color: Colors.white),
                onPressed: () {
                  // 實現聊天功能
                },
              ),
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
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: CircleAvatar(
              radius: 25,
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
            subtitle: Text(
              '${request['requester_grade'] ?? ''} ${request['requester_intro'] ?? ''}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.check, color: Colors.white),
                    onPressed: () => _respondToFriendRequest(request['id'], 'accepted'),
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () => _respondToFriendRequest(request['id'], 'rejected'),
                  ),
                ),
              ],
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
                color: Colors.black.withOpacity(0.1),
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
                                ? '輸入電子郵件並按下搜尋'
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
                          margin: EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: ListTile(
                            contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            leading: CircleAvatar(
                              radius: 25,
                              backgroundImage: user['photo_url'] != null && user['photo_url'].isNotEmpty
                                  ? NetworkImage(user['photo_url'])
                                  : null,
                              child: user['photo_url'] == null || user['photo_url'].isEmpty
                                  ? Icon(Icons.person, color: Colors.white, size: 30)
                                  : null,
                              backgroundColor: primaryBlue,
                            ),
                            title: Text(
                              user['name'] ?? user['nickname'] ?? '未知用戶',
                              style: TextStyle(
                                color: darkBlue,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user['email'] ?? '',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                                if (user['year_grade'] != null || user['introduction'] != null)
                                  Text(
                                    '${user['year_grade'] ?? ''} ${user['introduction'] ?? ''}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: isFriend
                                ? Container(
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
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
                                    ? Container(
                                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: accentOrange,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.schedule, color: Colors.white, size: 20),
                                            SizedBox(width: 4),
                                            Text(
                                              '等待回應',
                                              style: TextStyle(color: Colors.white),
                                            ),
                                          ],
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
                        );
                      },
                    ),
        ),
      ],
    );
  }
} 