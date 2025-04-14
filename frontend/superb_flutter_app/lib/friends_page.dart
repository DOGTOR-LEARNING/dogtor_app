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
        Uri.parse('http://your-backend-url.com/get_friends/$_userId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _friendsList = List<Map<String, dynamic>>.from(data['friends']);
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        // 處理錯誤
        print('無法載入好友列表: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('加載好友列表時出錯: $e');
    }
  }

  Future<void> _loadPendingRequests() async {
    if (_userId == null) return;

    try {
      final response = await http.get(
        Uri.parse('http://your-backend-url.com/get_friend_requests/$_userId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _pendingRequests = List<Map<String, dynamic>>.from(data['requests']);
        });
      } else {
        // 處理錯誤
        print('無法載入好友請求: ${response.statusCode}');
      }
    } catch (e) {
      print('加載好友請求時出錯: $e');
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
      final response = await http.post(
        Uri.parse('http://your-backend-url.com/search_users'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'query': query,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _searchResults = List<Map<String, dynamic>>.from(data['users']);
          _isSearching = false;
        });
      } else {
        setState(() {
          _isSearching = false;
        });
        // 處理錯誤
        print('搜尋用戶時發生錯誤: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      print('搜尋用戶時出錯: $e');
    }
  }

  Future<void> _sendFriendRequest(String friendId) async {
    if (_userId == null) return;

    try {
      final response = await http.post(
        Uri.parse('http://your-backend-url.com/send_friend_request'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'requester_id': _userId,
          'addressee_id': friendId,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('好友請求已發送')),
        );
        // 重新載入搜尋結果
        _searchFriends(_searchController.text);
      } else {
        // 處理錯誤
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('無法發送好友請求')),
        );
      }
    } catch (e) {
      print('發送好友請求時出錯: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('發送好友請求失敗: $e')),
      );
    }
  }

  Future<void> _respondToFriendRequest(String requestId, String status) async {
    try {
      final response = await http.post(
        Uri.parse('http://your-backend-url.com/respond_friend_request'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'request_id': requestId,
          'status': status,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(status == 'accepted' ? '已接受好友請求' : '已拒絕好友請求')),
        );
        // 重新載入好友和請求列表
        _loadFriends();
        _loadPendingRequests();
      } else {
        // 處理錯誤
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('處理好友請求時發生錯誤')),
        );
      }
    } catch (e) {
      print('處理好友請求時出錯: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('處理好友請求失敗: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('好友'),
        backgroundColor: Color(0xFF101F30),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: '好友列表'),
            Tab(text: '好友請求'),
            Tab(text: '查詢好友'),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/home-background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            // 好友列表頁面
            _buildFriendsListTab(),
            
            // 好友請求頁面
            _buildFriendRequestsTab(),
            
            // 查詢好友頁面
            _buildSearchFriendsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsListTab() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    
    if (_friendsList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/images/dogtor_eng_logo.svg',
              width: 100,
              height: 100,
              color: Colors.white.withOpacity(0.5),
            ),
            SizedBox(height: 20),
            Text(
              '還沒有好友',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            SizedBox(height: 10),
            Text(
              '在「查詢好友」頁面尋找新朋友',
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
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
          color: Colors.white.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: friend['photo_url'] != null && friend['photo_url'].isNotEmpty
                  ? NetworkImage(friend['photo_url'])
                  : null,
              child: friend['photo_url'] == null || friend['photo_url'].isEmpty
                  ? Icon(Icons.person, color: Colors.white)
                  : null,
              backgroundColor: Colors.blue.shade700,
            ),
            title: Text(
              friend['name'] ?? friend['nickname'] ?? '未知用戶',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              '${friend['year_grade'] ?? ''} ${friend['introduction'] ?? ''}',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
            trailing: IconButton(
              icon: Icon(Icons.message, color: Colors.white),
              onPressed: () {
                // 實現聊天功能
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
            SvgPicture.asset(
              'assets/images/dogtor_eng_logo.svg',
              width: 100,
              height: 100,
              color: Colors.white.withOpacity(0.5),
            ),
            SizedBox(height: 20),
            Text(
              '沒有待處理的好友請求',
              style: TextStyle(color: Colors.white, fontSize: 18),
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
          color: Colors.white.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: request['requester_photo'] != null && request['requester_photo'].isNotEmpty
                  ? NetworkImage(request['requester_photo'])
                  : null,
              child: request['requester_photo'] == null || request['requester_photo'].isEmpty
                  ? Icon(Icons.person, color: Colors.white)
                  : null,
              backgroundColor: Colors.blue.shade700,
            ),
            title: Text(
              request['requester_name'] ?? '未知用戶',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              '${request['requester_grade'] ?? ''} ${request['requester_intro'] ?? ''}',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.check, color: Colors.green),
                  onPressed: () => _respondToFriendRequest(request['id'], 'accepted'),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.red),
                  onPressed: () => _respondToFriendRequest(request['id'], 'rejected'),
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
        Padding(
          padding: EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '搜尋用戶名稱或暱稱',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              prefixIcon: Icon(Icons.search, color: Colors.white),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.white),
                      onPressed: () {
                        _searchController.clear();
                        _searchFriends('');
                      },
                    )
                  : null,
            ),
            onChanged: _searchFriends,
          ),
        ),
        Expanded(
          child: _isSearching
              ? Center(child: CircularProgressIndicator())
              : _searchResults.isEmpty
                  ? Center(
                      child: Text(
                        _searchController.text.isEmpty
                            ? '輸入名稱或暱稱搜尋好友'
                            : '沒有找到符合的用戶',
                        style: TextStyle(color: Colors.white),
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
                          color: Colors.white.withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          margin: EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundImage: user['photo_url'] != null && user['photo_url'].isNotEmpty
                                  ? NetworkImage(user['photo_url'])
                                  : null,
                              child: user['photo_url'] == null || user['photo_url'].isEmpty
                                  ? Icon(Icons.person, color: Colors.white)
                                  : null,
                              backgroundColor: Colors.blue.shade700,
                            ),
                            title: Text(
                              user['name'] ?? user['nickname'] ?? '未知用戶',
                              style: TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              '${user['year_grade'] ?? ''} ${user['introduction'] ?? ''}',
                              style: TextStyle(color: Colors.white.withOpacity(0.7)),
                            ),
                            trailing: isFriend
                                ? Icon(Icons.check_circle, color: Colors.green)
                                : requestSent
                                    ? Text('已發送請求', style: TextStyle(color: Colors.yellow))
                                    : IconButton(
                                        icon: Icon(Icons.person_add, color: Colors.white),
                                        onPressed: () => _sendFriendRequest(user['user_id']),
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