import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';  // 添加這行來引入 ImageFilter
import 'main.dart';  // 引入原來的 AI 問問題頁面
import 'auth_page.dart';  // Import the AuthPage
import 'mistake_book.dart';  // Import the MistakeBookPage
import 'dart:math';
// import 'chapter_detail_page.dart';  // 默認深藍色
import 'chapter_detail_page_n.dart';  // 藍橘配色
import 'chat_page_s.dart';
import 'user_profile_page.dart';  // 引入新的用戶中心頁面
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/rendering.dart';
import 'user_stats_page.dart';  // Import the UserStatsPage
import 'friends_page.dart';  // 引入新的好友頁面

import 'package:http/http.dart' as http;
import 'dart:convert';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int _selectedIndex = 1;
  int _userHearts = 0;
  ScrollController _scrollController = ScrollController();
  final double _maxPlanetSize = 200.0;  // 增加最大尺寸
  final double _minPlanetSize = 100.0;  // 增加最小尺寸
  double _screenHeight = 600.0;  // 初始值
  String? _userPhotoUrl;  // 添加用戶頭像 URL 狀態變量
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserPhoto();  // 在初始化時加載用戶頭像
    _loadUserHeart();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
 
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadUserPhoto(); // 當應用程序從後台恢復時重新加載頭像
    }
  }

  // 加載用戶頭像
  Future<void> _loadUserPhoto() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _userPhotoUrl = prefs.getString('photo_url');
      print("頭像 URL: $_userPhotoUrl");
    });
  }

  // 加載剩餘體力
  Future<bool> _loadUserHeart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      if (userId == null) return false;

      final response = await http.post(
        Uri.parse('https://superb-backend-1041765261654.asia-east1.run.app/check_heart'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
            setState(() {
            _userHearts = data['hearts'];  // Update the heart value
          });
          return data['hearts'] > 0;
        }
      }
    } catch (e) {
      print("檢查體力失敗: $e");
    }

    return false;
  }

  // 計算星球大小的方法
  double calculatePlanetSize(double scrollPosition, double itemPosition) {
    // 調整中心點位置（向上偏移 20%）
    double adjustedScrollPosition = scrollPosition - (_screenHeight * 0.13);
    
    // 計算與中心線的距離（0-1範圍）
    double distanceFromCenter = (adjustedScrollPosition - itemPosition).abs() / (_screenHeight / 2);
    // 限制距離範圍在 0-1 之間
    distanceFromCenter = distanceFromCenter.clamp(0.0, 1.0);
    // 使用餘弦函數創建平滑的大小變化
    double sizeFactor = (cos(distanceFromCenter * pi) + 1) / 2;
    // 在最小和最大大小之間插值
    return _minPlanetSize + (_maxPlanetSize - _minPlanetSize) * sizeFactor;
  }

  // 計算文字大小的方法
  double calculateTextSize(double size) {
    // 根據圖片大小計算對應的文字大小
    double maxTextSize = 28.0;
    double minTextSize = 18.0;
    double ratio = (size - _minPlanetSize) / (_maxPlanetSize - _minPlanetSize);
    return minTextSize + (maxTextSize - minTextSize) * ratio;
  }

