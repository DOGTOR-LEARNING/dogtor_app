import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui'; // 添加這行來引入 ImageFilter
// 引入原來的 AI 問問題頁面
// Import the AuthPage
import 'mistake_book_n.dart'; // Import the MistakeBookPage
import 'dart:math';
// import 'chapter_detail_page.dart';  // 默認深藍色
import 'chapter_detail_page_n.dart'; // 藍橘配色
import 'chat_page_s.dart';
import 'user_profile_page.dart'; // 引入新的用戶中心頁面
import 'package:flutter_svg/flutter_svg.dart';
import 'user_stats_page.dart'; // Import the UserStatsPage
import 'friends_page.dart'; // 引入新的好友頁面
import 'notification_status_page.dart'; // Import the NotificationStatusPage
import 'heart_display_widget.dart'; // 引入新的生命樹組件
// 引入生命不足對話框

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  int _selectedIndex = 1;
  final ScrollController _scrollController = ScrollController();
  final double _maxPlanetSize = 200.0;
  final double _minPlanetSize = 10.0;
  double _screenHeight = 600.0;
  String? _userPhotoUrl;
  // Heart display widgets
  HeartDisplayWidget? _heartDisplayWidget;

  late AnimationController? _shimmerController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserPhoto();
    _shimmerController = AnimationController(
      duration: Duration(seconds: 5), // Slower animation to reduce GPU load
      vsync: this,
    )..repeat();

    // Remove automatic scroll initialization to prevent jumping back
    // Users can manually scroll to their desired position
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
    } else if (name == '高中化學') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChapterDetailPage(
            subject: '高中化學',
            csvPath: 'assets/edu_data/level_info/high_chem_level.csv',
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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
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
                height: screenHeight * 0.75,
                width: screenWidth,
                child: Stack(
                  children: [
                    if (_shimmerController != null)
                      _HorizonShimmerLayer(animation: _shimmerController!),
                    _UnifiedSeaLayer(
                      scrollController: _scrollController,
                      shimmerController: _shimmerController!,
                      minPlanetSize: _minPlanetSize,
                      maxPlanetSize: _maxPlanetSize,
                      screenHeightSetter: (h) => _screenHeight = h,
                      onPlanetTap: _onPlanetTap,
                      planets: planets,
                    ),
                  ],
                ),
              )),
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

// --- Modular Layer Widgets ---

