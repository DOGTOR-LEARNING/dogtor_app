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
  List<Map<String, dynamic>> sections = [];
  String currentChapter = '';
  int currentProgress = 0;
  int totalSections = 0;
  String yearGrade = '';  // 添加年級
  String book = '';      // 添加冊別

  @override
  void initState() {
    super.initState();
    _loadChapterData();
  }

  Future<void> _loadChapterData() async {
    try {
      final String data = await DefaultAssetBundle.of(context).loadString(widget.csvPath);
      final List<String> rows = data.split('\n');
      
      // 跳過標題行，獲取第一行的年級和冊別資訊
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
              'chapter_num': cols[3],
              'chapter_name': cols[4],
              'section_num': cols[5],
              'section_name': cols[6],
              'knowledge_spots': cols[7],
              'section_summary': cols[8],  // 添加課綱內容
              'stars': 0, // 預設星星數
            };
          }).toList();

      setState(() {
        sections = allSections;
        totalSections = allSections.length;
        currentProgress = 2; // 示例進度
      });
    } catch (e) {
      print('Error loading chapter data: $e');
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
          // 添加年級和冊別資訊
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
                          
                          // 創建知識點分數映射，預設分數為 5
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