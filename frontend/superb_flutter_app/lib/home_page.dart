import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';  // 添加這行來引入 ImageFilter
import 'main.dart';  // 引入原來的 AI 問問題頁面
import 'auth_page.dart';  // Import the AuthPage
import 'mistake_book_n.dart';  // Import the MistakeBookPage
import 'dart:math';
// import 'chapter_detail_page.dart';  // 默認深藍色
import 'chapter_detail_page_n.dart';  // 藍橘配色
import 'chat_page_s.dart';
import 'user_profile_page.dart';  // 引入新的用戶中心頁面
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/rendering.dart';
import 'user_stats_page.dart';  // Import the UserStatsPage
import 'friends_page.dart';  // 引入新的好友頁面
import 'notification_status_page.dart';  // Import the NotificationStatusPage
import 'heart_display_widget.dart';  // 引入新的生命樹組件
import 'top_heart_display.dart';  // 引入頂部生命樹組件
import 'insufficient_hearts_dialog.dart';  // 引入生命不足對話框

import 'package:http/http.dart' as http;
import 'dart:convert';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin, WidgetsBindingObserver {
  int _selectedIndex = 1;
  final ScrollController _scrollController = ScrollController();
  final double _maxPlanetSize = 200.0;
  final double _minPlanetSize = 100.0;
  double _screenHeight = 600.0;
  String? _userPhotoUrl;
  TopHeartDisplay? _topHeartDisplay;

  late AnimationController? _shimmerController;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserPhoto();
    _shimmerController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _shimmerController?.dispose();
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

  // Add this method to handle planet taps in the modular _IslandsLayer
  void _onPlanetTap(int index) {
                                              print('點擊了 ${planets[index]['name']}');
    final name = planets[index]['name'];
    if (name == '自然') {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => ChapterDetailPage(
                                                      subject: '自然',
                                                      csvPath: 'assets/edu_data/level_info/jun_science_level.csv',
                                                    ),
                                                  ),
                                                );
    } else if (name == '化學') {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => ChapterDetailPage(
                                                      subject: '化學',
                                                      csvPath: 'assets/edu_data/level_info/high_chemistry_level.csv',
                                                    ),
                                                  ),
                                                );
    } else if (name == '國中數學') {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => ChapterDetailPage(
                                                      subject: '國中數學',
                                                      csvPath: 'assets/edu_data/level_info/jun_math_level.csv',
                                                    ),
                                                  ),
                                                );
    } else if (name == '歷史') {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => ChapterDetailPage(
                                                      subject: '歷史',
                                                      csvPath: 'assets/edu_data/level_info/jun_his_level.csv',
                                                    ),
                                                  ),
                                                );
    } else if (name == '地理') {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => ChapterDetailPage(
                                                      subject: '地理',
                                                      csvPath: 'assets/edu_data/level_info/jun_geo_level.csv',
                                                    ),
                                                  ),
                                                );
    } else if (name == '公民') {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => ChapterDetailPage(
                                                      subject: '公民',
                                                      csvPath: 'assets/edu_data/level_info/jun_civ_level.csv',
                                                    ),
                                                  ),
                                                );
                                              }
    // Add more cases as needed for other planets
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth  = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: Stack(
        children: [
          // --- Layer 1: Base Sea + Sky ---
          _BaseSeaSkyLayer(),

          Positioned(
            top: screenHeight * 0.25,
            left: 0,
            right: 0,
            child: SizedBox(
              height: screenHeight*0.75,
              width: screenWidth,
              child: Transform(
                alignment: Alignment.topCenter,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateX(-0.65),
                child: Stack(
                  children:[
                    if (_shimmerController != null)
                      _HorizonShimmerLayer(animation: _shimmerController!),
                    if (_shimmerController != null)
                      _WavesLayer(
                        scrollController: _scrollController,
                        shimmerController: _shimmerController!,
                      ),
                    _IslandsLayer(
                      scrollController: _scrollController,
                      minPlanetSize: _minPlanetSize,
                      maxPlanetSize: _maxPlanetSize,
                      screenHeightSetter: (h) => _screenHeight = h,
                      onPlanetTap: _onPlanetTap,
                      planets: planets,
                    ),
                  ],
                ),
              ),
            )
          ),
          // --- Layer 2: Horizon Shimmer ---

          // --- TopBarOverlay: Dogtor logo (left) + bubbles (right) ---
          Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: _TopBarOverlay(
              userPhotoUrl: _userPhotoUrl,
              reloadPhoto: _loadUserPhoto,
            ),
          ),
          // --- Overlays (hearts, nav bar) ---

          // Bottom nav bar (unchanged)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BottomNavBar(
              selectedIndex: _selectedIndex,
              onItemTapped: _onItemTapped,
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
      'name': '化學',
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

// --- Modular Layer Widgets ---

class _BaseSeaSkyLayer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 1,
          child: Container(color: Color(0xFFB3E5FC)), // Sky blue
        ),
        Expanded(
          flex: 3,
          child: Container(color: Color(0xFF1976D2)), // Ocean blue
        ),
      ],
    );
  }
}

