import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'quiz_page_n.dart'; // blue & orange theme
import 'package:google_fonts/google_fonts.dart';
import 'insufficient_hearts_dialog.dart';  // 引入生命不足對話框

class ChapterDetailPage extends StatefulWidget {
  final String subject;
  final String csvPath;

  ChapterDetailPage({required this.subject, required this.csvPath});

  @override
  _ChapterDetailPageState createState() => _ChapterDetailPageState();
}

class _ChapterDetailPageState extends State<ChapterDetailPage> with SingleTickerProviderStateMixin {
  // 儲存所有章節資料的列表
  List<Map<String, dynamic>> sections = [];
  // 當前章節名稱
  String currentChapter = '';
  // 目前完成的進度
  int currentProgress = 0;
  // 總章節數量
  int totalSections = 0;
  // 用於追蹤哪些章節是展開的
  Map<String, bool> expandedChapters = {};
  // 用於追蹤哪些年級冊別是展開的
  Map<String, bool> expandedGradeBooks = {};
  // 課程適用年級
  String yearGrade = '';
  // 教材冊別
  String book = '';
  // 用戶關卡星星數
  Map<String, int> levelStars = {};
  // 是否正在加載星星數
  bool isLoadingStars = false;
  // 總星星數
  int totalStars = 0;
  // 最大可能星星數 (每關3顆星)
  int maxPossibleStars = 0;
  
  // 動畫控制器q
  late AnimationController _animationController;
  Map<String, Animation<double>> _animations = {};
  
  // 滾動控制器
  late ScrollController _scrollController;
  // 用於記錄上次滾動位置的鍵
  String get _scrollPositionKey => '${widget.subject}_scroll_position';
  // 用於記錄上次展開狀態的鍵
  String get _expandedChaptersKey => '${widget.subject}_expanded_chapters';
  String get _expandedGradeBooksKey => '${widget.subject}_expanded_grade_books';

  // 更新主題色彩以匹配圖片
  final Color primaryColor = Color(0xFF1E5B8C);  // 深藍色主題
  final Color secondaryColor = Color(0xFF2A7AB8); // 較淺的藍色
  final Color accentColor = Color.fromARGB(255, 238, 159, 41);    // 橙色強調色，類似小島的顏色
  final Color cardColor = Color(0xFF3A8BC8);      // 淺藍色卡片背景色
  final Color whiteColor = Color(0xFFFFF9F7);     // 新增白色元素

  @override
  void initState() {
    super.initState();
    print("loaded");  // Debug statement to indicate the page has loaded
    
    // 初始化滾動控制器
    _scrollController = ScrollController();
    
    _loadChapterData();
    _loadUserLevelStars();
    _loadSavedState();
    
    // 初始化動畫控制器
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
  }
  
