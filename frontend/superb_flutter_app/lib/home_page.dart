import 'package:flutter/material.dart';
import 'main.dart';  // 引入原來的 AI 問問題頁面
import 'auth.dart';  // Import the AuthPage
import 'mistake_book.dart';  // Import the MistakeBookPage
import 'dart:math';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 2;  // AI 問問題在中間，索引為 2
  ScrollController _scrollController = ScrollController();
  final double _maxPlanetSize = 200.0;  // 增加最大尺寸
  final double _minPlanetSize = 100.0;  // 增加最小尺寸
  double _screenHeight = 600.0;  // 初始值
  
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
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          Center(child: Text('探索', style: TextStyle(color: Colors.white))),
          MistakeBookPage(),  // Add MistakeBookPage here
          Container(
            decoration: BoxDecoration(
              color: Color(0xFF1B3B4B), // 深藍色微偏綠
            ),
            child: Column(
              children: [
                SizedBox(height: 60),
                Text(
                  '首頁',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      _screenHeight = constraints.maxHeight;
                      return ListView.builder(
                        controller: _scrollController,
                        itemCount: planets.length,
                        itemBuilder: (context, index) {
                          return AnimatedBuilder(
                            animation: _scrollController,
                            builder: (context, child) {
                              double itemPosition = index * 180.0; // 減少間距
                              double scrollPosition = _scrollController.hasClients 
                                  ? _scrollController.offset 
                                  : 0.0;
                              double viewportCenter = constraints.maxHeight * 0.4;
                              double size = calculatePlanetSize(
                                scrollPosition + viewportCenter,
                                itemPosition
                              );
                              
                              bool isLeft = index.isEven; // 偶數在左，奇數在右
                              
                              return Container(
                                height: 180,
                                padding: EdgeInsets.symmetric(horizontal: 40), // 增加水平內邊距
                                child: Row(
                                  mainAxisAlignment: isLeft 
                                      ? MainAxisAlignment.start 
                                      : MainAxisAlignment.end,
                                  children: [
                                    if (!isLeft) Expanded(
                                      child: Padding(
                                        padding: EdgeInsets.only(right: 40), // 增加文字和圖片之間的間距
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
                                        },
                                        child: Image.asset(
                                          planets[index]['image'],
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                    if (isLeft) Expanded(
                                      child: Padding(
                                        padding: EdgeInsets.only(left: 40), // 增加文字和圖片之間的間距
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
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          ChatPage(),
          AuthPage(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Colors.white.withOpacity(0.2),
              width: 0.5,
            ),
          ),
        ),
        child: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.search),
              label: '探索',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.book),
              label: '錯題本',  // This should correspond to MistakeBookPage
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: '首頁',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat),
              label: 'AI問答',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: '我的',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white.withOpacity(0.5),
          backgroundColor: Color(0xFF1B3B4B), // 深藍色微偏綠
          type: BottomNavigationBarType.fixed,
          onTap: _onItemTapped,
        ),
      ),
    );
  }

  final List<Map<String, dynamic>> planets = [
    {
      'name': '社會',
      'image': 'assets/pics/planet1.png',
    },
    {
      'name': '自然',
      'image': 'assets/pics/planet2.png',
    },
    {
      'name': '數學',
      'image': 'assets/pics/planet3.png',
    },
    {
      'name': '國文',
      'image': 'assets/pics/planet4.png',
    },
    {
      'name': '英文',
      'image': 'assets/pics/planet1.png',  // 重複使用圖片
    },
    {
      'name': '理化',
      'image': 'assets/pics/planet2.png',
    },
    {
      'name': '物理',
      'image': 'assets/pics/planet3.png',
    },
    {
      'name': '化學',
      'image': 'assets/pics/planet4.png',
    },
    {
      'name': '地科',
      'image': 'assets/pics/planet1.png',
    },
    {
      'name': '生物',
      'image': 'assets/pics/planet2.png',
    },
    {
      'name': '歷史',
      'image': 'assets/pics/planet3.png',
    },
    {
      'name': '地理',
      'image': 'assets/pics/planet4.png',
    },
  ];
}