void _onItemTapped(int index) {
  if (index == 0) {  // If "錯題本" (Wrongbook) is tapped
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => MistakeBookPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(-1.0, 0.0); // Start from the left
          const end = Offset.zero; // End at the normal position
          const curve = Curves.easeInOut;

          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
      ),
    );
  } else if (index == 1) {  // If (Stat) is tapped
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const UserStatsPage()),
    );
  }
  else if (index == 2) {  // If "汪汪題" (Chat) is tapped
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChatPage()),
    );
  } else {
    setState(() {
      _selectedIndex = index;  // Only update state for "學習" (Learning)
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: Stack(
        children: [
          // 背景圖片 - 添加視差效果
          AnimatedBuilder(
            animation: _scrollController,
            builder: (context, child) {
              // 計算背景偏移，使其滾動速度比前景慢
              double offset = _scrollController.hasClients ? _scrollController.offset * 0.3 : 0.0;
              return Transform.translate(
                offset: Offset(0, offset),
                child: child,
              );
            },
            child: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/home-background.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          // 主要內容
          IndexedStack(
            index: _selectedIndex,
            children: [
              MistakeBookPage(),
              Container(
                child: Column(
                  children: [
                    SizedBox(height: 50),
                    // Dogtor 標題和用戶頭像在同一列
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SvgPicture.asset(
                            'assets/images/dogtor_eng_logo.svg',
                            width: 120,
                            height: 24,
                            color: Color.fromRGBO(
                              (0.06 * 255).round(),
                              (0.13 * 255).round(),
                              (0.19 * 255).round(),
                              1,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder: (context, animation, secondaryAnimation) => UserProfilePage(),
                                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                        const begin = Offset(1.0, 0.0);
                                        const end = Offset.zero;
                                        const curve = Curves.easeInOut;
                                        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                                        var offsetAnimation = animation.drive(tween);
                                        return SlideTransition(
                                          position: offsetAnimation,
                                          child: child,
                                        );
                                      },
                                    ),
                                  ).then((_) {
                                    _loadUserPhoto();
                                  });
                                },
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        spreadRadius: 1,
                                        blurRadius: 3,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                    image: _userPhotoUrl != null && _userPhotoUrl!.isNotEmpty
                                        ? DecorationImage(
                                            image: NetworkImage(_userPhotoUrl!),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: _userPhotoUrl == null || _userPhotoUrl!.isEmpty
                                      ? Icon(
                                          Icons.person,
                                          color: Colors.blue.shade700,
                                          size: 24,
                                        )
                                      : null,
                                ),
                              ),
                              // 添加好友按鈕
                              SizedBox(height: 8),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder: (context, animation, secondaryAnimation) => FriendsPage(),
                                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                        const begin = Offset(1.0, 0.0);
                                        const end = Offset.zero;
                                        const curve = Curves.easeInOut;
                                        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                                        var offsetAnimation = animation.drive(tween);
                                        return SlideTransition(
                                          position: offsetAnimation,
                                          child: child,
                                        );
                                      },
                                    ),
                                  );
                                },
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        spreadRadius: 1,
                                        blurRadius: 3,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.people,
                                    color: Colors.blue.shade700,
                                    size: 24,
                                  ),
                                ),
                              ),
                              // 新增心形按鈕
                              SizedBox(height: 8),
                              GestureDetector(
                                onTap: () {
                                  // Define what happens when the heart button is pressed
                                  print("Heart button pressed");
                                  // You can navigate to another page or perform any action here
                                },
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        spreadRadius: 1,
                                        blurRadius: 3,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.favorite,  // Use the heart icon
                                    color: Colors.red,  // Set the color for the heart icon
                                    size: 24,
                                  ),
                                ),
                              ),
                              // 剩餘愛心數量顯示
                              SizedBox(width: 8), // Space between the heart icon and the number
                              Text(
                                '$_userHearts', // Display the heart value
                                style: TextStyle(
                                  fontSize: 20, // Adjust the font size as needed
                                  color: Colors.black, // Set the text color
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                    // 學科列表
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          _screenHeight = constraints.maxHeight;
                          return ListView.builder(
                            controller: _scrollController,
                            physics: SnappingScrollPhysics(itemExtent: 180), // 使用自定義的吸附式滾動
                            itemCount: planets.length,
                            itemBuilder: (context, index) {
                              return AnimatedBuilder(
                                animation: _scrollController,
                                builder: (context, child) {
                                  double itemPosition = index * 180.0;
                                  double scrollPosition = _scrollController.hasClients 
                                      ? _scrollController.offset 
                                      : 0.0;
                                  double viewportCenter = constraints.maxHeight * 0.4;
                                  double size = calculatePlanetSize(
                                    scrollPosition + viewportCenter,
                                    itemPosition
                                  );
                                  
                                  bool isLeft = index.isEven;
                                  
                                  return Container(
                                    height: 180,
                                    padding: EdgeInsets.symmetric(horizontal: 40),
                                    child: Row(
                                      mainAxisAlignment: isLeft 
                                          ? MainAxisAlignment.start 
                                          : MainAxisAlignment.end,
                                      children: [
                                        if (!isLeft) Expanded(
                                          child: Padding(
                                            padding: EdgeInsets.only(right: 40),
                                            child: AnimatedDefaultTextStyle(
                                              duration: Duration(milliseconds: 100),
                                              style: Theme.of(context).textTheme.displayMedium!.copyWith(
                                                fontSize: calculateTextSize(size),
                                                color: Colors.white,
                                              ),
                                              child: Text(
                                                planets[index]['name'],
                                                textAlign: TextAlign.end,
                                              ),
                                            ),
                                          ),
                                        ),
                                        AnimatedContainer(
                                          duration: Duration(milliseconds: 100),
                                          width: size,
                                          height: size,
                                          child: GestureDetector(
                                            onTap: () {
                                              print('點擊了 ${planets[index]['name']}');
                                              if (planets[index]['name'] == '理化') {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => ChapterDetailPage(
                                                      subject: '理化',
                                                      csvPath: 'assets/edu_data/level_info/junior_science_level.csv',
                                                    ),
                                                  ),
                                                );
                                              }
                                              else if (planets[index]['name'] == '化學') {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => ChapterDetailPage(
                                                      subject: '化學',
                                                      csvPath: 'assets/edu_data/level_info/high_chemistry_level.csv',
                                                    ),
                                                  ),
                                                );
                                              }
                                              else if (planets[index]['name'] == '歷史') {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => ChapterDetailPage(
                                                      subject: '歷史',
                                                      csvPath: 'assets/edu_data/level_info/junior_his_level.csv',
                                                    ),
                                                  ),
                                                );
                                              }
                                              else if (planets[index]['name'] == '地理') {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => ChapterDetailPage(
                                                      subject: '地理',
                                                      csvPath: 'assets/edu_data/level_info/junior_geo_level.csv',
                                                    ),
                                                  ),
                                                );
                                              }
                                              else if (planets[index]['name'] == '公民') {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => ChapterDetailPage(
                                                      subject: '公民',
                                                      csvPath: 'assets/edu_data/level_info/junior_civ_level.csv',
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                            child: Image.asset(
                                              planets[index]['image'],
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ),
                                        if (isLeft) Expanded(
                                          child: Padding(
                                            padding: EdgeInsets.only(left: 40),
                                            child: AnimatedDefaultTextStyle(
                                              duration: Duration(milliseconds: 100),
                                              style: Theme.of(context).textTheme.displayMedium!.copyWith(
                                                fontSize: calculateTextSize(size),
                                                color: Colors.white,
                                              ),
                                              // hello
                                              child: Text(
                                                planets[index]['name'],
                                                textAlign: TextAlign.start,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              ChatPage(),
            ],
          ),
          // 自定義底部導航欄
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // 獲取屏幕寬度
                final screenWidth = MediaQuery.of(context).size.width;
                // 計算基準尺寸（以屏幕寬度的比例）
                final baseWidth = screenWidth * 0.36; // 約佔屏幕寬度的 36%
                
                // 計算各個按鈕的尺寸，保持原始寬高比
                final questionSize = Size(baseWidth * 0.78, baseWidth * 1.1);  // 140/179 ≈ 0.78, 198/179 ≈ 1.1
                final studySize = Size(baseWidth, baseWidth * 1.41);  // 179/179 = 1, 253/179 ≈ 1.41
                final chatSize = Size(baseWidth * 0.79, baseWidth * 1.11);  // 141/179 ≈ 0.79, 199/179 ≈ 1.11

                return Container(
                  height: baseWidth * 1.41,  // 使用最高按鈕的高度
                  child: Stack(
                    clipBehavior: Clip.none, // 允許子元素超出邊界
                    alignment: Alignment.bottomCenter,
                    children: [
                      // 模糊效果底框 (最底層)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: SizedBox(
                          height: baseWidth * 1, // Provide a height constraint
                          child: Column(
                            children: [
                              // Top part with lighter blur
                              Expanded(
                                flex: 2,
                                child: ClipRect(
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 1.0, sigmaY: 1.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.white.withOpacity(0.0),
                                            Colors.white.withOpacity(0.02),
                                          ],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Middle part with stronger blur
                              Expanded(
                                flex: 4,
                                child: ClipRect(
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 3.0, sigmaY: 3.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.white.withOpacity(0.02),
                                            Colors.white.withOpacity(0.05),
                                          ],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Bottom part with lighter blur
                              Expanded(
                                flex: 2,
                                child: ClipRect(
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.white.withOpacity(0.05),
                                            Colors.white.withOpacity(0.0),
                                          ],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),


                      // 導航按鈕 - 學習（次底層）
                      Positioned(
                        bottom: baseWidth * 0.1,
                        left: (screenWidth - studySize.width) / 2,
                        child: Container(
                          width: studySize.width * 1.17,
                          height: studySize.height * 1.17,
                          child: GestureDetector(
                            onTap: () => _onItemTapped(1),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Expanded(
                                  child: Image.asset(
                                    'assets/images/toolbar-study.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                SizedBox(height: baseWidth * 0.02),
                                Text(
                                  '學習',
                                  style: TextStyle(
                                    color: _selectedIndex == 1 ? Colors.white : Colors.white.withOpacity(0.7),
                                    fontSize: baseWidth * 0.08,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // 背景圖片 - 放在學習按鈕上方
                      Positioned(
                        bottom: -screenWidth * 0.06,
                        left: 0,
                        child: Container(
                          width: screenWidth * 1.2,
                          height: baseWidth,
                          child: Image.asset(
                            'assets/images/toolbar-background.png',
                            fit: BoxFit.fill,
                          ),
                        ),
                      ),
                      // 導航按鈕 - 即問題
                      Positioned(
                        right: screenWidth * 0.05,
                        bottom: baseWidth * 0.19,
                        child: Container(
                          width: chatSize.width * 1.2,
                          height: chatSize.height * 1.2,
                          child: GestureDetector(
                            onTap: () => _onItemTapped(2),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Expanded(
                                  child: Image.asset(
                                    'assets/images/toolbar-chat.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                SizedBox(height: baseWidth * 0.02),
                                Text(
                                  '汪汪題',
                                  style: TextStyle(
                                    color: _selectedIndex == 2 ? Colors.white : Colors.white.withOpacity(0.7),
                                    fontSize: baseWidth * 0.08,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // 導航按鈕 - 錯題本（最上層）
                      Positioned(
                        left: screenWidth * 0.04,
                        bottom: baseWidth * 0.16,
                        child: Container(
                          width: questionSize.width * 1.2,
                          height: questionSize.height * 1.2,
                          child: GestureDetector(
                            onTap: () => _onItemTapped(0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Expanded(
                                  child: Image.asset(
                                    'assets/images/toolbar-question.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                SizedBox(height: baseWidth * 0.02),
                                Text(
                                  '錯題本',
                                  style: TextStyle(
                                    color: _selectedIndex == 0 ? Colors.white : Colors.white.withOpacity(0.7),
                                    fontSize: baseWidth * 0.08,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  final List<Map<String, dynamic>> planets = [
    {
      'name': '理化',
      'image': 'assets/pics/home-island2.png',
    },
    {
      'name': '物理',
      'image': 'assets/pics/home-island3.png',
    },
    {
      'name': '化學',
      'image': 'assets/pics/home-island4.png',
    },
    {
      'name': '數學',
      'image': 'assets/pics/home-island5.png',
    },
    {
      'name': '地科',
      'image': 'assets/pics/home-island4.png',
    },
    {
      'name': '生物',
      'image': 'assets/pics/home-island5.png',
    },
    {
      'name': '公民',
      'image': 'assets/pics/home-island3.png',
    },
    {
      'name': '歷史',
      'image': 'assets/pics/home-island1.png',
    },
    {
      'name': '地理',
      'image': 'assets/pics/home-island2.png',
    },
    {
      'name': '國文',
      'image': 'assets/pics/home-island1.png',
    },
    {
      'name': '英文',
      'image': 'assets/pics/home-island2.png',  // 重複使用圖片
    },
  ];
}

// 自定義吸附式滾動物理效果
class SnappingScrollPhysics extends ScrollPhysics {
  final double itemExtent;

  const SnappingScrollPhysics({
    ScrollPhysics? parent,
    required this.itemExtent,
  }) : super(parent: parent);

  @override
  SnappingScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return SnappingScrollPhysics(
      parent: buildParent(ancestor),
      itemExtent: itemExtent,
    );
  }

  double _getPage(ScrollMetrics position) {
    return position.pixels / itemExtent;
  }

  double _getPixels(double page) {
    return page * itemExtent;
  }

  double _getTargetPixels(ScrollMetrics position, Tolerance tolerance, double velocity) {
    double page = _getPage(position);
    if (velocity < -tolerance.velocity) {
      page -= 0.5;
    } else if (velocity > tolerance.velocity) {
      page += 0.5;
    }
    return _getPixels(page.roundToDouble());
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    // 如果已經在邊界，使用默認行為
    if (position.outOfRange) {
      return super.createBallisticSimulation(position, velocity);
    }

    final Tolerance tolerance = this.tolerance;
    final double target = _getTargetPixels(position, tolerance, velocity);
    
    // 如果目標滾動位置非常接近當前位置，且沒有滾動速度，不使用模擬
    if ((target - position.pixels).abs() < tolerance.distance &&
        velocity.abs() < tolerance.velocity) {
      return null;
    }
    
    // 返回一個使滾動動畫平滑的彈簧模擬
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: tolerance,
    );
  }
}