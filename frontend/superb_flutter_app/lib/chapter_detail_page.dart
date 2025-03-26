import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'quiz_page.dart';
import 'package:google_fonts/google_fonts.dart';

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
  
  // 動畫控制器
  late AnimationController _animationController;
  Map<String, Animation<double>> _animations = {};

  // 更新主題色彩以匹配 chat_page_s
  final Color primaryColor = Color(0xFF0F172A);  // 深藍色主題
  final Color secondaryColor = Color(0xFF1E293B); // 次要背景色
  final Color accentColor = Color(0xFF38BDF8);    // 亮藍色強調色
  final Color cardColor = Color(0xFF334155);      // 卡片背景色

  @override
  void initState() {
    super.initState();
    _loadChapterData();
    _loadUserLevelStars();
    
    // 初始化動畫控制器
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
  }
  
  @override
  void dispose() {
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
      
      print("正在獲取用戶星星數，用戶 ID: $userId");
      final apiUrl = 'https://superb-backend-1041765261654.asia-east1.run.app/get_user_level_stars';
      // print("API URL: $apiUrl");
      
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
        }),
      );
      
      // print("API 響應狀態碼: ${response.statusCode}");
      // print("API 響應內容: ${response.body}");
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          setState(() {
            // 將字符串鍵轉換為整數鍵
            Map<String, dynamic> stars = data['level_stars'];
            levelStars = stars.map((key, value) => MapEntry(key, value as int));
            
            // 輸出所有獲取到的星星數據
            // print("獲取到的所有星星數據: $levelStars");
            
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
      for (var section in allSections) {
        if (section.containsKey('chapter_name')) {
          uniqueChapters.add(section['chapter_name']);
        }
      }
      
      // 設置所有章節為展開狀態
      Map<String, bool> initialExpandState = {};
      for (var chapter in uniqueChapters) {
        initialExpandState[chapter] = true; // 默認展開
      }

      setState(() {
        sections = allSections;
        totalSections = allSections.length * 3; // 每個關卡最多3顆星
        expandedChapters = initialExpandState; // 設置默認展開狀態
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
      body: Column(
        children: [
          // 進度條
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: secondaryColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
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
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$currentProgress / $totalSections 顆星',
                      style: GoogleFonts.notoSans(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                LinearProgressIndicator(
                  value: totalSections > 0 ? currentProgress / totalSections : 0,
                  backgroundColor: Colors.white.withOpacity(0.1),
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
                    padding: EdgeInsets.all(16),
                    itemCount: sections.length > 0 ? getUniqueChapters().length : 0,
                    itemBuilder: (context, index) {
                      final chapterName = getUniqueChapters()[index];
                      final isExpanded = expandedChapters[chapterName] ?? false;
                      
                      // 獲取當前章節的年級和冊數
                      final currentYearGrade = _getChapterYearGrade(chapterName);
                      final currentBook = _getChapterBook(chapterName);
                      
                      // 判斷是否需要顯示年級和冊數
                      // 如果是第一個章節，或者年級/冊數與前一個章節不同，則顯示
                      bool shouldShowGradeAndBook = true;
                      if (index > 0) {
                        final prevChapterName = getUniqueChapters()[index - 1];
                        final prevYearGrade = _getChapterYearGrade(prevChapterName);
                        final prevBook = _getChapterBook(prevChapterName);
                        
                        // 如果年級和冊數都相同，則不顯示
                        if (currentYearGrade == prevYearGrade && currentBook == prevBook) {
                          shouldShowGradeAndBook = false;
                        }
                      }
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 如果需要顯示年級和冊數，則顯示一個標題
                          if (shouldShowGradeAndBook && currentYearGrade.isNotEmpty && currentBook.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(left: 8, bottom: 8, top: index > 0 ? 16 : 0),
                              child: Text(
                                '$currentYearGrade年級 $currentBook',
                                style: GoogleFonts.notoSans(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          
                          // 章節卡片
                          Card(
                            margin: EdgeInsets.only(bottom: 16),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            color: cardColor,
                            child: Column(
                              children: [
                                // 章節標題
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      expandedChapters[chapterName] = !isExpanded;
                                    });
                                  },
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isExpanded ? Icons.expand_less : Icons.expand_more,
                                          color: Colors.white,
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
                                    child: Column(
                                      children: sections
                                          .where((section) => section['chapter_name'] == chapterName)
                                          .map((section) => Container(
                                            margin: EdgeInsets.only(
                                              left: 16,
                                              right: 16,
                                              bottom: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color: secondaryColor,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: ListTile(
                                              contentPadding: EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 8,
                                              ),
                                              title: Text(
                                                section['level_name'],
                                                style: GoogleFonts.notoSans(
                                                  color: Colors.white,
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
                                                      color: Colors.white70,
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
                                                        // 獲取該關卡的星星數
                                                        int stars = 0;
                                                        if (!isLoadingStars) {
                                                          // 使用 level_id 查找星星數
                                                          String levelId = section['level_id'].toString();
                                                          
                                                          // 直接使用 level_id 查找星星數
                                                          stars = levelStars[levelId] ?? 0;
                                                        }
                                                        
                                                        return Icon(
                                                          i < stars ? Icons.star : Icons.star_border,
                                                          color: Colors.amber,
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
                                              onTap: () {
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
                                                  // 當用戶從 QuizPage 返回時，重新加載星星數
                                                  _loadUserLevelStars();
                                                });
                                              },
                                            ),
                                          ))
                                          .toList(),
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
    );
  }
}