  @override
  void dispose() {
    _saveCurrentState();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // 獲取用戶 ID
  Future<String?> _getUserId() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('user_id');
      if (userId != null && userId.isNotEmpty) {
        return userId;
      }
      return null;
    } catch (e) {
      print("獲取用戶 ID 時出錯: $e");
      return null;
    }
  }

  // 加載用戶關卡星星數
  Future<void> _loadUserLevelStars() async {
    try {
      setState(() {
        isLoadingStars = true;
      });
      
      String? userId = await _getUserId();
      if (userId == null) {
        print("無法獲取用戶 ID");
        setState(() {
          isLoadingStars = false;
        });
        return;
      }
      
      print("正在獲取用戶星星數，用戶 ID: $userId, 科目: ${widget.subject}");
      final apiUrl = 'https://superb-backend-1041765261654.asia-east1.run.app/quiz/user_level_stars';
      // print("API URL: $apiUrl");
      
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'subject': widget.subject,  // 添加科目參數
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          setState(() {
            // 將字符串鍵轉換為整數鍵
            Map<String, dynamic> stars = data['level_stars'];
            levelStars = stars.map((key, value) => MapEntry(key, value as int));
            
            // 計算總星星數
            totalStars = levelStars.values.fold(0, (sum, stars) => sum + stars);
            
            // 計算最大可能星星數 (每關3顆星)
            maxPossibleStars = sections.length * 3;
            
            // 更新進度
            currentProgress = totalStars;
            totalSections = maxPossibleStars;
            
            isLoadingStars = false;
          });
        } else {
          print("獲取星星數失敗: ${data['message']}");
          setState(() {
            isLoadingStars = false;
          });
        }
      } else {
        print("獲取星星數失敗，狀態碼: ${response.statusCode}，響應內容: ${response.body}");
        setState(() {
          isLoadingStars = false;
        });
      }
    } catch (e) {
      print("加載星星數時出錯: $e");
      print(e.toString());
      setState(() {
        isLoadingStars = false;
      });
    }
  }

  Future<void> _loadChapterData() async {
    try {
      // 從資源檔案中載入 CSV 資料
      final String data = await DefaultAssetBundle.of(context).loadString(widget.csvPath);
      final List<String> rows = data.split('\n');
      
      // 跳過標題行
      final List<Map<String, dynamic>> allSections = rows.skip(1)
          .where((row) => row.trim().isNotEmpty)
          .map((row) {
            final cols = row.split(',');
            if (cols.length < 9) return null; // 確保有足夠的列
            
            return {
              'level_id': cols[9],       // 關卡編號 (最後一列)
              'year_grade': cols[1],     // 年級
              'book': cols[2],           // 冊別
              'chapter_num': cols[3],    // 章節編號
              'chapter_name': cols[4],   // 章節名稱
              'section_num': cols[5],    // 小節編號
              'section_name': cols[6],   // 小節名稱
              'knowledge_spots': cols[7],// 知識點
              'level_name': cols[8],     // 關卡名稱
            };
          })
          .where((map) => map != null)
          .cast<Map<String, dynamic>>()
          .toList();
      
      // 設置年級和冊別（從第一個項目獲取）
      if (allSections.isNotEmpty) {
        yearGrade = allSections[0]['year_grade'];
        book = allSections[0]['book'];
      }
      
      // 初始化所有章節為展開狀態
      Set<String> uniqueChapters = {};
      Set<String> uniqueGradeBooks = {};
      
      for (var section in allSections) {
        if (section.containsKey('chapter_name')) {
          uniqueChapters.add(section['chapter_name']);
        }
        if (section.containsKey('year_grade') && section.containsKey('book')) {
          uniqueGradeBooks.add('${section['year_grade']}_${section['book']}');
        }
      }
      
      // 設置所有章節為展開狀態
      Map<String, bool> initialExpandState = {};
      for (var chapter in uniqueChapters) {
        initialExpandState[chapter] = true; // 默認展開
      }
      
      // 設置所有年級冊別為展開狀態
      Map<String, bool> initialGradeBookExpandState = {};
      for (var gradeBook in uniqueGradeBooks) {
        initialGradeBookExpandState[gradeBook] = true; // 默認展開
      }

      setState(() {
        sections = allSections;
        totalSections = allSections.length * 3; // 每個關卡最多3顆星
        expandedChapters = initialExpandState; // 設置默認展開狀態
        expandedGradeBooks = initialGradeBookExpandState; // 設置默認年級冊別展開狀態
      });
    } catch (e) {
      print('載入章節資料時發生錯誤: $e');
    }
  }

  // 獲取唯一的章節名稱列表
  List<String> getUniqueChapters() {
    Set<String> uniqueChapters = {};
    for (var section in sections) {
      if (section.containsKey('chapter_name')) {
        uniqueChapters.add(section['chapter_name']);
      }
    }
    return uniqueChapters.toList();
  }

  // 載入儲存的狀態
  Future<void> _loadSavedState() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      
      // 載入滾動位置
      double? savedScrollPosition = prefs.getDouble(_scrollPositionKey);
      if (savedScrollPosition != null) {
        // 等UI渲染完畢後再滾動
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(
              savedScrollPosition.clamp(0.0, _scrollController.position.maxScrollExtent)
            );
          }
        });
      }
      
      // 載入章節展開狀態
      String? expandedChaptersJson = prefs.getString(_expandedChaptersKey);
      if (expandedChaptersJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(expandedChaptersJson);
        setState(() {
          expandedChapters = decoded.map((key, value) => MapEntry(key, value as bool));
        });
      }
      
      // 載入年級冊別展開狀態
      String? expandedGradeBooksJson = prefs.getString(_expandedGradeBooksKey);
      if (expandedGradeBooksJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(expandedGradeBooksJson);
        setState(() {
          expandedGradeBooks = decoded.map((key, value) => MapEntry(key, value as bool));
        });
      }
    } catch (e) {
      print('載入儲存狀態時發生錯誤: $e');
    }
  }
  
  // 儲存當前狀態
  Future<void> _saveCurrentState() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      
      // 儲存滾動位置
      if (_scrollController.hasClients) {
        await prefs.setDouble(_scrollPositionKey, _scrollController.offset);
      }
      
      // 儲存章節展開狀態
      await prefs.setString(_expandedChaptersKey, jsonEncode(expandedChapters));
      
      // 儲存年級冊別展開狀態
      await prefs.setString(_expandedGradeBooksKey, jsonEncode(expandedGradeBooks));
    } catch (e) {
      print('儲存狀態時發生錯誤: $e');
    }
  }

  // 切換章節展開/收合狀態
  void _toggleChapter(String chapterName) {
    setState(() {
      expandedChapters[chapterName] = !(expandedChapters[chapterName] ?? true);
      
      // 重置動畫控制器
      _animationController.reset();
      
      // 創建新的動畫
      _animations[chapterName] = CurvedAnimation(
        parent: _animationController,
        curve: expandedChapters[chapterName]! ? Curves.easeOut : Curves.easeIn,
      );
      
      // 開始動畫
      _animationController.forward();
      
      // 保存當前狀態
      _saveCurrentState();
    });
  }
  
  // 切換年級冊別展開/收合狀態
  void _toggleGradeBook(String gradeBook) {
    setState(() {
      expandedGradeBooks[gradeBook] = !(expandedGradeBooks[gradeBook] ?? true);
      
      // 如果收合年級冊別，則收合其下所有章節
      if (!(expandedGradeBooks[gradeBook] ?? true)) {
        for (var section in sections) {
          String sectionGradeBook = '${section['year_grade']}_${section['book']}';
          if (sectionGradeBook == gradeBook) {
            expandedChapters[section['chapter_name']] = false;
          }
        }
      }
      
      // 保存當前狀態
      _saveCurrentState();
    });
  }

  // 獲取章節的年級
  String _getChapterYearGrade(String chapterName) {
    final sectionWithChapter = sections.firstWhere(
      (section) => section['chapter_name'] == chapterName,
      orElse: () => {'year_grade': ''},
    );
    return sectionWithChapter['year_grade'] ?? '';
  }

  // 獲取章節的冊數
  String _getChapterBook(String chapterName) {
    final sectionWithChapter = sections.firstWhere(
      (section) => section['chapter_name'] == chapterName,
      orElse: () => {'book': ''},
    );
    return sectionWithChapter['book'] ?? '';
  }

  Future<Map<String, dynamic>> _checkHeart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      if (userId == null) return {'hasHearts': false, 'remainingTime': null};

      final response = await http.post(
        Uri.parse('https://superb-backend-1041765261654.asia-east1.run.app/hearts/check_heart'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          Duration? remainingTime;
          final nextHeartIn = data['next_heart_in'] as String?;
          
          if (nextHeartIn != null && nextHeartIn.isNotEmpty) {
            try {
              final parts = nextHeartIn.split(':');
              if (parts.length >= 3) {
                final hours = int.tryParse(parts[0]) ?? 0;
                final minutes = int.tryParse(parts[1]) ?? 0;
                final seconds = int.tryParse(parts[2].split('.')[0]) ?? 0;
                
                remainingTime = Duration(
                  hours: hours,
                  minutes: minutes,
                  seconds: seconds,
                );
              }
            } catch (e) {
              print("解析倒數時間失敗: $e");
            }
          }
          
          return {
            'hasHearts': data['hearts'] > -10,
            'remainingTime': remainingTime,
          };
        }
      }
    } catch (e) {
      print("檢查體力失敗: $e");
    }

    return {'hasHearts': false, 'remainingTime': null};
  }

  Future<void> _consumeHeart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      if (userId == null) return;

      final response = await http.post(
        Uri.parse('https://superb-backend-1041765261654.asia-east1.run.app/hearts/consume_heart'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          print("體力扣除成功，剩餘體力: ${data['hearts']}");
        } else {
          print("體力扣除失敗: ${data['message']}");
        }
      } else {
        print("API 錯誤，狀態碼: ${response.statusCode}");
      }
    } catch (e) {
      print("扣除體力時出錯: $e");
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        title: Text(
          '${widget.subject} 學習',
          style: GoogleFonts.notoSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white70),
            onPressed: () {
              _loadChapterData();
              _loadUserLevelStars();
            },
          ),
        ],
      ),
      body: Container(
        // 添加漸變背景，模擬海洋效果
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [primaryColor, Color(0xFF0D3B69)],
          ),
        ),
        child: Column(
          children: [
            // 進度條
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: whiteColor.withOpacity(0.9),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '學習進度',
                        style: GoogleFonts.notoSans(
                          color: primaryColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$currentProgress / $totalSections 顆星',
                        style: GoogleFonts.notoSans(
                          color: primaryColor.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: totalSections > 0 ? currentProgress / totalSections : 0,
                    backgroundColor: secondaryColor.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                    borderRadius: BorderRadius.circular(10),
                    minHeight: 10,
                  ),
                ],
              ),
            ),
            
            // 章節列表
            Expanded(
              child: sections.isEmpty
                  ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController, // 使用滾動控制器
                      padding: EdgeInsets.all(16),
                      itemCount: sections.length > 0 ? getUniqueChapters().length : 0,
                      itemBuilder: (context, index) {
                        final chapterName = getUniqueChapters()[index];
                        final isExpanded = expandedChapters[chapterName] ?? false;
                        
                        // 獲取當前章節的年級和冊數
                        final currentYearGrade = _getChapterYearGrade(chapterName);
                        final currentBook = _getChapterBook(chapterName);
                        final String gradeBookKey = '${currentYearGrade}_${currentBook}';
                        final bool isGradeBookExpanded = expandedGradeBooks[gradeBookKey] ?? true;
                        
                        // 判斷是否需要顯示年級和冊數
                        bool shouldShowGradeAndBook = true;
                        if (index > 0) {
                          final prevChapterName = getUniqueChapters()[index - 1];
                          final prevYearGrade = _getChapterYearGrade(prevChapterName);
                          final prevBook = _getChapterBook(prevChapterName);
                          
                          if (currentYearGrade == prevYearGrade && currentBook == prevBook) {
                            shouldShowGradeAndBook = false;
                          }
                        }
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (shouldShowGradeAndBook && currentYearGrade.isNotEmpty && currentBook.isNotEmpty)
                              InkWell(
                                onTap: () => _toggleGradeBook(gradeBookKey),
                                child: Container(
                                  margin: EdgeInsets.only(left: 8, bottom: 12, top: index > 0 ? 20 : 0),
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: accentColor,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '$currentYearGrade年級 $currentBook',
                                        style: GoogleFonts.notoSans(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(width: 4),
                                      Icon(
                                        isGradeBookExpanded ? Icons.expand_less : Icons.expand_more,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            
                            // 章節卡片 - 只有在對應的年級冊別展開時才顯示
                            if (isGradeBookExpanded)
                              Card(
                                margin: EdgeInsets.only(bottom: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                color: cardColor,
                                child: Column(
                                  children: [
                                    // 章節標題
                                    InkWell(
                                      onTap: () {
                                        _toggleChapter(chapterName);
                                      },
                                      child: Container(
                                        padding: EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(16),
                                            bottom: isExpanded ? Radius.zero : Radius.circular(16),
                                          ),
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [cardColor, cardColor.withOpacity(0.8)],
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: accentColor,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                isExpanded ? Icons.expand_less : Icons.expand_more,
                                                color: Colors.white,
                                              ),
                                            ),
                                            SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                chapterName,
                                                style: GoogleFonts.notoSans(
                                                  color: Colors.white,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    
                                    // 小節列表
                                    if (isExpanded)
                                      AnimatedSize(
                                        duration: Duration(milliseconds: 300),
                                        curve: Curves.easeInOut,
                                        child: Container(
                                          padding: EdgeInsets.symmetric(vertical: 8),
                                          child: Column(
                                            children: sections
                                                .where((section) => section['chapter_name'] == chapterName)
                                                .map((section) => Container(
                                                  margin: EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: whiteColor,
                                                    borderRadius: BorderRadius.circular(12),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black12,
                                                        blurRadius: 3,
                                                        offset: Offset(0, 1),
                                                      ),
                                                    ],
                                                  ),
                                                  child: ListTile(
                                                    contentPadding: EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 8,
                                                    ),
                                                    title: Text(
                                                      section['level_name'],
                                                      style: GoogleFonts.notoSans(
                                                        color: primaryColor,
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                    subtitle: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        SizedBox(height: 4),
                                                        Text(
                                                          '知識點：${section['knowledge_spots']}',
                                                          style: GoogleFonts.notoSans(
                                                            color: secondaryColor.withOpacity(0.8),
                                                            fontSize: 12,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                        SizedBox(height: 8),
                                                        Row(
                                                          children: List.generate(
                                                            3,
                                                            (i) {
                                                              int stars = 0;
                                                              if (!isLoadingStars) {
                                                                String levelId = section['level_id'].toString();
                                                                stars = levelStars[levelId] ?? 0;
                                                              }
                                                              
                                                              return Icon(
                                                                i < stars ? Icons.star : Icons.star_border,
                                                                color: accentColor,
                                                                size: 20,
                                                              );
                                                            },
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    trailing: Container(
                                                      decoration: BoxDecoration(
                                                        color: accentColor,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      padding: EdgeInsets.all(8),
                                                      child: Icon(Icons.play_arrow, color: Colors.white),
                                                    ),
                                                    onTap: () async {
                                                      final heartResult = await _checkHeart();
                                                      final hasHearts = heartResult['hasHearts'] as bool;
                                                      final remainingTime = heartResult['remainingTime'] as Duration?;

                                                      if (hasHearts) {
                                                        _consumeHeart();
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (context) => QuizPage(
                                                              chapter: chapterName,
                                                              section: section['level_name'],
                                                              knowledgePoints: section['knowledge_spots'],
                                                              levelNum: section['level_id'].toString(),
                                                            ),
                                                          ),
                                                        ).then((_) {
                                                          _loadUserLevelStars();
                                                        });
                                                      } else {
                                                        InsufficientHeartsDialog.show(context, remainingTime);
                                                      }
                                                    },
                                                  ),
                                                ))
                                                .toList(),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}