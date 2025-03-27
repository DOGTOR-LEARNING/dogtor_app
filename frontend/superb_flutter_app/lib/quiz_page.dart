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

  // 修改 _errorController 的聲明，移除 final 關鍵字
  TextEditingController _errorController = TextEditingController();

  // 修改 UI 風格，使其與 chat_page_s.dart 一致

  // 1. 更新顏色方案
  final Color primaryColor = Color(0xFF0F172A);  // 深藍色主題
  final Color secondaryColor = Color(0xFF1E293B); // 次要背景色
  final Color accentColor = Color(0xFF38BDF8);    // 亮藍色強調色
  final Color cardColor = Color(0xFF334155);      // 卡片背景色

  @override
  void initState() {
    super.initState();
    // 不再需要從 API 獲取 level_id，直接使用傳入的值
    _initializeLevelId();
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

  // 初始化 level_id
  void _initializeLevelId() {
    try {
      // 嘗試將傳入的 level_id 轉換為整數
      if (widget.levelNum.isNotEmpty) {
        levelId = int.tryParse(widget.levelNum);
        // print('使用 CSV 中的 level_id: $levelId');
      }
    } catch (e) {
      print('初始化 level_id 時出錯: $e');
    }
  }

  Future<void> _fetchQuestionsFromDatabase() async {
    try {
      // 知識點已經是字符串形式，格式為 "知識點1、知識點2、知識點3"
      final String knowledgePointsStr = widget.knowledgePoints;
      
      // print("知識點字符串: $knowledgePointsStr");
      // print("小節摘要: ${widget.section}");
      // print("關卡名稱: ${widget.section}");
      
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

      // print('發送請求到: https://superb-backend-1041765261654.asia-east1.run.app/get_questions_by_level');
      // print('請求數據: ${jsonEncode({
      //   'chapter': '',
      //   'section': widget.section,
      //   'knowledge_points': knowledgePointsStr,
      // })}');

      if (response.statusCode == 200) {
        // 嘗試使用 UTF-8 解碼
        final String responseBody = utf8.decode(response.bodyBytes);
        final data = jsonDecode(responseBody);
        // print('響應數據: $data');
        
        if (data['success']) {
          final List<dynamic> questionsData = data['questions'];
          
          // 檢查並處理每個題目
          List<Map<String, dynamic>> processedQuestions = [];
          for (var q in questionsData) {
            // 確保每個題目都有 id 字段
            if (q['id'] != null) {
              // 確保 correct_answer 是字符串類型
              var correctAnswer = q['correct_answer'];
              if (correctAnswer != null) {
                // 如果是數字，轉換為字符串
                if (correctAnswer is int) {
                  q['correct_answer'] = correctAnswer.toString();
                } else if (correctAnswer is String) {
                  // 如果是字符串，確保是數字格式（1-4）
                  if (!RegExp(r'^[1-4]$').hasMatch(correctAnswer)) {
                    print("警告: 題目 ${q['id']} 的正確答案格式不正確: $correctAnswer");
                  }
                }
              } else {
                print("警告: 題目 ${q['id']} 沒有正確答案");
                continue; // 跳過沒有正確答案的題目
              }
              
              // 構建選項列表
              List<dynamic> options = [];
              
              // 檢查是否有 options 字段
              if (q['options'] != null && q['options'] is List) {
                options = q['options'];
              } 
              // 如果沒有 options 字段，嘗試從 option_1, option_2 等字段構建
              else {
                // 確保所有選項字段都存在
                if (q['option_1'] != null && q['option_2'] != null) {
                  options = [
                    q['option_1'],
                    q['option_2'],
                    q['option_3'] ?? '',
                    q['option_4'] ?? '',
                  ];
                }
              }
              
              // 如果選項列表為空，跳過這個題目
              if (options.isEmpty) {
                print("警告: 題目 ${q['id']} 沒有選項，跳過");
                continue;
              }
              
              processedQuestions.add({
                'id': q['id'],
                'question': q['question_text'] ?? '',
                'options': options,
                'correct_answer': q['correct_answer'].toString(), // 確保是字符串
                'explanation': q['explanation'] ?? '',
                'knowledge_point': widget.knowledgePoints.split('、')[0], // 使用第一個知識點作為顯示
              });
              
              // 打印處理後的題目，以便調試
              // print("處理後的題目: ${processedQuestions.last}");
            } else {
              print("警告: 發現沒有 ID 的題目: $q");
            }
          }
          
          setState(() {
            questions = processedQuestions;
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

  // 在用戶回答問題後調用
  void _handleAnswer(String selectedOption) {
    if (isCorrect != null) return; // 如果已經提交過答案，則不再處理

    setState(() {
      selectedAnswer = selectedOption;
      
      // 獲取當前題目
      final currentQuestion = questions[currentQuestionIndex];
      
      // 獲取選中選項在列表中的位置（從0開始）
      final selectedIndex = currentQuestion['options'].indexOf(selectedOption);
      
      // 獲取資料庫中的正確答案（已經是0-based索引）
      final correctAnswerStr = currentQuestion['correct_answer'];
      final correctAnswerIndex = int.tryParse(correctAnswerStr) ?? 0;
      
      // 直接比較索引，因為API已經將答案轉換為0-based索引
      isCorrect = selectedIndex == correctAnswerIndex;
      
      // 如果答對了，增加正確答案計數
      if (isCorrect!) {
        correctAnswersCount++;
      }
      
      // 調試信息
      print('題目: ${currentQuestion['question']}');
      print('選項列表: ${currentQuestion['options']}');
      print('選中選項: $selectedOption (索引: $selectedIndex)');
      print('資料庫中的正確答案: $correctAnswerStr (已是0-based索引)');
      print('判斷結果: $isCorrect');
    });
    
    // 記錄答題情況
    _recordUserAnswer(questions[currentQuestionIndex]['id'], isCorrect!);
  }

  // 記錄用戶答題情況
  Future<void> _recordUserAnswer(int questionId, bool isCorrect) async {
    try {
      // 如果用戶已登入，則記錄答題情況
      final userId = await _getUserId();
      if (userId != null) {
        // 發送請求到後端 API 記錄答題情況
        final response = await http.post(
          Uri.parse('https://superb-backend-1041765261654.asia-east1.run.app/record_answer'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_id': userId,
            'question_id': questionId,
            'is_correct': isCorrect,
          }),
        );
        
        // 檢查響應
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (!data['success']) {
            print('記錄答題情況失敗：${data['message']}');
          }
        } else {
          print('記錄答題情況失敗，狀態碼：${response.statusCode}');
        }
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
  void _showReportErrorDialog(int? questionId) {
    print("開始顯示錯誤回報對話框，題目ID: $questionId");
    
    // 如果 questionId 為 null，使用一個默認值或顯示錯誤信息
    if (questionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('無法識別題目 ID，請稍後再試。'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) {
        print("構建錯誤回報對話框");
        return AlertDialog(
          backgroundColor: secondaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.report_problem_outlined,
                color: Colors.amber,
                size: 24,
              ),
              SizedBox(width: 10),
              Text(
                '回報題目錯誤',
                style: GoogleFonts.notoSans(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '請描述題目的錯誤之處：',
                  style: GoogleFonts.notoSans(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: _errorController,
                    maxLines: 4,
                    style: GoogleFonts.notoSans(
                      color: Colors.white,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: '例如：選項有誤、答案不正確、題目敘述不清...',
                      hintStyle: GoogleFonts.notoSans(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 14,
                      ),
                      contentPadding: EdgeInsets.all(16),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white.withOpacity(0.7),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                '取消',
                style: GoogleFonts.notoSans(
                  fontSize: 15,
                ),
              ),
              onPressed: () {
                print("取消錯誤回報");
                Navigator.of(context).pop();
                _errorController.clear();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: Text(
                '送出回報',
                style: GoogleFonts.notoSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              onPressed: () {
                print("送出錯誤回報");
                if (_errorController.text.trim().isNotEmpty) {
                  print("回報內容: ${_errorController.text.trim()}");
                  _reportQuestionError(questionId, _errorController.text.trim());
                  Navigator.of(context).pop();
                  
                  // 顯示成功提示
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.white),
                          SizedBox(width: 10),
                          Text('回報成功，感謝您的反饋！'),
                        ],
                      ),
                      backgroundColor: Color(0xFF4ADE80),
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      margin: EdgeInsets.all(10),
                    ),
                  );
                  
                  _errorController.clear();
                }
              },
            ),
          ],
          actionsPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        );
      },
    );
  }
  
  // 發送錯誤報告到後端
  Future<void> _reportQuestionError(int? questionId, String errorMessage) async {
    if (questionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('無法識別題目 ID，請稍後再試。'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    try {
      final response = await http.post(
        Uri.parse('https://superb-backend-1041765261654.asia-east1.run.app/report_question_error'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'question_id': questionId,
          'error_message': errorMessage,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('感謝您的回報！我們會盡快處理。'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('回報失敗：${data['message']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('回報失敗，請稍後再試。'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('回報題目錯誤時出錯: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('回報失敗，請檢查網絡連接。'),
          backgroundColor: Colors.red,
        ),
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

    // 獲取當前題目的選項
    List<dynamic> options = currentQuestion['options'] ?? [];
    if (options.isEmpty) {
      // 如果選項為空，顯示錯誤信息
      return Center(
        child: Text(
          '此題目沒有選項',
          style: GoogleFonts.notoSans(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: secondaryColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        title: Text(
          '${widget.section}',
          style: GoogleFonts.notoSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 添加頂部間距
            SizedBox(height: 16),
            
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
                        '問題 ${currentQuestionIndex + 1}/${questions.length}',
                        style: GoogleFonts.notoSans(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      // 添加「題目有誤」按鈕
                      TextButton.icon(
                        icon: Icon(Icons.report_problem_outlined, color: Colors.amber, size: 16),
                        label: Text(
                          '題目有誤',
                          style: GoogleFonts.notoSans(
                            color: Colors.amber,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size(0, 0),
                          backgroundColor: primaryColor.withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () {
                          print("按下題目有誤按鈕");
                          if (questions.isNotEmpty && currentQuestionIndex < questions.length) {
                            // 檢查 id 是否存在
                            final questionId = questions[currentQuestionIndex]['id'];
                            print("當前題目: ${questions[currentQuestionIndex]}");
                            print("顯示錯誤回報對話框，題目ID: $questionId");
                            _showReportErrorDialog(questionId);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('無法識別當前題目，請稍後再試。'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progressPercentage,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                    borderRadius: BorderRadius.circular(10),
                    minHeight: 6,
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
                          color: accentColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: accentColor.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          currentQuestion['knowledge_point'],
                          style: GoogleFonts.notoSans(
                            color: accentColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      
                      // 題目文字 - 使用卡片風格
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          currentQuestion['question'],
                          style: GoogleFonts.notoSans(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
                      
                      // 選項 - 使用更現代的卡片風格
                      Column(
                        children: currentQuestion['options'].asMap().entries.map<Widget>((entry) {
                          final index = entry.key;
                          final option = entry.value;
                          final isSelected = selectedAnswer == option;
                          
                          // 獲取正確答案索引（已經是0-based）
                          final correctAnswerIndex = int.tryParse(currentQuestion['correct_answer']) ?? 0;
                          
                          // 判斷這個選項是否是正確答案
                          final isCorrectOption = index == correctAnswerIndex;
                          
                          Color optionColor = cardColor;
                          IconData? trailingIcon;
                          Color iconColor = Colors.white;
                          
                          if (isCorrect != null) {
                            // 答案已提交
                            if (isCorrectOption) {
                              // 這是正確答案
                              optionColor = Color(0xFF4ADE80).withOpacity(0.2);
                              trailingIcon = Icons.check_circle;
                              iconColor = Color(0xFF4ADE80);
                            } else if (isSelected) {
                              // 這是用戶選擇的錯誤答案
                              optionColor = Color(0xFFF87171).withOpacity(0.2);
                              trailingIcon = Icons.cancel;
                              iconColor = Color(0xFFF87171);
                            }
                          } else if (isSelected) {
                            // 答案未提交，但已選擇
                            optionColor = accentColor.withOpacity(0.2);
                          }
                          
                          return Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: isCorrect != null ? null : () {
                                  _handleAnswer(option);
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: optionColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? accentColor : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          option,
                                          style: GoogleFonts.notoSans(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                      if (trailingIcon != null)
                                        Icon(
                                          trailingIcon,
                                          color: iconColor,
                                          size: 24,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      
                      SizedBox(height: 24),
                      
                      // 確認按鈕
                      if (selectedAnswer != null && isCorrect == null)
                        Container(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              _handleAnswer(selectedAnswer!);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              '確認答案',
                              style: GoogleFonts.notoSans(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      
                      // 解釋
                      if (isCorrect != null)
                        Container(
                          margin: EdgeInsets.only(top: 16),
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isCorrect! ? Color(0xFF4ADE80) : Color(0xFFF87171),
                              width: 2,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isCorrect! ? Icons.check_circle : Icons.cancel,
                                    color: isCorrect! ? Color(0xFF4ADE80) : Color(0xFFF87171),
                                    size: 24,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    isCorrect! ? '答對了！' : '答錯了！',
                                    style: GoogleFonts.notoSans(
                                      color: isCorrect! ? Color(0xFF4ADE80) : Color(0xFFF87171),
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              Text(
                                '解釋：',
                                style: GoogleFonts.notoSans(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                currentQuestion['explanation'] ?? '無解釋',
                                style: GoogleFonts.notoSans(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 16,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      // 下一題按鈕
                      if (isCorrect != null)
                        Container(
                          width: double.infinity,
                          margin: EdgeInsets.only(top: 24),
                          child: ElevatedButton(
                            onPressed: () {
                              if (currentQuestionIndex < questions.length - 1) {
                                setState(() {
                                  currentQuestionIndex++;
                                  selectedAnswer = null;
                                  isCorrect = null;
                                  _animationController.reset();
                                  _animationController.forward();
                                });
                              } else {
                                _completeLevel();
                                _showResultDialog();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              currentQuestionIndex < questions.length - 1 ? '下一題' : '完成測驗',
                              style: GoogleFonts.notoSans(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
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