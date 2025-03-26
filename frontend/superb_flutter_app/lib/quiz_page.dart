import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert' show utf8;
import 'dart:convert' show latin1;
import 'package:shared_preferences/shared_preferences.dart';

class QuizPage extends StatefulWidget {
  final String chapter;
  final String section;
  final String knowledgePoints;
  final String levelNum;
  
  const QuizPage({
    Key? key,
    required this.chapter,
    required this.section,
    required this.knowledgePoints,
    required this.levelNum,
  }) : super(key: key);

  @override
  _QuizPageState createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> questions = [];
  int currentQuestionIndex = 0;
  bool isLoading = true;
  String? selectedAnswer;
  bool? isCorrect;
  int correctAnswersCount = 0;
  int? levelId; // 添加關卡 ID 變數
  
  // 添加動畫控制器
  late AnimationController _animationController;
  late Animation<double> _animation;

  // 添加一個控制器來獲取用戶輸入的錯誤訊息
  final TextEditingController _errorController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchLevelId();
    _fetchQuestionsFromDatabase();
    
    // 初始化動畫控制器
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchLevelId() async {
    try {
      print("正在獲取關卡 ID...");
      print("章節名稱: ${widget.chapter}");
      print("小節名稱: ${widget.section}");
      print("知識點: ${widget.knowledgePoints}");
      print("關卡編號: ${widget.levelNum}");
      
      final response = await http.post(
        Uri.parse('https://superb-backend-1041765261654.asia-east1.run.app/get_level_id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chapter': widget.chapter,
          'section': widget.section,
          'knowledge_points': widget.knowledgePoints,
          'level_num': widget.levelNum,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("API 響應: $data");
        
        if (data['success']) {
          setState(() {
            levelId = data['level_id'];
          });
          print('獲取關卡 ID 成功: $levelId');
        } else {
          print('獲取關卡 ID 失敗: ${data['message']}');
        }
      } else {
        print('獲取關卡 ID 失敗，狀態碼: ${response.statusCode}');
      }
    } catch (e) {
      print('獲取關卡 ID 時出錯: $e');
      print(e.toString());
    }
  }

  Future<void> _fetchQuestionsFromDatabase() async {
    try {
      // 知識點已經是字符串形式，格式為 "知識點1、知識點2、知識點3"
      final String knowledgePointsStr = widget.knowledgePoints;
      
      print("知識點字符串: $knowledgePointsStr");
      print("小節摘要: ${widget.section}");
      print("關卡名稱: ${widget.section}");
      
      // 檢查是否有知識點
      if (knowledgePointsStr.isEmpty) {
        print("錯誤: 沒有提供知識點");
        setState(() {
          isLoading = false;
        });
        return;
      }
      
      // 從數據庫獲取題目
      final response = await http.post(
        Uri.parse('https://superb-backend-1041765261654.asia-east1.run.app/get_questions_by_level'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json; charset=utf-8'
        },
        body: jsonEncode({
          'chapter': '',  // 不使用章節過濾
          'section': widget.section,  // 使用小節名稱
          'knowledge_points': knowledgePointsStr,  // 使用知識點字符串
        }),
      );

      print('發送請求到: https://superb-backend-1041765261654.asia-east1.run.app/get_questions_by_level');
      print('請求數據: ${jsonEncode({
        'chapter': '',
        'section': widget.section,
        'knowledge_points': knowledgePointsStr,
      })}');

      if (response.statusCode == 200) {
        // 嘗試使用 UTF-8 解碼
        final String responseBody = utf8.decode(response.bodyBytes);
        final data = jsonDecode(responseBody);
        print('響應數據: $data');
        
        if (data['success']) {
          final List<dynamic> questionsData = data['questions'];
          
          final List<Map<String, dynamic>> parsedQuestions = questionsData.map((q) {
            // 嘗試修復亂碼
            String fixEncoding(String text) {
              try {
                // 嘗試多種編碼修復方法
                return utf8.decode(latin1.encode(text));
              } catch (e) {
                return text;
              }
            }
            
            return {
              'knowledge_point': fixEncoding(q['knowledge_point'] ?? ''),
              'question': fixEncoding(q['question_text'] ?? ''),
              'correct_answer': q['correct_answer'],
              'options': [
                fixEncoding(q['option_1'] ?? ''),
                fixEncoding(q['option_2'] ?? ''),
                fixEncoding(q['option_3'] ?? ''),
                fixEncoding(q['option_4'] ?? ''),
              ],
              'explanation': fixEncoding(q['explanation'] ?? ''),
              'question_id': q['id'],
            };
          }).toList();
          
          setState(() {
            questions = parsedQuestions;
            isLoading = false;
          });
        } else {
          print('Error: ${data['message']}');
          setState(() {
            isLoading = false;
          });
        }
      } else {
        print('Error: ${response.statusCode}');
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching questions: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _checkAnswer() {
    final currentQuestion = questions[currentQuestionIndex];
    try {
      final correctAnswerString = currentQuestion['correct_answer'].trim();
      final correctAnswerIndex = int.parse(correctAnswerString) - 1;
      final correctAnswer = currentQuestion['options'][correctAnswerIndex];
      
      final bool answerIsCorrect = selectedAnswer == correctAnswer;
      
      setState(() {
        isCorrect = answerIsCorrect;
        
        if (answerIsCorrect) {
          correctAnswersCount++;
        }
      });
      
      // 記錄用戶答題情況
      _recordUserAnswer(currentQuestion['question_id'], answerIsCorrect);
    } catch (e) {
      print('Error in _checkAnswer: $e');
    }
  }

  // 記錄用戶答題情況
  Future<void> _recordUserAnswer(int questionId, bool isCorrect) async {
    try {
      // 如果用戶已登入，則記錄答題情況
      // 這裡需要根據你的用戶系統進行調整
      final userId = await _getUserId();
      if (userId != null) {
        await http.post(
          Uri.parse('https://superb-backend-1041765261654.asia-east1.run.app/record_answer'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_id': userId,
            'question_id': questionId,
            'is_correct': isCorrect,
          }),
        );
      }
    } catch (e) {
      print('Error recording answer: $e');
    }
  }

  // 獲取用戶 ID 的方法
  Future<String?> _getUserId() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('user_id');
      if (userId != null && userId.isNotEmpty) {
        return userId; // 直接返回字串
      }
      return null;
    } catch (e) {
      print("獲取用戶 ID 時出錯: $e");
      return null;
    }
  }

  void _nextQuestion() {
    if (currentQuestionIndex < questions.length - 1) {
      // 重置動畫
      _animationController.reset();
      
      setState(() {
        currentQuestionIndex++;
        selectedAnswer = null;
        isCorrect = null;
      });
      
      // 播放進入動畫
      _animationController.forward();
    }
  }

  void _showResultDialog() {
    final percentage = (correctAnswersCount / questions.length * 100).round();
    String resultMessage;
    Color resultColor;
    IconData resultIcon;
    
    if (percentage >= 90) {
      resultMessage = "太棒了！你對這個部分掌握得非常好！";
      resultColor = Color(0xFF4ADE80);
      resultIcon = Icons.emoji_events;
    } else if (percentage >= 70) {
      resultMessage = "做得好！還有一點小細節需要復習。";
      resultColor = Color(0xFF38BDF8);
      resultIcon = Icons.thumb_up;
    } else if (percentage >= 50) {
      resultMessage = "繼續加油！可以再多複習幾遍。";
      resultColor = Color(0xFFFACC15);
      resultIcon = Icons.history_edu;
    } else {
      resultMessage = "這部分需要更多練習，別灰心！";
      resultColor = Color(0xFFF87171);
      resultIcon = Icons.replay;
    }
    
    // 先寫入答題記錄
    _completeLevel().then((_) {
      // 然後顯示結果對話框
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  resultIcon,
                  size: 60,
                  color: resultColor,
                ),
                SizedBox(height: 16),
                Text(
                  "測驗結果",
                  style: GoogleFonts.notoSans(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: resultColor.withOpacity(0.2),
                    border: Border.all(
                      color: resultColor,
                      width: 3,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      "$percentage%",
                      style: GoogleFonts.notoSans(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: resultColor,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  "答對 $correctAnswersCount/${questions.length} 題",
                  style: GoogleFonts.notoSans(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  resultMessage,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSans(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        "返回課程",
                        style: GoogleFonts.notoSans(),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        // 重置測驗
                        setState(() {
                          currentQuestionIndex = 0;
                          selectedAnswer = null;
                          isCorrect = null;
                          correctAnswersCount = 0;
                          _animationController.reset();
                          _animationController.forward();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: resultColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        "重新測驗",
                        style: GoogleFonts.notoSans(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }).catchError((error) {
      print('Error saving level completion: $error');
      // 即使保存失敗，仍然顯示結果對話框
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  resultIcon,
                  size: 60,
                  color: resultColor,
                ),
                SizedBox(height: 16),
                Text(
                  "測驗結果",
                  style: GoogleFonts.notoSans(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: resultColor.withOpacity(0.2),
                    border: Border.all(
                      color: resultColor,
                      width: 3,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      "$percentage%",
                      style: GoogleFonts.notoSans(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: resultColor,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  "答對 $correctAnswersCount/${questions.length} 題",
                  style: GoogleFonts.notoSans(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  resultMessage,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSans(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        "返回課程",
                        style: GoogleFonts.notoSans(),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        // 重置測驗
                        setState(() {
                          currentQuestionIndex = 0;
                          selectedAnswer = null;
                          isCorrect = null;
                          correctAnswersCount = 0;
                          _animationController.reset();
                          _animationController.forward();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: resultColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        "重新測驗",
                        style: GoogleFonts.notoSans(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  // 顯示報告錯誤的對話框
  void _showReportErrorDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('回報題目問題'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('請描述題目的問題：'),
              SizedBox(height: 10),
              TextField(
                controller: _errorController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: '例如：選項不清楚、題目有錯字等',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _errorController.clear();
              },
              child: Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_errorController.text.trim().isNotEmpty) {
                  _reportQuestionError();
                  Navigator.pop(context);
                }
              },
              child: Text('送出'),
            ),
          ],
        );
      },
    );
  }
  
  // 發送錯誤報告到後端
  Future<void> _reportQuestionError() async {
    try {
      final currentQuestion = questions[currentQuestionIndex];
      final questionId = currentQuestion['question_id'];
      final errorMessage = _errorController.text.trim();
      
      final response = await http.post(
        Uri.parse('https://superb-backend-1041765261654.asia-east1.run.app/report_question_error'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({
          'question_id': questionId,
          'error_message': errorMessage,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('感謝您的回報！我們會盡快處理。')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('回報失敗：${data['message']}')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('回報失敗，請稍後再試。')),
        );
      }
      
      _errorController.clear();
    } catch (e) {
      print('Error reporting question: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('回報時發生錯誤，請稍後再試。')),
      );
    }
  }

  // 在用戶完成所有題目後調用
  Future<void> _completeLevel() async {
    try {
      // 獲取用戶 ID
      String? userId = await _getUserId();
      if (userId == null) {
        print('無法保存關卡記錄: 用戶未登入');
        return;
      }
      
      if (levelId == null) {
        print('無法保存關卡記錄: 關卡 ID 未知');
        return;
      }
      
      // 準備請求數據
      final response = await http.post(
        Uri.parse('https://superb-backend-1041765261654.asia-east1.run.app/complete_level'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,  // 使用字串形式的用戶 ID
          'level_id': levelId,
          'correct_count': correctAnswersCount,
          'total_questions': questions.length
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (!data['success']) {
          print('保存關卡記錄失敗：${data['message']}');
        }
      } else {
        print('保存關卡記錄失敗，狀態碼：${response.statusCode}');
      }
    } catch (e) {
      print('Error completing level: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Color(0xFF1E293B),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Color(0xFF38BDF8),
                strokeWidth: 3,
              ),
              SizedBox(height: 24),
              Text(
                '載入題目中...',
                style: GoogleFonts.notoSans(
                  fontSize: 18,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (questions.isEmpty) {
      return Scaffold(
        backgroundColor: Color(0xFF1E293B),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
              SizedBox(height: 16),
              Text(
                '無法載入題目',
                style: GoogleFonts.notoSans(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    isLoading = true;
                  });
                  _fetchQuestionsFromDatabase();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF38BDF8),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text('重試'),
              ),
            ],
          ),
        ),
      );
    }

    final currentQuestion = questions[currentQuestionIndex];
    final progressPercentage = (currentQuestionIndex + 1) / questions.length;

    return Scaffold(
      backgroundColor: Color(0xFF1E293B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_ios_new, color: Colors.white),
        ),
        title: Text(
          widget.section,
          style: GoogleFonts.notoSans(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 進度條
            Container(
              margin: EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '題目 ${currentQuestionIndex + 1}/${questions.length}',
                        style: GoogleFonts.notoSans(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Color(0xFF4ADE80),
                            size: 18,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '$correctAnswersCount 答對',
                            style: GoogleFonts.notoSans(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progressPercentage,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: FadeTransition(
                opacity: _animation,
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 知識點標籤
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Color(0xFF38BDF8).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Color(0xFF38BDF8).withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          currentQuestion['knowledge_point'],
                          style: GoogleFonts.notoSans(
                            color: Color(0xFF38BDF8),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      
                      // 題目文字
                      Text(
                        currentQuestion['question'],
                        style: GoogleFonts.notoSans(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: 24),
                      
                      // 選項
                      ...currentQuestion['options'].asMap().entries.map((entry) {
                        final index = entry.key;
                        final option = entry.value;
                        final isSelected = selectedAnswer == option;
                        final correctAnswerIndex = isCorrect != null 
                            ? int.parse(currentQuestion['correct_answer']) - 1 
                            : -1;
                        final isCorrectAnswer = isCorrect != null && index == correctAnswerIndex;
                        
                        // 確定選項顏色和圖標
                        Color optionColor = Colors.white.withOpacity(0.1);
                        IconData? trailingIcon;
                        Color? iconColor;
                        
                        if (isCorrect != null) {
                          if (index == correctAnswerIndex) {
                            optionColor = Color(0xFF4ADE80).withOpacity(0.2);
                            trailingIcon = Icons.check_circle;
                            iconColor = Color(0xFF4ADE80);
                          } else if (isSelected) {
                            optionColor = Color(0xFFF87171).withOpacity(0.2);
                            trailingIcon = Icons.cancel;
                            iconColor = Color(0xFFF87171);
                          }
                        } else if (isSelected) {
                          optionColor = Color(0xFF38BDF8).withOpacity(0.2);
                        }
                        
                        return Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: isCorrect == null ? () {
                                setState(() {
                                  selectedAnswer = option;
                                });
                              } : null,
                              borderRadius: BorderRadius.circular(12),
                              splashColor: Colors.white.withOpacity(0.1),
                              child: Ink(
                                decoration: BoxDecoration(
                                  color: optionColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected 
                                        ? (isCorrect == null 
                                            ? Color(0xFF38BDF8) 
                                            : (isCorrect! 
                                                ? Color(0xFF4ADE80) 
                                                : Color(0xFFF87171)))
                                        : (isCorrectAnswer 
                                            ? Color(0xFF4ADE80) 
                                            : Colors.white.withOpacity(0.2)),
                                    width: 1.5,
                                  ),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      // 選項字母
                                      Container(
                                        width: 32,
                                        height: 32,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: isSelected 
                                              ? (isCorrect == null 
                                                  ? Color(0xFF38BDF8) 
                                                  : (isCorrect! 
                                                      ? Color(0xFF4ADE80) 
                                                      : Color(0xFFF87171)))
                                              : (isCorrectAnswer 
                                                  ? Color(0xFF4ADE80) 
                                                  : Colors.white.withOpacity(0.1)),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          String.fromCharCode(65 + index as int),
                                          style: GoogleFonts.notoSans(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      
                                      // 選項文字
                                      Expanded(
                                        child: Text(
                                          option,
                                          style: GoogleFonts.notoSans(
                                            color: Colors.white,
                                            fontSize: 16,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                      
                                      // 結果圖標
                                      if (trailingIcon != null)
                                        Icon(
                                          trailingIcon,
                                          color: iconColor,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            ),
            
            // 底部按鈕
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(0xFF0F172A),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (selectedAnswer != null && isCorrect == null)
                    // 送出答案按鈕
                    ElevatedButton(
                      onPressed: _checkAnswer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF4ADE80),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 20),
                          SizedBox(width: 8),
                          Text(
                            '送出答案',
                            style: GoogleFonts.notoSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                  if (isCorrect != null && currentQuestionIndex < questions.length - 1)
                    // 下一題按鈕
                    ElevatedButton(
                      onPressed: _nextQuestion,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF38BDF8),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '下一題',
                            style: GoogleFonts.notoSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 20),
                        ],
                      ),
                    ),
                    
                  if (isCorrect != null && currentQuestionIndex == questions.length - 1)
                    // 完成測驗按鈕
                    ElevatedButton(
                      onPressed: _showResultDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFF59E0B),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.emoji_events, size: 20),
                          SizedBox(width: 8),
                          Text(
                            '查看結果',
                            style: GoogleFonts.notoSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}