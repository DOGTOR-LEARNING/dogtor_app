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
      backgroundColor: Color(0xFF1B3B4B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${widget.subject} - 章節學習',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          // 顯示年級和冊別資訊
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '課綱推薦年級：$yearGrade 年級 $book',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$currentProgress/$totalSections',
                  style: TextStyle(color: Colors.white),
                ),
                IconButton(
                  icon: Icon(Icons.refresh, color: Colors.white),
                  onPressed: () {},
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
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
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Ch ${section['chapter_num']} - ${section['chapter_name']}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        title: Text(
                          section['section_name'],
                          style: TextStyle(color: Colors.white),
                        ),
                        subtitle: Row(
                          children: List.generate(
                            3,
                            (i) => Icon(
                              i < section['stars'] ? Icons.star : Icons.star_border,
                              color: Colors.yellow,
                              size: 20,
                            ),
                          ),
                        ),
                        trailing: Icon(Icons.play_circle_fill, color: Colors.white),
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