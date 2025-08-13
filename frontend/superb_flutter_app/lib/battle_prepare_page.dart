import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'battle_quiz_page.dart'; // 導入對戰頁面

class BattlePreparePage extends StatefulWidget {
  final String opponentId;
  final String opponentName;
  final String? opponentPhotoUrl;

  const BattlePreparePage({
    super.key,
    required this.opponentId,
    required this.opponentName,
    this.opponentPhotoUrl,
  });

  @override
  _BattlePreparePageState createState() => _BattlePreparePageState();
}

class _BattlePreparePageState extends State<BattlePreparePage> {
  // 主題顏色
  final Color primaryBlue = Color(0xFF319cb6);
  final Color accentOrange = Color(0xFFf59b03);
  final Color backgroundWhite = Color(0xFFFFF9F7);
  final Color textBlue = Color(0xFF0777B1);
  final Color cardBlue = Color(0xFFECF6F9);

  List<String> subjects = [];
  Map<String, List<String>> chaptersBySubject = {};
  String? selectedSubject;
  String? selectedChapter;
  bool isLoading = true;
  bool isStartingBattle = false;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://superb-backend-1041765261654.asia-east1.run.app/quiz/subjects'),
        headers: {'Accept': 'application/json; charset=utf-8'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['success']) {
          setState(() {
            subjects = List<String>.from(data['subjects']);
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print('載入科目錯誤: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadChapters(String subject) async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://superb-backend-1041765261654.asia-east1.run.app/quiz/chapters/$subject'),
        headers: {'Accept': 'application/json; charset=utf-8'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['success']) {
          setState(() {
            chaptersBySubject[subject] = List<String>.from(data['chapters']);
            selectedChapter = null; // 重置章節選擇
          });
        }
      }
    } catch (e) {
      print('載入章節錯誤: $e');
    }
  }