class _HorizonShimmerLayer extends StatelessWidget {
  final AnimationController animation;
  const _HorizonShimmerLayer({required this.animation});
  @override
  Widget build(BuildContext context) {
    final double shimmerHeight = 40;
    final double shimmerWidth = MediaQuery.of(context).size.width * 0.8;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final double t = animation.value;
        final double y = 120 + 20 * (sin(2 * pi * t));
        return Positioned(
          top: y,
          left: (MediaQuery.of(context).size.width - shimmerWidth) / 2,
          child: Opacity(
            opacity: 0.25,
            child: Container(
              width: shimmerWidth,
              height: shimmerHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Center(child: Text('Shimmer Placeholder', style: TextStyle(color: Colors.blueGrey, fontSize: 12))),
            ),
          ),
        );
      },
    );
  }
}

class _WavesLayer extends StatelessWidget {
  final ScrollController scrollController;
  final AnimationController shimmerController;
  const _WavesLayer({required this.scrollController, required this.shimmerController});
  @override
  Widget build(BuildContext context) {
    final double baseY = 180;
    final List<Color> waveColors = [
      Colors.white.withOpacity(0.5),
      Colors.blueAccent.withOpacity(0.3),
      Colors.lightBlueAccent.withOpacity(0.2),
    ];
    return AnimatedBuilder(
      animation: Listenable.merge([scrollController, shimmerController]),
      builder: (context, child) {
        final double scroll = scrollController.hasClients ? scrollController.offset : 0.0;
        final double t = shimmerController.value;
        List<Widget> waves = [];
        for (int i = 0; i < 3; i++) {
          final double scale = 1.0 - 0.15 * (scroll / 300).clamp(0, 1) - 0.05 * i;
          final double y = baseY + i * 30 - (scroll * 0.3) + 10 * sin(2 * pi * t + i);
          final double x = 10 * sin(2 * pi * t + i * 2);
          waves.add(Positioned(
            top: y,
            left: x,
            right: -x,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.center,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                height: 28.0 - i * 4,
                decoration: BoxDecoration(
                  color: waveColors[i],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(child: Text('Wave ${i + 1}', style: TextStyle(color: Colors.blueGrey, fontSize: 10))),
              ),
            ),
          ));
        }
        return Stack(children: waves);
      },
    );
  }
}

