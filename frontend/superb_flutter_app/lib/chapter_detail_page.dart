import 'package:flutter/material.dart';
import 'quiz_page.dart';

class ChapterDetailPage extends StatefulWidget {
  final String subject;
  final String csvPath;

  ChapterDetailPage({required this.subject, required this.csvPath});

  @override
  _ChapterDetailPageState createState() => _ChapterDetailPageState();
}

class _ChapterDetailPageState extends State<ChapterDetailPage> {
  // 儲存所有章節資料的列表
  List<Map<String, dynamic>> sections = [];
  // 當前章節名稱
  String currentChapter = '';
  // 目前完成的進度
  int currentProgress = 0;
  // 總章節數量
  int totalSections = 0;
  // 課程適用年級
  String yearGrade = '';
  // 教材冊別
  String book = '';

  // 定義主題色彩
  final Color primaryColor = Color(0xFF0A1D3A);  // 深藍色主題
  final Color secondaryColor = Color(0xFF1E3A5F);
  final Color accentColor = Color(0xFF4D90FE);    // 亮藍色強調色

  @override
  void initState() {
    super.initState();
    _loadChapterData();
  }

  Future<void> _loadChapterData() async {
    try {
      // 從資源檔案中載入 CSV 資料
      final String data = await DefaultAssetBundle.of(context).loadString(widget.csvPath);
      final List<String> rows = data.split('\n');
      
      // 從第一行資料中取得年級和冊別資訊
      if (rows.length > 1) {
        final firstRow = rows[1].split(',');
        yearGrade = firstRow[1];  // 年級
        book = firstRow[2];      // 冊別
      }

      // 跳過標題行
      final List<Map<String, dynamic>> allSections = rows.skip(1)
          .where((row) => row.trim().isNotEmpty)
          .map((row) {
            final cols = row.split(',');
            return {
              'chapter_num': cols[3],    // 章節編號
              'chapter_name': cols[4],   // 章節名稱
              'section_num': cols[5],    // 小節編號
              'section_name': cols[6],   // 小節名稱
              'knowledge_spots': cols[7], // 知識點列表
              'section_summary': cols[8], // 課綱內容摘要
              'stars': 0,                // 學習進度星星數（預設為0）
            };
          }).toList();

      setState(() {
        sections = allSections;
        totalSections = allSections.length;
        currentProgress = 2; // 示例進度
      });
    } catch (e) {
      print('載入章節資料時發生錯誤: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
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
          // 顯示年級和冊別資訊
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
                  '課綱推薦年級：$yearGrade 年級 $book',
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
                    Text(
                      '學習進度',
                      style: TextStyle(color: Colors.white70),
                    ),
                    SizedBox(width: 8),
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
                    backgroundColor: accentColor, // 修正: 將 primary 改為 backgroundColor
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
                    itemCount: sections.length,
                    itemBuilder: (context, index) {
                      final section = sections[index];
                      // 判斷是否為新章節的開始
                      final isNewChapter = index == 0 || 
                          sections[index]['chapter_name'] != sections[index - 1]['chapter_name'];
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isNewChapter)
                            Container(
                              margin: EdgeInsets.only(top: index > 0 ? 24 : 8, bottom: 8, left: 16, right: 16),
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
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: accentColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      section['chapter_num'],
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      section['chapter_name'],
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Container(
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
                                  section['section_num'],
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                section['section_name'],
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
                                // 從 knowledge_spots 欄位獲取知識點列表
                                final knowledgeSpots = section['knowledge_spots'].toString().split('、');
                                
                                // 為每個知識點設定預設分數（5分）
                                final Map<String, dynamic> knowledgePoints = Map.fromIterable(
                                  knowledgeSpots,
                                  key: (spot) => spot,
                                  value: (_) => 5
                                );

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => QuizPage(
                                      section: section['section_name'],
                                      knowledgePoints: knowledgePoints,
                                      sectionSummary: section['section_summary'],  // 添加課綱內容
                                    ),
                                  ),
                                );
                              },
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