import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui'; // 添加這行來引入 ImageFilter
import 'dart:math'; // 添加這行來引入 pow 函數
import 'main.dart'; // 引入原來的 AI 問問題頁面
import 'auth_page.dart'; // Import the AuthPage
import 'mistake_book_n.dart'; // Import the MistakeBookPage
// import 'chapter_detail_page.dart';  // 默認深藍色
import 'chapter_detail_page_n.dart'; // 藍橘配色
import 'chat_page_s.dart';
import 'user_profile_page.dart'; // 引入新的用戶中心頁面
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/rendering.dart';
import 'user_stats_page.dart'; // Import the UserStatsPage
import 'friends_page.dart'; // 引入新的好友頁面

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int _selectedIndex = 1;
  ScrollController _scrollController = ScrollController();
  String? _userPhotoUrl; // 添加用戶頭像 URL 狀態變量

  // 新增：透視相關參數
  double _screenHeight = 800.0; // 初始屏幕高度
  double _screenWidth = 400.0; // 初始屏幕寬度
  double _scrollPosition = 0.0; // 當前滾動位置

  // 消失點位置 (基於截圖定位在海平面位置)
  double vanishPointX = 0.5; // 消失點 X 座標 (佔屏幕寬度的比例，0.5 = 中間)
  double vanishPointY = 0.25; // 消失點 Y 座標 (佔屏幕高度的比例，海平面位置)

  // 定義視景深度 - 控制縮放速率
  double perspectiveDepth = 2000.0;

  // 控制島嶼大小
  double baseIslandSize = 280.0; // 基礎島嶼大小 (最大尺寸)

  // 追蹤當前最大島嶼索引
  int _currentFocusIndex = 0;

  // 追蹤已經看過的島嶼
  Set<int> _viewedIslands = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserPhoto(); // 在初始化時加載用戶頭像

    // 監聽滾動事件
    _scrollController.addListener(() {
      setState(() {
        _scrollPosition = _scrollController.offset;
        _updateCurrentFocusIndex();
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
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

  // 更新當前焦點島嶼索引
  void _updateCurrentFocusIndex() {
    // 計算當前中心位置島嶼
    double estimatedIndex = _scrollPosition / 700.0;
    int newIndex = estimatedIndex.floor();

    // 確保索引在有效範圍內
    newIndex = newIndex.clamp(0, planets.length - 1);

    // 如果索引改變，將其添加到已查看集合
    if (newIndex != _currentFocusIndex) {
      _viewedIslands.add(_currentFocusIndex);
      _currentFocusIndex = newIndex;
    }
  }

  // 檢查島嶼是否應該顯示
  bool _shouldDisplayIsland(int index, double zPosition) {
    // 如果是當前焦點島嶼，始終顯示
    if (index == _currentFocusIndex) return true;

    // 如果在消失點後面或超出屏幕，不顯示
    if (zPosition < 0 || _calculateScreenY(zPosition) > _screenHeight + 200)
      return false;

    // 如果已經看過，且不在視野中心附近，不顯示
    if (_viewedIslands.contains(index) &&
        (index < _currentFocusIndex - 1 || index > _currentFocusIndex + 1)) {
      return false;
    }

    return true;
  }

  // 計算島嶼在 Z 軸上的位置 (基於滾動位置)
  double _calculateZPosition(int index) {
    // 起始 Z 位置 - 增加間距
    double baseZ = index * 700.0;
    // 當前 Z 位置 = 基礎位置 - 滾動偏移 (滾動時移動)
    return baseZ - _scrollPosition;
  }

  // 從 Z 位置計算屏幕上的 Y 座標
  double _calculateScreenY(double zPosition) {
    // 如果在消失點後面，則不可見
    if (zPosition < 0) return -1000;

    // 計算透視映射: 越遠的物體越接近消失點
    double perspectiveFactor =
        perspectiveDepth / (perspectiveDepth + zPosition);

    // 映射到屏幕座標 (消失點為參考點)
    // 調整使其不會在底部堆積 - 減少屏幕高度的使用比例
    double screenY = vanishPointY * _screenHeight +
        (1.0 - perspectiveFactor) * (_screenHeight * 0.6);

    return screenY;
  }

  // 計算島嶼的縮放比例 (基於 Z 位置)
  double _calculateScale(double zPosition) {
    // 如果在消失點後面，則不可見
    if (zPosition < 0) return 0.0;

    // 透視因子: 0 (消失點) 到 1 (最近位置)
    double perspectiveFactor =
        perspectiveDepth / (perspectiveDepth + zPosition);

    // 使縮放更極端，讓近處的更大，遠處的更小
    double scale = pow(1.0 - perspectiveFactor * 0.95, 1.8).toDouble();

    return scale;
  }

  // 計算 X 座標 (左右偏移，基於透視)
  double _calculateScreenX(double zPosition, bool isLeft) {
    // 如果在消失點後面，則不可見
    if (zPosition < 0) return 0;

    // 透視因子
    double perspectiveFactor =
        perspectiveDepth / (perspectiveDepth + zPosition);

    // 計算基於透視的左右偏移
    double screenX;
    if (isLeft) {
      // 從中間向消失點的左側延伸
      screenX = vanishPointX * _screenWidth -
          (1.0 - perspectiveFactor) * (_screenWidth * 0.5);
    } else {
      // 從中間向消失點的右側延伸
      screenX = vanishPointX * _screenWidth +
          (1.0 - perspectiveFactor) * (_screenWidth * 0.5);
    }

    return screenX;
  }

  // 計算不透明度 (越遠越透明)
  double _calculateOpacity(double zPosition) {
    if (zPosition < 0) return 0.0;

    // 透視因子
    double perspectiveFactor =
        perspectiveDepth / (perspectiveDepth + zPosition);

    // 非線性漸變: 接近消失點時迅速消失
    return (1.0 - perspectiveFactor * perspectiveFactor * 0.95).clamp(0.0, 1.0);
  }

  // 計算文字大小
  double _calculateTextSize(double scale) {
    // 基本字體大小
    double baseSize = 22.0;
    // 返回縮放後的字體大小
    return baseSize * scale;
  }

  // 導航到科目詳情頁面
  void _navigateToSubjectPage(String subject) {
    String csvPath = '';

    if (subject == '自然') {
      csvPath = 'assets/edu_data/level_info/junior_science_level.csv';
    } else if (subject == '高中化學') {
      csvPath = 'assets/edu_data/level_info/high_chem_level.csv';
    } else if (subject == '歷史') {
      csvPath = 'assets/edu_data/level_info/junior_his_level.csv';
    } else if (subject == '地理') {
      csvPath = 'assets/edu_data/level_info/junior_geo_level.csv';
    } else if (subject == '公民') {
      csvPath = 'assets/edu_data/level_info/junior_civ_level.csv';
    } else {
      return; // 其他科目暫不跳轉
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChapterDetailPage(
          subject: subject,
          csvPath: csvPath,
        ),
      ),
    );
  }

  void _onItemTapped(int index) {
    if (index == 0) {
      // If "錯題本" (Wrongbook) is tapped
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              MistakeBookPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(-1.0, 0.0); // Start from the left
            const end = Offset.zero; // End at the normal position
            const curve = Curves.easeInOut;

            var tween =
                Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            var offsetAnimation = animation.drive(tween);

            return SlideTransition(
              position: offsetAnimation,
              child: child,
            );
          },
        ),
      );
    } else if (index == 1) {
      // If (Stat) is tapped
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const UserStatsPage()),
      );
    } else if (index == 2) {
      // If "汪汪題" (Chat) is tapped
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ChatPage()),
      );
    } else {
      setState(() {
        _selectedIndex = index; // Only update state for "學習" (Learning)
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 更新屏幕尺寸
    _screenWidth = MediaQuery.of(context).size.width;
    _screenHeight = MediaQuery.of(context).size.height;

    // 計算背景縮放和位移
    double scrollFactor = _scrollPosition / 5000.0;
    double bgScale = 1.0 + scrollFactor;

    // 調整背景位移使海平面始終在正確位置
    double bgOffsetY = -_scrollPosition * 0.08;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: Stack(
        children: [
          // 背景圖片 - 隨滾動放大
          AnimatedBuilder(
            animation: _scrollController,
            builder: (context, child) {
              return Transform(
                alignment:
                    Alignment(0.0, -0.5 + scrollFactor * 0.5), // 對齊消失點，並隨滾動調整
                transform: Matrix4.identity()
                  ..translate(0.0, bgOffsetY)
                  ..scale(bgScale),
                child: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/home-background.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              );
            },
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
                                      pageBuilder: (context, animation,
                                              secondaryAnimation) =>
                                          UserProfilePage(),
                                      transitionsBuilder: (context, animation,
                                          secondaryAnimation, child) {
                                        const begin = Offset(1.0, 0.0);
                                        const end = Offset.zero;
                                        const curve = Curves.easeInOut;
                                        var tween = Tween(
                                                begin: begin, end: end)
                                            .chain(CurveTween(curve: curve));
                                        var offsetAnimation =
                                            animation.drive(tween);
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
                                    image: _userPhotoUrl != null &&
                                            _userPhotoUrl!.isNotEmpty
                                        ? DecorationImage(
                                            image: NetworkImage(_userPhotoUrl!),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: _userPhotoUrl == null ||
                                          _userPhotoUrl!.isEmpty
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
                                      pageBuilder: (context, animation,
                                              secondaryAnimation) =>
                                          FriendsPage(),
                                      transitionsBuilder: (context, animation,
                                          secondaryAnimation, child) {
                                        const begin = Offset(1.0, 0.0);
                                        const end = Offset.zero;
                                        const curve = Curves.easeInOut;
                                        var tween = Tween(
                                                begin: begin, end: end)
                                            .chain(CurveTween(curve: curve));
                                        var offsetAnimation =
                                            animation.drive(tween);
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
                            ],
                          ),
                        ],
                      ),
                    ),

                    // 透視視圖區域 - 增加 bottomPadding 防止堆在底部
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // 更新屏幕尺寸
                          _screenHeight = constraints.maxHeight;

                          return Stack(
                            children: [
                              // 隱形滾動容器 (用於捕獲滾動手勢)
                              Container(
                                color: Colors.transparent,
                                width: _screenWidth,
                                height: _screenHeight,
                                child: SingleChildScrollView(
                                  controller: _scrollController,
                                  physics: BouncingScrollPhysics(),
                                  child: Container(
                                    height: planets.length * 700.0 +
                                        500, // 足夠長的滾動區域
                                    width: 1,
                                  ),
                                ),
                              ),

                              // 島嶼層
                              ...planets.asMap().entries.map((entry) {
                                int index = entry.key;
                                Map<String, dynamic> planet = entry.value;

                                // 計算透視位置
                                double zPos = _calculateZPosition(index);

                                // 判斷是否應該顯示該島嶼
                                if (!_shouldDisplayIsland(index, zPos)) {
                                  return SizedBox.shrink();
                                }

                                double screenY = _calculateScreenY(zPos);
                                double scale = _calculateScale(zPos);
                                double opacity = _calculateOpacity(zPos);
                                double textSize = scale * 24.0; // 調整文字大小

                                // 如果在視野範圍外，不渲染 (性能優化)
                                if (screenY < -200 ||
                                    screenY > _screenHeight + 200 ||
                                    opacity <= 0) {
                                  return SizedBox.shrink();
                                }

                                // 計算島嶼大小
                                double islandSize = baseIslandSize * scale;

                                // 將島嶼永遠放在屏幕中間
                                double screenX = _screenWidth / 2;

                                return Positioned(
                                  left: screenX - islandSize / 2, // 中心定位
                                  top: screenY - islandSize / 2, // 中心定位
                                  child: Opacity(
                                    opacity: opacity,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // 島嶼及其名稱
                                        GestureDetector(
                                          onTap: () {
                                            print('點擊了 ${planet['name']}');
                                            _navigateToSubjectPage(
                                                planet['name']);
                                          },
                                          child: Container(
                                            width: islandSize,
                                            height: islandSize,
                                            child: Image.asset(
                                              planet['image'],
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: 5),
                                        // 科目名稱
                                        Text(
                                          planet['name'],
                                          style: TextStyle(
                                            fontSize: textSize,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            shadows: [
                                              Shadow(
                                                offset: Offset(1, 1),
                                                blurRadius: 3.0,
                                                color: Colors.black
                                                    .withOpacity(0.6),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),

                              // 確保底部有足夠的空間，防止與導航欄重疊
                              Container(
                                height: 100,
                                margin: EdgeInsets.only(bottom: 0),
                              ),

                              // 海平面消失點指示器 (調試用，可以註釋掉)
                              // Positioned(
                              //   left: vanishPointX * _screenWidth,
                              //   top: vanishPointY * _screenHeight,
                              //   child: Container(
                              //     width: 10,
                              //     height: 10,
                              //     decoration: BoxDecoration(
                              //       color: Colors.red,
                              //       shape: BoxShape.circle,
                              //     ),
                              //   ),
                              // ),
                            ],
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
                final questionSize = Size(baseWidth * 0.78,
                    baseWidth * 1.1); // 140/179 ≈ 0.78, 198/179 ≈ 1.1
                final studySize = Size(
                    baseWidth, baseWidth * 1.41); // 179/179 = 1, 253/179 ≈ 1.41
                final chatSize = Size(baseWidth * 0.79,
                    baseWidth * 1.11); // 141/179 ≈ 0.79, 199/179 ≈ 1.11

                return Container(
                  height: baseWidth * 1.41, // 使用最高按鈕的高度
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
                                    filter: ImageFilter.blur(
                                        sigmaX: 1.0, sigmaY: 1.0),
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
                                    filter: ImageFilter.blur(
                                        sigmaX: 3.0, sigmaY: 3.0),
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
                                    filter: ImageFilter.blur(
                                        sigmaX: 5.0, sigmaY: 5.0),
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
                                    color: _selectedIndex == 1
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.7),
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
                                    color: _selectedIndex == 2
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.7),
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
                                    color: _selectedIndex == 0
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.7),
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
      'name': '自然',
      'image': 'assets/pics/home-island2.png',
    },
    {
      'name': '物理',
      'image': 'assets/pics/home-island3.png',
    },
    {
      'name': '高中化學',
      'image': 'assets/pics/home-island4.png',
    },
    {
      'name': '國中數學',
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
      'image': 'assets/pics/home-island2.png', // 重複使用圖片
    },
  ];
}