class _IslandsLayer extends StatelessWidget {
  final ScrollController scrollController;
  final double minPlanetSize;
  final double maxPlanetSize;
  final Function(double) screenHeightSetter;
  final Function(int) onPlanetTap;
  final List<Map<String, dynamic>> planets;
  const _IslandsLayer({
    required this.scrollController,
    required this.minPlanetSize,
    required this.maxPlanetSize,
    required this.screenHeightSetter,
    required this.onPlanetTap,
    required this.planets,
  });
  double calculatePlanetSize(double scrollPosition, double itemPosition, double screenHeight) {
    double distanceFromHorizon = screenHeight - ((scrollPosition - itemPosition));
    
    distanceFromHorizon = distanceFromHorizon.clamp( 0, screenHeight);
    if(distanceFromHorizon ==0 ) { print(distanceFromHorizon);}
    double sizeFactor = distanceFromHorizon/screenHeight;
    return (maxPlanetSize)* sizeFactor;
  }
  double calculateTextSize(double size) {
    double maxTextSize = 28.0;
    double minTextSize = 18.0;
    double ratio = (size - minPlanetSize) / (maxPlanetSize - minPlanetSize);
    return minTextSize + (maxTextSize - minTextSize) * ratio;
  }
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
        builder: (context, constraints) {
        screenHeightSetter(constraints.maxHeight);
        return Column(
          children: [
            // ListView of islands/planets
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                physics: SnappingScrollPhysics(itemExtent: 180),
                itemCount: planets.length,
                itemBuilder: (context, index) {
                  return AnimatedBuilder(
                    animation: scrollController,
                    builder: (context, child) {
                      double itemPosition = index * 180.0;
                      double scrollPosition = scrollController.hasClients ? scrollController.offset : 0.0;
                      double size = calculatePlanetSize(scrollPosition , itemPosition, constraints.maxHeight);
                      bool isLeft = index.isEven;
                      return Container(
                        height: 160,
                        padding: EdgeInsets.symmetric(horizontal: 40),
                        child: Row(
                          mainAxisAlignment: isLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
                          children: [
                            if (!isLeft)
                              Expanded(
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
                                onTap: () => onPlanetTap(index),
                                child: Image.asset(
                                  planets[index]['image'],
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            if (isLeft)
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(left: 40),
                                  child: AnimatedDefaultTextStyle(
                                    duration: Duration(milliseconds: 100),
                                    style: Theme.of(context).textTheme.displayMedium!.copyWith(
                                          fontSize: calculateTextSize(size),
                                          color: Colors.white,
                                        ),
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
              ),
            ),
          ],
        );
      },
    );
  }
}

// --- Bottom NavBar modularized (unchanged logic) ---
class _BottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;
  const _BottomNavBar({required this.selectedIndex, required this.onItemTapped});
  @override
  Widget build(BuildContext context) {
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
                              // 最頂部，非常輕微的模糊
                              Expanded(
                                flex: 1,
                                child: ClipRect(
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 0.5, sigmaY: 0.5),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.white.withOpacity(0.0),
                                            Colors.white.withOpacity(0.01),
                                          ],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // 第二層模糊
                              Expanded(
                                flex: 1,
                                child: ClipRect(
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 1.0, sigmaY: 1.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.white.withOpacity(0.01),
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
                              // 第三層模糊
                              Expanded(
                                flex: 1,
                                child: ClipRect(
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.white.withOpacity(0.02),
                                            Colors.white.withOpacity(0.03),
                                          ],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // 中間強模糊層
                              Expanded(
                                flex: 2,
                                child: ClipRect(
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 3.0, sigmaY: 3.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.white.withOpacity(0.03),
                                            Colors.white.withOpacity(0.04),
                                          ],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // 倒數第二層模糊
                              Expanded(
                                flex: 1,
                                child: ClipRect(
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.white.withOpacity(0.04),
                                            Colors.white.withOpacity(0.03),
                                          ],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // 底部模糊層
                              Expanded(
                                flex: 1,
                                child: ClipRect(
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.white.withOpacity(0.03),
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

                      // 導航按鈕 - 錯題本
                      Positioned(
                        left: screenWidth * 0.04,
                        bottom: baseWidth * 0.16,
                        child: Container(
                          width: questionSize.width * 1.2,
                          height: questionSize.height * 1.2,
                          child: GestureDetector(
                onTap: () => onItemTapped(0),
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
                        color: selectedIndex == 0 ? Colors.white : Colors.white.withOpacity(0.7),
                                    fontSize: baseWidth * 0.08,
                                  ),
                                ),
                              ],
                            ),
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
                onTap: () => onItemTapped(2),
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
                        color: selectedIndex == 2 ? Colors.white : Colors.white.withOpacity(0.7),
                                    fontSize: baseWidth * 0.08,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      // 導航按鈕 - 學習（放在最上層確保可點擊性）
                      Positioned(
                        bottom: baseWidth * 0.1,
                        left: (screenWidth - studySize.width) / 2,
                        child: Container(
                          width: studySize.width * 1.17,
                          height: studySize.height * 1.17,
                          child: GestureDetector(
                onTap: () => onItemTapped(1),
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
                        color: selectedIndex == 1 ? Colors.white : Colors.white.withOpacity(0.7),
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
  }
}

// --- TopBarOverlay modular widget ---
class _TopBarOverlay extends StatelessWidget {
  final String? userPhotoUrl;
  final VoidCallback reloadPhoto;
  const _TopBarOverlay({
    required this.userPhotoUrl,
    required this.reloadPhoto,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dogtor logo (left)
        Padding(
          padding: const EdgeInsets.only(left: 20.0, top: 0),
          child: SvgPicture.asset(
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
        ),
        Spacer(),
        // Bubbles (right, inlined)
        Padding(
          padding: const EdgeInsets.only(right: 20.0, top: 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
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
                    reloadPhoto();
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
                    image: userPhotoUrl != null && userPhotoUrl!.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(userPhotoUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: userPhotoUrl == null || userPhotoUrl!.isEmpty
                      ? Icon(
                          Icons.person,
                          color: Colors.blue.shade700,
                          size: 24,
                        )
                      : null,
                ),
              ),
              SizedBox(height: 8),
              GestureDetector(
                onTap:  () {
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
              SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) => NotificationStatusPage(),
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
                    Icons.notifications,
                    color: Colors.purple.shade700,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}