class _BaseSeaSkyLayer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 1,
          child: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/home-background-sky.png'),
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Container(color: Color.fromARGB(255, 4, 91, 178)), // Ocean blue
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
    return IgnorePointer(
      child: Stack(
        children: [
          // Fill the entire sea area with a vertical gradient that fades to transparent at the bottom
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.05, 0.1, 0.35, 1.0],
                  colors: [
                    const Color.fromARGB(0, 255, 240, 192).withOpacity(0.35),
                    const Color.fromARGB(0, 254, 252, 216).withOpacity(0.25),
                    const Color.fromARGB(0, 250, 237, 164).withOpacity(0.15),
                    Colors.transparent,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Subtle highlight at the horizon line
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 4,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.65),
                    Colors.white.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),

          // Gentle yellow shimmer glows drifting near the horizon to match sky
          AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              final Size size = MediaQuery.of(context).size;
              final double t = animation.value; // 0..1

              final double bandWidth = size.width * 1.2; // extend beyond screen
              const double bandHeight = 120.0;
              final double dx = sin(2 * pi * t) * size.width * 0.15;

              return Stack(
                children: [
                  // Primary soft yellow glow
                  Positioned(
                    top: 10.0,
                    left: (size.width - bandWidth) / 2 + dx,
                    width: bandWidth,
                    height: bandHeight,
                    child: Opacity(
                      opacity: 0.22,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.0, 0.45, 1.0],
                            colors: [
                              const Color(0xFFFFF1B2), // warm yellow
                              const Color(0xFFFFE59A).withOpacity(0.55),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Secondary fainter glow for depth
                  Positioned(
                    top: 30.0,
                    left: (size.width - bandWidth) / 2 - dx * 0.6,
                    width: bandWidth,
                    height: bandHeight * 0.8,
                    child: Opacity(
                      opacity: 0.14,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.0, 0.4, 1.0],
                            colors: [
                              const Color(0xFFFFF4C6),
                              const Color(0xFFFFEAA8).withOpacity(0.45),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class WaveShimmerPainter extends CustomPainter {
  final Color color;
  final double animationValue;
  final int waveCount;
  final double amplitude;

  WaveShimmerPainter({
    required this.color,
    required this.animationValue,
    required this.waveCount,
    required this.amplitude,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withOpacity(0.6),
          color.withOpacity(0.6),
          color.withOpacity(0.6),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();

    // Start from top-left
    path.moveTo(0, 0);

    // Draw top wave edge
    path.lineTo(size.width, 0);

    // Draw right edge
    path.lineTo(size.width, size.height);

    // Draw bottom wave edge
    for (int i = size.width.toInt(); i >= 0; i--) {
      final x = i.toDouble();
      final waveOffset = amplitude *
          0.5 *
          sin(1.3 * pi * waveCount * x / size.width +
              animationValue * 2 * pi +
              pi);
      final y = size.height * 0.7 + waveOffset * 5;
      path.lineTo(x, y);
    }

    // Close the path
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(WaveShimmerPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.color != color ||
        oldDelegate.waveCount != waveCount ||
        oldDelegate.amplitude != amplitude;
  }
}

// Unified sea layer that combines islands and waves in a single scrollable widget
class _UnifiedSeaLayer extends StatefulWidget {
  final ScrollController scrollController;
  final AnimationController shimmerController;
  final double minPlanetSize;
  final double maxPlanetSize;
  final Function(double) screenHeightSetter;
  final Function(int) onPlanetTap;
  final List<Map<String, dynamic>> planets;

  const _UnifiedSeaLayer({
    required this.scrollController,
    required this.shimmerController,
    required this.minPlanetSize,
    required this.maxPlanetSize,
    required this.screenHeightSetter,
    required this.onPlanetTap,
    required this.planets,
  });

  @override
  State<_UnifiedSeaLayer> createState() => _UnifiedSeaLayerState();
}

class _UnifiedSeaLayerState extends State<_UnifiedSeaLayer> {
  late List<List<Map<String, dynamic>>> _islandWaves;

  @override
  void initState() {
    super.initState();
    _islandWaves = _generateWavesForEachIsland();
  }

  // Generate waves specifically for each island
  List<List<Map<String, dynamic>>> _generateWavesForEachIsland() {
    final random = Random(42);
    List<List<Map<String, dynamic>>> allIslandWaves = [];

    for (int islandIndex = 0;
        islandIndex < widget.planets.length;
        islandIndex++) {
      List<Map<String, dynamic>> islandWaveList = [];

      // Create 6-10 waves around each island (more visible but still light)
      int waveCount = 6 + random.nextInt(5);

      for (int waveIndex = 0; waveIndex < waveCount; waveIndex++) {
        islandWaveList.add({
          'imageIndex': random.nextInt(6) + 1,
          'offsetX': (random.nextDouble() - 0.5) * 0.8, // wider spread
          'offsetY': (random.nextDouble() - 0.5) *
              160, // ±80 pixels from island center
          'scale':
              0.25 + random.nextDouble() * 0.35, // larger waves: 0.25 to 0.6
          'speed': 0.08 +
              random.nextDouble() * 0.22, // slightly slower for calmer look
          'phase': random.nextDouble() * 2 * pi,
          'opacity': 0.5 + random.nextDouble() * 0.3, // stronger opacity
        });
      }

      allIslandWaves.add(islandWaveList);
    }

    return allIslandWaves;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        widget.screenHeightSetter(constraints.maxHeight);
        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: widget.scrollController,
                physics: ClampingScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height *
                      2.1, // Fixed large container
                  child: Stack(
                    children: [
                      // Position all islands at the bottom of the container
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Column(
                          children: widget.planets.asMap().entries.map((entry) {
                            final index = entry.key;
                            final planetData = entry.value;
                            return AnimatedBuilder(
                              animation: Listenable.merge([
                                widget.shimmerController,
                                widget.scrollController
                              ]),
                              builder: (context, child) {
                                return IslandItem(
                                  index: index,
                                  planetData: planetData,
                                  waveData: _islandWaves[index],
                                  shimmerController: widget.shimmerController,
                                  minPlanetSize: widget.minPlanetSize,
                                  maxPlanetSize: widget.maxPlanetSize,
                                  onTap: () => widget.onPlanetTap(index),
                                  scrollController: widget
                                      .scrollController, // Pass scroll controller
                                  totalPlanets: widget.planets.length,
                                );
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
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
  const _BottomNavBar(
      {required this.selectedIndex, required this.onItemTapped});
  @override
  Widget build(BuildContext context) {
    // 獲取屏幕寬度
    final screenWidth = MediaQuery.of(context).size.width;
    // 計算基準尺寸（以屏幕寬度的比例）
    final baseWidth = screenWidth * 0.36; // 約佔屏幕寬度的 36%

    // 計算各個按鈕的尺寸，保持原始寬高比
    final questionSize = Size(
        baseWidth * 0.78, baseWidth * 1.1); // 140/179 ≈ 0.78, 198/179 ≈ 1.1
    final studySize =
        Size(baseWidth, baseWidth * 1.41); // 179/179 = 1, 253/179 ≈ 1.41
    final chatSize = Size(
        baseWidth * 0.79, baseWidth * 1.11); // 141/179 ≈ 0.79, 199/179 ≈ 1.11

    return SizedBox(
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
            child: SizedBox(
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
            child: SizedBox(
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
                        color: selectedIndex == 0
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

          // 導航按鈕 - 即問題
          Positioned(
            right: screenWidth * 0.05,
            bottom: baseWidth * 0.19,
            child: SizedBox(
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
                        color: selectedIndex == 2
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

          // 導航按鈕 - 學習（放在最上層確保可點擊性）
          Positioned(
            bottom: baseWidth * 0.1,
            left: (screenWidth - studySize.width) / 2,
            child: SizedBox(
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
                        color: selectedIndex == 1
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
  }
}

class IslandItem extends StatelessWidget {
  final int index;
  final Map<String, dynamic> planetData;
  final List<Map<String, dynamic>> waveData;
  final AnimationController shimmerController;
  final double minPlanetSize;
  final double maxPlanetSize;
  final VoidCallback onTap;
  final ScrollController scrollController; // Add scroll controller parameter
  final int totalPlanets;

  const IslandItem({
    super.key,
    required this.index,
    required this.planetData,
    required this.waveData,
    required this.shimmerController,
    required this.minPlanetSize,
    required this.maxPlanetSize,
    required this.onTap,
    required this.scrollController, // Required parameter
    required this.totalPlanets,
  });

  double calculatePlanetSize(BuildContext context) {
    // Use scroll position instead of findRenderObject for much better performance
    final double scrollOffset =
        scrollController.hasClients ? scrollController.offset : 0.0;
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final double screenHeight = mediaQuery.size.height;
    final double seaLayerHeight =
        screenHeight * 0.75; // height of the sea layer viewport

    // Calculate the approximate position of this island based on index and scroll
    // Fixed stride so consecutive islands don't drift
    final double itemSpacing = 150.0;
    final double containerHeight = screenHeight * 2.1;
    final double columnHeight = totalPlanets * itemSpacing;
    final double baseTop = containerHeight - columnHeight;
    final double yAbsTop = baseTop + index * itemSpacing;

    // Use the island's vertical center for a natural shrink-to-point at the horizon
    final double yCenterViewport = (yAbsTop + itemSpacing / 2) - scrollOffset;

    // Normalized position within sea layer (0 = horizon, 1 = bottom)
    final double normalizedPosition =
        (yCenterViewport / seaLayerHeight).clamp(0.0, 1.0);

    // Curved perspective for natural size change
    final double curvedFactor = 1.0 - pow(1.0 - normalizedPosition, 3.2);

    // Size goes to 0 exactly at the horizon
    return (curvedFactor * maxPlanetSize).clamp(0.0, maxPlanetSize);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final islandSize = calculatePlanetSize(context).clamp(0.0, 200.0);
    final itemHeight =
        islandSize.clamp(10.0, 200.0); // Min/max heights for stability
    final isLeft = index.isEven;
    final t = shimmerController.value;

    // If island size is 0 (at/above horizon), don't render anything
    if (islandSize <= 0.0) {
      return SizedBox(height: (itemHeight - 40).clamp(0.0, 200.0));
    }

    // Calculate curved perspective positioning mimicking Earth's curvature
    double normalizedDistance = islandSize / maxPlanetSize;

    // Create a curved path that starts wide, curves inward, then spreads again
    // This mimics how islands appear to move across the horizon
    double curvePhase = normalizedDistance.clamp(0.0, 1.0);

    // Base offset from center (alternating left/right)
    double baseOffsetFromCenter =
        isLeft ? -screenWidth * 0.3 : screenWidth * 0.3;

    // Curved convergence factor - islands curve toward center as they emerge
    double convergenceCurve = 0.0 + pow(curvePhase, 1.6);

    // Add a slight "S" curve effect for more natural movement
    double sCurveEffect = sin(curvePhase * pi * 2) * 0.15 * (1.0 - curvePhase);

    // Calculate final horizontal position with curved path
    double curvedOffset =
        baseOffsetFromCenter * (convergenceCurve + sCurveEffect);
    double finalX = (screenWidth / 2) + curvedOffset - (islandSize / 2);

    return RepaintBoundary(
      child: SizedBox(
        height: 150.0,
        child: Stack(
          children: [
            // Render waves
            ...waveData.map((wave) {
              final double waveX = screenWidth * 0.5 +
                  screenWidth * wave['offsetX'] +
                  6 * sin(2 * pi * t * wave['speed'] + wave['phase']);
              final double waveY = 75.0 +
                  wave['offsetY'] +
                  4 * sin(2 * pi * t * wave['speed'] + wave['phase'] + pi / 4);

              // Shrink waves with island progress toward horizon (simple and smooth)
              final double finalWaveScale =
                  (wave['scale'] * normalizedDistance).clamp(0.0, 2.0);
              final double waveOpacity = (wave['opacity']).clamp(0.0, 1.0);

              return Positioned(
                left: waveX - 60,
                top: waveY,
                child: Transform.scale(
                  scale: finalWaveScale,
                  child: Opacity(
                    opacity: waveOpacity,
                    child: Image.asset(
                      'assets/images/waves/${wave['imageIndex']}.png',
                      width: 120,
                      height: 120,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: Text(
                              'Wave ${wave['imageIndex']}',
                              style: TextStyle(
                                  color: Colors.blueGrey, fontSize: 8),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            }),

            // Render island with curved vertical positioning
            Positioned(
              left: finalX,
              top: 0,
              bottom: 0, // ← now this child's box stretches top→bottom
              child: Align(
                // ← Align its contents in the middle
                alignment: Alignment.center,
                child: GestureDetector(
                  onTap: onTap,
                  child: Image.asset(
                    planetData['image'],
                    width: islandSize,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ],
        ),
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
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          UserProfilePage(),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                        const begin = Offset(1.0, 0.0);
                        const end = Offset.zero;
                        const curve = Curves.easeInOut;
                        var tween = Tween(begin: begin, end: end)
                            .chain(CurveTween(curve: curve));
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
                onTap: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          FriendsPage(),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                        const begin = Offset(1.0, 0.0);
                        const end = Offset.zero;
                        const curve = Curves.easeInOut;
                        var tween = Tween(begin: begin, end: end)
                            .chain(CurveTween(curve: curve));
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
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          NotificationStatusPage(),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                        const begin = Offset(1.0, 0.0);
                        const end = Offset.zero;
                        const curve = Curves.easeInOut;
                        var tween = Tween(begin: begin, end: end)
                            .chain(CurveTween(curve: curve));
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
