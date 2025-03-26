import 'package:flutter/material.dart';
import 'quiz_page.dart';

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
  
  // 動畫控制器
  late AnimationController _animationController;
  Map<String, Animation<double>> _animations = {};

  // 定義主題色彩
  final Color primaryColor = Color(0xFF0A1D3A);  // 深藍色主題
  final Color secondaryColor = Color(0xFF1E3A5F);
  final Color accentColor = Color(0xFF4D90FE);    // 亮藍色強調色

  @override
  void initState() {
    super.initState();
    _loadChapterData();
    
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
              'level_id': cols[0],       // 關卡編號
              'year_grade': cols[1],     // 年級
              'book': cols[2],           // 冊別
              'chapter_num': cols[3],    // 章節編號
              'chapter_name': cols[4],   // 章節名稱
              'section_num': cols[5],    // 小節編號
              'section_name': cols[6],   // 小節名稱
              'knowledge_spots': cols[7], // 知識點列表
              'level_name': cols[8],     // 關卡名稱
              'stars': 0,                // 學習進度星星數（預設為0）
            };
          })
          .where((item) => item != null)
          .cast<Map<String, dynamic>>()
          .toList();

      setState(() {
        sections = allSections;
        totalSections = allSections.length;
        currentProgress = 2; // 示例進度
      });
    } catch (e) {
      print('載入章節資料時發生錯誤: $e');
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
    });
  }

  @override
  Widget build(BuildContext context) {
    // 按章節分組
    Map<String, List<Map<String, dynamic>>> chapterGroups = {};
    // 追蹤已顯示的年級和冊別組合
    Set<String> displayedGradeBooks = {};
    
    for (var section in sections) {
      final chapterName = section['chapter_name'];
      if (!chapterGroups.containsKey(chapterName)) {
        chapterGroups[chapterName] = [];
        // 預設所有章節為展開狀態
        if (!expandedChapters.containsKey(chapterName)) {
          expandedChapters[chapterName] = true;
        }
      }
      chapterGroups[chapterName]!.add(section);
    }

    return Scaffold(
      backgroundColor: primaryColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${widget.subject} - 章節學習',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.white),
            onPressed: () {
              // 搜尋功能實作
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 顯示整體進度
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: secondaryColor,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '總體學習進度',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 12),
                // 進度條
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: totalSections > 0 ? currentProgress / totalSections : 0,
                          backgroundColor: Colors.white24,
                          valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                          minHeight: 10,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      '$currentProgress/$totalSections',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // 重置按鈕
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  icon: Icon(Icons.refresh, size: 18),
                  label: Text('重置進度'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: () {
                    // 重置進度邏輯
                  },
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
                    itemCount: chapterGroups.length,
                    itemBuilder: (context, index) {
                      final chapterName = chapterGroups.keys.elementAt(index);
                      final chapterSections = chapterGroups[chapterName]!;
                      final firstSection = chapterSections.first;
                      final isExpanded = expandedChapters[chapterName] ?? true;
                      
                      // 確保該章節有動畫
                      if (!_animations.containsKey(chapterName)) {
                        _animations[chapterName] = CurvedAnimation(
                          parent: _animationController,
                          curve: Curves.easeOut,
                        );
                      }
                      
                      // 檢查是否需要顯示年級和冊別
                      final gradeBookKey = '${firstSection['year_grade']}_${firstSection['book']}';
                      final shouldShowGradeBook = !displayedGradeBooks.contains(gradeBookKey);
                      
                      // 如果需要顯示，將其添加到已顯示集合中
                      if (shouldShowGradeBook) {
                        displayedGradeBooks.add(gradeBookKey);
                      }
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 年級和冊別標題 (只在需要時顯示)
                          if (shouldShowGradeBook)
                            Container(
                              margin: EdgeInsets.only(top: 24, bottom: 8, left: 16, right: 16),
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Color(0xFF0D2447),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.book, color: Colors.white70),
                                  SizedBox(width: 12),
                                  Text(
                                    '${firstSection['year_grade']} 年級 ${firstSection['book']}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                          // 章節標題
                          Container(
                            margin: EdgeInsets.only(
                              top: shouldShowGradeBook ? 16 : (index > 0 ? 24 : 8), 
                              bottom: 8, 
                              left: 16, 
                              right: 16
                            ),
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: secondaryColor,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: InkWell(
                              onTap: () => _toggleChapter(chapterName),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: accentColor,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          firstSection['chapter_num'],
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 16),
                                      Expanded(
                                        child: Text(
                                          chapterName,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                        color: Colors.white,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          // 小節列表 (只在展開時顯示)
                          if (isExpanded)
                            Column(
                              children: chapterSections.map((section) => 
                                AnimatedOpacity(
                                  opacity: isExpanded ? 1.0 : 0.0,
                                  duration: Duration(milliseconds: 300),
                                  child: Container(
                                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.1),
                                        width: 1,
                                      ),
                                    ),
                                    child: ListTile(
                                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      leading: CircleAvatar(
                                        backgroundColor: accentColor.withOpacity(0.3),
                                        child: Text(
                                          section['level_id'], // 使用關卡編號
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        section['level_name'], // 使用關卡名稱
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(height: 4),
                                          Text(
                                            '知識點：${section['knowledge_spots']}',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          SizedBox(height: 4),
                                          Row(
                                            children: List.generate(
                                              3,
                                              (i) => Icon(
                                                i < section['stars'] ? Icons.star : Icons.star_border,
                                                color: Colors.amber,
                                                size: 20,
                                              ),
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
                                              chapter: chapterName,  // 使用 chapterName 而不是 section['chapter_name']
                                              section: section['level_name'],
                                              knowledgePoints: section['knowledge_spots'],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                )
                              ).toList(),
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