  Future<void> _selectRandomChapter() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse(
            'https://superb-backend-1041765261654.asia-east1.run.app/quiz/random_chapter${selectedSubject != null ? '?subject=$selectedSubject' : ''}'),
        headers: {'Accept': 'application/json; charset=utf-8'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['success']) {
          setState(() {
            selectedSubject = data['subject'];
            selectedChapter = data['chapter'];
          });

          // 確保章節列表已載入
          if (!chaptersBySubject.containsKey(selectedSubject)) {
            await _loadChapters(selectedSubject!);
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.casino, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('隨機選擇：${data['subject']} - ${data['chapter']}'),
                  ),
                ],
              ),
              backgroundColor: primaryBlue,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        } else {
          _showError('隨機選擇失敗：${data['message']}');
        }
      } else {
        _showError('伺服器錯誤');
      }
    } catch (e) {
      print('隨機選擇章節錯誤: $e');
      _showError('網路錯誤');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _startBattle() async {
    if (selectedSubject == null || selectedChapter == null) {
      _showError('請先選擇科目和章節');
      return;
    }

    setState(() {
      isStartingBattle = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      if (userId == null) {
        throw Exception('未找到用戶ID，請重新登入');
      }

      final response = await http.post(
        Uri.parse(
            'https://superb-backend-1041765261654.asia-east1.run.app/battle/start'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'challenger_id': userId,
          'opponent_id': widget.opponentId,
          'chapter': selectedChapter,
          'subject': selectedSubject,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['success']) {
          // 顯示成功訊息
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('對戰房間建立成功！'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
            ),
          );

          // 短暫延遲後跳轉
          await Future.delayed(Duration(milliseconds: 1500));

          // 跳轉到對戰頁面
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => BattleQuizPage(
                battleId: data['battle_id'],
                opponentName: widget.opponentName,
                opponentPhotoUrl: widget.opponentPhotoUrl,
                chapter: selectedChapter!,
                subject: selectedSubject!,
              ),
            ),
          );
        } else {
          throw Exception(data['message'] ?? '發起對戰失敗');
        }
      } else {
        throw Exception('伺服器錯誤 (${response.statusCode})');
      }
    } catch (e) {
      print('發起對戰錯誤: $e');
      _showError('發起對戰失敗：${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) {
        setState(() {
          isStartingBattle = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundWhite,
      appBar: AppBar(
        title: Text(
          '對戰準備',
          style: TextStyle(
            color: textBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: backgroundWhite,
        elevation: 0,
        iconTheme: IconThemeData(color: textBlue),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryBlue))
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 對手信息卡片
                  _buildOpponentCard(),
                  SizedBox(height: 24),

                  // 科目選擇
                  _buildSectionTitle('選擇科目'),
                  SizedBox(height: 12),
                  _buildSubjectSelection(),
                  SizedBox(height: 24),

                  // 章節選擇
                  if (selectedSubject != null) ...[
                    _buildSectionTitle('選擇章節'),
                    SizedBox(height: 12),
                    _buildChapterSelection(),
                    SizedBox(height: 16),
                    _buildRandomButton(),
                    SizedBox(height: 24),
                  ],

                  // 當前選擇顯示
                  _buildCurrentSelection(),
                  SizedBox(height: 32),

                  // 發起對戰按鈕
                  _buildStartBattleButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildOpponentCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBlue,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            '對戰對手',
            style: TextStyle(
              fontSize: 16,
              color: textBlue.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundImage: widget.opponentPhotoUrl != null
                    ? NetworkImage(widget.opponentPhotoUrl!)
                    : null,
                backgroundColor: primaryBlue.withOpacity(0.2),
                child: widget.opponentPhotoUrl == null
                    ? Icon(Icons.person, color: primaryBlue, size: 30)
                    : null,
              ),
              SizedBox(width: 16),
              Text(
                widget.opponentName,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textBlue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: textBlue,
      ),
    );
  }

  Widget _buildSubjectSelection() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: subjects.map((subject) {
        final isSelected = selectedSubject == subject;
        return GestureDetector(
          onTap: () {
            setState(() {
              selectedSubject = subject;
              selectedChapter = null;
            });
            _loadChapters(subject);
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? primaryBlue : Colors.white,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: isSelected ? primaryBlue : Colors.grey.shade300,
                width: 2,
              ),
            ),
            child: Text(
              subject,
              style: TextStyle(
                color: isSelected ? Colors.white : textBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildChapterSelection() {
    final chapters = chaptersBySubject[selectedSubject!] ?? [];

    if (chapters.isEmpty) {
      return Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text(
              '載入章節中...',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return Container(
      constraints: BoxConstraints(maxHeight: 200),
      child: SingleChildScrollView(
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: chapters.map((chapter) {
            final isSelected = selectedChapter == chapter;
            return GestureDetector(
              onTap: () {
                setState(() {
                  selectedChapter = chapter;
                });
              },
              child: AnimatedContainer(
                duration: Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? accentOrange : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? accentOrange : Colors.grey.shade300,
                    width: 2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: accentOrange.withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Text(
                  chapter,
                  style: TextStyle(
                    color: isSelected ? Colors.white : textBlue,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildRandomButton() {
    return Center(
      child: ElevatedButton.icon(
        onPressed: _selectRandomChapter,
        icon: Icon(Icons.shuffle, color: Colors.white),
        label: Text(
          '隨機選擇',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: accentOrange,
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentSelection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '當前選擇',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textBlue,
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.book, color: primaryBlue, size: 20),
              SizedBox(width: 8),
              Text(
                '科目：${selectedSubject ?? "尚未選擇"}',
                style: TextStyle(
                  fontSize: 14,
                  color: textBlue.withOpacity(0.8),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.menu_book, color: accentOrange, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '章節：${selectedChapter ?? "尚未選擇章節"}',
                  style: TextStyle(
                    fontSize: 14,
                    color: textBlue.withOpacity(0.8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStartBattleButton() {
    final canStart = selectedSubject != null && selectedChapter != null;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: canStart && !isStartingBattle ? _startBattle : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: canStart ? primaryBlue : Colors.grey.shade400,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: canStart ? 4 : 0,
        ),
        child: isStartingBattle
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    '發起對戰中...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.sports_esports,
                    color: Colors.white,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Text(
                    '發起對戰',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
