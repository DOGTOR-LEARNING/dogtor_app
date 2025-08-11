import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert' show utf8;
import 'dart:convert' show latin1;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:flutter_markdown/flutter_markdown.dart';

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

class _QuizPageState extends State<QuizPage>
    with SingleTickerProviderStateMixin {
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

  // 打字機動畫相關
  String _displayedQuestion = "";
  bool _isTyping = false;
  List<bool> _optionVisibility = [false, false, false, false];

  // 光標閃爍相關
  Timer? _cursorTimer;
  bool _showCursor = true;

  // AI 分析相關
  bool _isAnalyzing = false;
  String _aiAnalysis = "";
  List<Map<String, dynamic>> _answerHistory = []; // 記錄答題歷史

  // 修改 UI 風格，使其與 chat_page_s.dart 一致

  // 1. 更新顏色方案
  final Color primaryColor = Colors.white;
  final Color secondaryColor = const Color.fromARGB(255, 239, 239, 239);
  final Color accentColor = Color.fromARGB(255, 238, 159, 41); // 橙色強調色，類似小島的顏色
  final Color cardColor = Colors.white; // 白色卡片背景色

  // 添加一個新的狀態變量來跟踪結果計算過程
  bool isCalculatingResult = false;

  bool isExplanationVisible =
      false; // Add this line to track explanation visibility

  TextStyle _textStyle({
    Color color = Colors.black,
    double fontSize = 14.0,
    FontWeight fontWeight = FontWeight.normal,
  }) {
    return TextStyle(
      fontFamily: 'Medium',
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
    );
  }

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
    _cursorTimer?.cancel();
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
        Uri.parse(
            'https://superb-backend-1041765261654.asia-east1.run.app/quiz/questions'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json; charset=utf-8'
        },
        body: jsonEncode({
          'chapter': widget.chapter, // 傳遞章節名稱，用於章節總複習
          'section': widget.section, // 使用小節名稱
          'knowledge_points': knowledgePointsStr, // 使用知識點字符串
          'user_id': await _getUserId(), // 添加用戶ID
          'level_id': widget.levelNum, // 添加關卡ID
        }),
      );

      // print('發送請求到: https://superb-backend-1041765261654.asia-east1.run.app/quiz/questions');
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

              // 獲取該題目的知識點
              String knowledgePoint = "";

              // 嘗試從後端獲取知識點信息
              if (q['knowledge_point'] != null) {
                knowledgePoint = q['knowledge_point'];
              } else {
                // 如果後端沒有提供知識點信息，則查詢數據庫
                try {
                  final knowledgeResponse = await http.get(
                    Uri.parse(
                        'https://superb-backend-1041765261654.asia-east1.run.app/get_question_knowledge_point/${q['id']}'),
                  );

                  if (knowledgeResponse.statusCode == 200) {
                    final knowledgeData =
                        jsonDecode(utf8.decode(knowledgeResponse.bodyBytes));
                    if (knowledgeData['success'] &&
                        knowledgeData['knowledge_point'] != null) {
                      knowledgePoint = knowledgeData['knowledge_point'];
                    }
                  }
                } catch (e) {
                  print("獲取題目知識點時出錯: $e");
                }
              }

              // 如果仍然沒有獲取到知識點，使用傳入的知識點列表中的第一個
              if (knowledgePoint.isEmpty) {
                knowledgePoint = widget.knowledgePoints.split('、')[0];
              }

              processedQuestions.add({
                'id': q['id'],
                'question': q['question_text'] ?? '',
                'options': options,
                'correct_answer': q['correct_answer'].toString(), // 確保是字符串
                'explanation': q['explanation'] ?? '',
                'knowledge_point': q['knowledge_point'] ??
                    widget.knowledgePoints
                        .split('、')[0], // 使用API返回的知識點，如果沒有則使用默認值
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

          // 載入完成後啟動第一題的打字機動畫
          if (processedQuestions.isNotEmpty) {
            Future.delayed(Duration(milliseconds: 500), () {
              _startTypingAnimation();
            });
          }
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
      print('選擇的答案: $selectedAnswer');
    });
  }

  // Add new method to handle answer confirmation
  void _confirmAnswer() {
    if (selectedAnswer == null) return;

    setState(() {
      // 獲取當前題目
      final currentQuestion = questions[currentQuestionIndex];

      // 獲取選中選項在列表中的位置（從0開始）
      final selectedIndex = currentQuestion['options'].indexOf(selectedAnswer);

      // 獲取資料庫中的正確答案（已經是0-based索引）
      final correctAnswerStr = currentQuestion['correct_answer'];
      final correctAnswerIndex = int.tryParse(correctAnswerStr) ?? 0;

      // 直接比較索引，因為API已經將答案轉換為0-based索引
      isCorrect = selectedIndex == correctAnswerIndex;

      // 如果答對了，增加正確答案計數
      if (isCorrect!) {
        correctAnswersCount++;
      }

      // 記錄答題歷史，用於 AI 分析
      _answerHistory.add({
        'question_id': currentQuestion['id'],
        'question_text': currentQuestion['question'],
        'knowledge_point': currentQuestion['knowledge_point'],
        'selected_option': selectedAnswer,
        'correct_option': currentQuestion['options'][correctAnswerIndex],
        'is_correct': isCorrect!,
        'explanation': currentQuestion['explanation'],
      });
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
          Uri.parse(
              'https://superb-backend-1041765261654.asia-east1.run.app/quiz/record_answer'),
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

  // 打字機動畫實現
  Future<void> _startTypingAnimation() async {
    if (questions.isEmpty || currentQuestionIndex >= questions.length) return;

    setState(() {
      _isTyping = true;
      _displayedQuestion = "";
      _optionVisibility = [false, false, false, false];
    });

    // 開始光標閃爍
    _startCursorBlinking();

    final fullQuestion = questions[currentQuestionIndex]['question'] as String;

    // 打字機效果 - 一個字一個字顯示
    for (int i = 0; i <= fullQuestion.length; i++) {
      if (!mounted) return;

      setState(() {
        _displayedQuestion = fullQuestion.substring(0, i);
      });

      // 調整打字速度，中文字符稍慢一些
      await Future.delayed(Duration(milliseconds: 50));
    }

    setState(() {
      _isTyping = false;
      _showCursor = false;
    });

    // 停止光標閃爍
    _cursorTimer?.cancel();

    // 題目打完後，選項依次浮現
    await _showOptionsSequentially();
  }

  // 光標閃爍動畫
  void _startCursorBlinking() {
    _cursorTimer?.cancel();
    _cursorTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
      if (!_isTyping) {
        timer.cancel();
        return;
      }
      if (mounted) {
        setState(() {
          _showCursor = !_showCursor;
        });
      }
    });
  }

  // 選項依次浮現動畫
  Future<void> _showOptionsSequentially() async {
    final options = questions[currentQuestionIndex]['options'] as List<dynamic>;

    for (int i = 0; i < options.length && i < 4; i++) {
      if (!mounted) return;

      setState(() {
        _optionVisibility[i] = true;
      });

      // 每個選項間隔 200ms 出現
      await Future.delayed(Duration(milliseconds: 200));
    }
  }

  // 下一題時重新開始動畫
  void _nextQuestion() {
    setState(() {
      currentQuestionIndex++;
      selectedAnswer = null;
      isCorrect = null;
      isExplanationVisible = false;
    });

    // 啟動新題目的打字機動畫
    _startTypingAnimation();
  }

  // AI 分析答題結果
  Future<void> _analyzeAnswersWithAI() async {
    try {
      final userId = await _getUserId();
      if (userId == null) {
        _aiAnalysis = "無法進行個人化分析，請登入後再試。";
        return;
      }

      final response = await http.post(
        Uri.parse(
            'https://superb-backend-1041765261654.asia-east1.run.app/ai/analyze_quiz_performance'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'answer_history': _answerHistory,
          'subject': widget.chapter,
          'knowledge_points': widget.knowledgePoints,
          'correct_count': correctAnswersCount,
          'total_count': questions.length,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success']) {
          _aiAnalysis = data['analysis'] ?? "分析完成，但暫無具體建議。";
        } else {
          _aiAnalysis = "分析失敗：${data['message']}";
        }
      } else {
        _aiAnalysis = "分析服務暫時無法使用。";
      }
    } catch (e) {
      print('AI 分析錯誤: $e');
      _aiAnalysis = "分析過程中發生錯誤。";
    }
  }

  void _showResultDialog() {
    // 設置計算結果狀態為 true
    setState(() {
      isCalculatingResult = true;
    });

    // 先進行 AI 分析，再記錄關卡完成情況
    _performAnalysisAndComplete();
  }

  Future<void> _performAnalysisAndComplete() async {
    // 開始 AI 分析
    setState(() {
      _isAnalyzing = true;
    });

    try {
      await _analyzeAnswersWithAI();
    } catch (e) {
      print('AI 分析失敗: $e');
      _aiAnalysis = "分析系統暫時無法使用，但你已經完成了測驗！";
    }

    // AI 分析完成後，記錄關卡完成情況（包含 AI comment）
    try {
      await _completeLevel();
    } catch (e) {
      print('記錄關卡完成失敗: $e');
    }

    // 計算完成後，重置狀態
    setState(() {
      isCalculatingResult = false;
      _isAnalyzing = false;
    });

    final percentage = (correctAnswersCount / questions.length * 100).round();
    String resultMessage;
    Color resultColor;
    IconData resultIcon;

    if (percentage >= 90) {
      resultMessage = "太棒了！你對這個部分掌握得非常好！";
      resultColor = Color(0xFF4ADE80);
      resultIcon = Icons.sentiment_very_satisfied;
    } else if (percentage >= 70) {
      resultMessage = "做得好！你已經掌握了大部分內容。";
      resultColor = Color(0xFF4ADE80);
      resultIcon = Icons.sentiment_satisfied;
    } else if (percentage >= 50) {
      resultMessage = "繼續努力！你已經理解了一半的內容。";
      resultColor = accentColor;
      resultIcon = Icons.sentiment_neutral;
    } else {
      resultMessage = "需要更多練習，不要氣餒！";
      resultColor = Color(0xFFF87171);
      resultIcon = Icons.sentiment_dissatisfied;
    }

    // 顯示結果對話框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: secondaryColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Center(
          child: Text(
            '測驗結果',
            style: _textStyle(
                color: const Color.fromARGB(255, 28, 49, 88),
                fontSize: 22,
                fontWeight: FontWeight.bold),
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                resultIcon,
                color: resultColor,
                size: 64,
              ),
              SizedBox(height: 16),
              Text(
                '$percentage% 正確率',
                style: _textStyle(
                    color: resultColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                '${correctAnswersCount}/${questions.length} 題答對',
                style: _textStyle(
                    color: const Color.fromARGB(255, 28, 49, 88), fontSize: 16),
              ),
              SizedBox(height: 16),
              Text(
                resultMessage,
                textAlign: TextAlign.center,
                style: _textStyle(
                    color: const Color.fromARGB(255, 19, 31, 54), fontSize: 16),
              ),
              if (_aiAnalysis.isNotEmpty) ...[
                SizedBox(height: 20),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.psychology, color: Colors.blue, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'AI 學習分析',
                            style: _textStyle(
                                color: Colors.blue,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        _aiAnalysis,
                        style: _textStyle(
                            color: const Color.fromARGB(255, 28, 49, 88),
                            fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // 關閉對話框
              Navigator.of(context).pop(); // 返回上一頁
            },
            style: TextButton.styleFrom(
              foregroundColor: accentColor,
            ),
            child: Text(
              '返回',
              style: _textStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
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
                color: accentColor,
                size: 24,
              ),
              SizedBox(width: 10),
              Text(
                '回報題目錯誤',
                style: _textStyle(
                    color: const Color.fromARGB(255, 28, 49, 88),
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
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
                  style: _textStyle(
                      color: const Color.fromARGB(255, 131, 141, 159),
                      fontSize: 15),
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
                    style: _textStyle(
                        color: const Color.fromARGB(255, 28, 49, 88),
                        fontSize: 15),
                    decoration: InputDecoration(
                      hintText: '例如：選項有誤、答案不正確、題目敘述不清...',
                      hintStyle: _textStyle(
                          color: const Color.fromARGB(255, 113, 121, 137),
                          fontSize: 14),
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
                style: _textStyle(fontSize: 15),
              ),
              onPressed: () {
                print("取消錯誤回報");
                Navigator.of(context).pop();
                _errorController.clear();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: Text(
                '送出回報',
                style: _textStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                print("送出錯誤回報");
                if (_errorController.text.trim().isNotEmpty) {
                  print("回報內容: ${_errorController.text.trim()}");
                  _reportQuestionError(
                      questionId, _errorController.text.trim());
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
  Future<void> _reportQuestionError(
      int? questionId, String errorMessage) async {
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
        Uri.parse(
            'https://superb-backend-1041765261654.asia-east1.run.app/quiz/report_error'),
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

      print('開始提交關卡完成記錄: user_id=$userId, level_id=$levelId');

      // 準備請求數據
      final requestData = {
        'user_id': userId,
        'level_id': levelId?.toString() ?? '', // 確保 level_id 是字符串類型
        'stars': _calculateStars(
            correctAnswersCount, questions.length), // 根據正確率計算星星數
        'ai_comment': _aiAnalysis,
      };

      print('請求數據: $requestData');

      final response = await http.post(
        Uri.parse(
            'https://superb-backend-1041765261654.asia-east1.run.app/quiz/complete_level'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestData),
      );

      print('收到響應: 狀態碼=${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        print('響應數據: $data');

        if (data['success']) {
          print('關卡完成記錄已保存');
        } else {
          print('保存關卡記錄失敗: ${data['message']}');
        }
      } else {
        print('保存關卡記錄失敗: HTTP ${response.statusCode}');
        print('響應內容: ${response.body}');
      }
    } catch (e) {
      print('Error completing level: $e');
    }
  }

  // 根據正確率計算星星數
  int _calculateStars(int correctCount, int totalQuestions) {
    final percentage = (correctCount / totalQuestions * 100).round();
    if (percentage >= 100) return 3; // 90% 以上獲得 3 星
    if (percentage >= 70) return 2; // 70% 以上獲得 2 星
    if (percentage >= 40) return 1; // 50% 以上獲得 1 星
    return 0; // 50% 以下獲得 0 星
  }

  // Add this method to toggle explanation visibility
  void _toggleExplanation() {
    setState(() {
      isExplanationVisible = !isExplanationVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 底部按鈕邏輯
    Widget bottomButtons = isCalculatingResult
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: accentColor,
                ),
                SizedBox(height: 16),
                Text(
                  "正在分析測驗結果...",
                  style: _textStyle(color: secondaryColor, fontSize: 16),
                ),
              ],
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 如果不是最後一題，顯示下一題按鈕
              if (currentQuestionIndex < questions.length - 1)
                ElevatedButton(
                  onPressed: isCorrect != null ? _nextQuestion : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    '下一題',
                    style:
                        _textStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                )
              else if (isCorrect != null)
                ElevatedButton(
                  onPressed: _showResultDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    '完成測驗',
                    style:
                        _textStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),

              // 顯示題目進度
              Text(
                '${currentQuestionIndex + 1}/${questions.length}',
                style: _textStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
            ],
          );

    // 修改 Scaffold 以處理不同的狀態
    return Scaffold(
      backgroundColor: primaryColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        title: Text(
          '${widget.section}',
          style: _textStyle(
              color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: primaryColor,
        ),
        child: SafeArea(
          child: isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: accentColor),
                      SizedBox(height: 16),
                      Text(
                        '載入題目中...',
                        style: _textStyle(color: Colors.black, fontSize: 16),
                      ),
                    ],
                  ),
                )
              : _isAnalyzing
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                CircularProgressIndicator(color: accentColor),
                                SizedBox(height: 16),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.psychology,
                                        color: Colors.blue, size: 24),
                                    SizedBox(width: 8),
                                    Text(
                                      'AI 正在分析你的答題表現...',
                                      style: _textStyle(
                                          color: Colors.black,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '請稍候，這需要幾秒鐘',
                                  style: _textStyle(
                                      color: Colors.grey, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  : questions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: accentColor,
                                size: 64,
                              ),
                              SizedBox(height: 16),
                              Text(
                                '無法載入題目',
                                style: _textStyle(
                                    color: Colors.black,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 8),
                              Text(
                                '請檢查網絡連接或稍後再試',
                                style: _textStyle(
                                    color: Colors.black.withOpacity(0.8),
                                    fontSize: 16),
                              ),
                              SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accentColor,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  '返回上一頁',
                                  style: _textStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
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
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '問題 ${currentQuestionIndex + 1}/${questions.length}',
                                        style: _textStyle(
                                            color: Colors.black,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500),
                                      ),
                                      // 添加「題目有誤」按鈕
                                      TextButton.icon(
                                        icon: Icon(
                                            Icons.report_problem_outlined,
                                            color: accentColor,
                                            size: 16),
                                        label: Text(
                                          '題目有誤',
                                          style: _textStyle(
                                              color: accentColor,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500),
                                        ),
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          minimumSize: Size(0, 0),
                                          backgroundColor:
                                              secondaryColor.withOpacity(0.3),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                        ),
                                        onPressed: () {
                                          print("按下題目有誤按鈕");
                                          if (questions.isNotEmpty &&
                                              currentQuestionIndex <
                                                  questions.length) {
                                            // 檢查 id 是否存在
                                            final questionId =
                                                questions[currentQuestionIndex]
                                                    ['id'];
                                            print(
                                                "當前題目: ${questions[currentQuestionIndex]}");
                                            print(
                                                "顯示錯誤回報對話框，題目ID: $questionId");
                                            _showReportErrorDialog(questionId);
                                          } else {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content:
                                                    Text('無法識別當前題目，請稍後再試。'),
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
                                    value: (currentQuestionIndex + 1) /
                                        questions.length,
                                    backgroundColor:
                                        Colors.white.withOpacity(0.2),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        accentColor),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // 知識點標籤
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: accentColor,
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        child: Text(
                                          questions[currentQuestionIndex]
                                              ['knowledge_point'],
                                          style: _textStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                      SizedBox(height: 16),

                                      // 題目文字 - 使用卡片風格
                                      Container(
                                        width: double.infinity,
                                        padding: EdgeInsets.all(20),
                                        margin:
                                            EdgeInsets.symmetric(horizontal: 4),
                                        decoration: BoxDecoration(
                                          color: cardColor,
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.05),
                                              blurRadius: 8,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  if (_isTyping)
                                                    RichText(
                                                      text: TextSpan(
                                                        children: [
                                                          TextSpan(
                                                            text:
                                                                _displayedQuestion,
                                                            style: _textStyle(
                                                                color: Colors
                                                                    .black,
                                                                fontSize: 18,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600),
                                                          ),
                                                          if (_showCursor)
                                                            TextSpan(
                                                              text: "|",
                                                              style: _textStyle(
                                                                  color:
                                                                      accentColor,
                                                                  fontSize: 18,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600),
                                                            ),
                                                        ],
                                                      ),
                                                    )
                                                  else
                                                    MarkdownBody(
                                                      data: questions[
                                                                  currentQuestionIndex]
                                                              ['question'] ??
                                                          '',
                                                      styleSheet:
                                                          MarkdownStyleSheet(
                                                        p: _textStyle(
                                                            color: Colors.black,
                                                            fontSize: 18,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w600),
                                                        h1: _textStyle(
                                                            color: Colors.black,
                                                            fontSize: 22,
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold),
                                                        h2: _textStyle(
                                                            color: Colors.black,
                                                            fontSize: 20,
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold),
                                                        h3: _textStyle(
                                                            color: Colors.black,
                                                            fontSize: 18,
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold),
                                                        code: _textStyle(
                                                            color: Colors.red,
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w500),
                                                        codeblockDecoration:
                                                            BoxDecoration(
                                                          color:
                                                              Colors.grey[100],
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                        ),
                                                        // 添加表格樣式
                                                        tableHead: _textStyle(
                                                            color: Colors.black,
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold),
                                                        tableBody: _textStyle(
                                                            color: Colors.black,
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight
                                                                    .normal),
                                                        tableBorder:
                                                            TableBorder.all(
                                                                color: const Color
                                                                    .fromARGB(
                                                                    255,
                                                                    37,
                                                                    37,
                                                                    37)!,
                                                                width: 1),
                                                        tableColumnWidth:
                                                            const FlexColumnWidth(
                                                                1.0),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      SizedBox(height: 24),

                                      // 選項 - 使用更現代的卡片風格
                                      Column(
                                        children:
                                            questions[currentQuestionIndex]
                                                    ['options']
                                                .asMap()
                                                .entries
                                                .map<Widget>((entry) {
                                          final index = entry.key;
                                          final option = entry.value;
                                          final isSelected =
                                              selectedAnswer == option;

                                          // 獲取正確答案索引（已經是0-based）
                                          final correctAnswerIndex =
                                              int.tryParse(questions[
                                                          currentQuestionIndex]
                                                      ['correct_answer']) ??
                                                  0;

                                          // 判斷這個選項是否是正確答案
                                          final isCorrectOption =
                                              index == correctAnswerIndex;

                                          Color optionColor =
                                              secondaryColor.withOpacity(0.7);
                                          IconData? trailingIcon;
                                          Color iconColor = Colors.white;

                                          if (isCorrect != null) {
                                            // 答案已提交
                                            if (isCorrectOption) {
                                              // 這是正確答案
                                              optionColor = Color(0xFF4ADE80)
                                                  .withOpacity(0.2);
                                              trailingIcon = Icons.check_circle;
                                              iconColor = Color(0xFF4ADE80);
                                            } else if (isSelected) {
                                              // 這是用戶選擇的錯誤答案
                                              optionColor = Color(0xFFF87171)
                                                  .withOpacity(0.2);
                                              trailingIcon = Icons.cancel;
                                              iconColor = Color(0xFFF87171);
                                            }
                                          } else if (isSelected) {
                                            // 答案未提交，但已選擇
                                            optionColor =
                                                accentColor.withOpacity(0.2);
                                          }

                                          return AnimatedOpacity(
                                            opacity: _optionVisibility[index]
                                                ? 1.0
                                                : 0.0,
                                            duration:
                                                Duration(milliseconds: 300),
                                            child: AnimatedSlide(
                                              offset: _optionVisibility[index]
                                                  ? Offset.zero
                                                  : Offset(0, 0.2),
                                              duration:
                                                  Duration(milliseconds: 300),
                                              child: Padding(
                                                padding:
                                                    EdgeInsets.only(bottom: 12),
                                                child: Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    onTap: isCorrect != null ||
                                                            !_optionVisibility[
                                                                index]
                                                        ? null
                                                        : () {
                                                            _handleAnswer(
                                                                option);
                                                          },
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                    child: Container(
                                                      padding:
                                                          EdgeInsets.all(16),
                                                      decoration: BoxDecoration(
                                                        color: optionColor,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                        border: Border.all(
                                                          color: isSelected
                                                              ? accentColor
                                                              : Colors
                                                                  .transparent,
                                                          width: 2,
                                                        ),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          Expanded(
                                                            child: MarkdownBody(
                                                              data: option,
                                                              styleSheet:
                                                                  MarkdownStyleSheet(
                                                                p: _textStyle(
                                                                    color: Colors
                                                                        .black,
                                                                    fontSize:
                                                                        16,
                                                                    fontWeight: isSelected
                                                                        ? FontWeight
                                                                            .bold
                                                                        : FontWeight
                                                                            .normal),
                                                                code: _textStyle(
                                                                    color: Colors
                                                                        .red,
                                                                    fontSize:
                                                                        14,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500),
                                                                codeblockDecoration:
                                                                    BoxDecoration(
                                                                  color: Colors
                                                                          .grey[
                                                                      100],
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              4),
                                                                ),
                                                                // 添加表格樣式
                                                                tableHead: _textStyle(
                                                                    color: Colors
                                                                        .black,
                                                                    fontSize:
                                                                        14,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold),
                                                                tableBody: _textStyle(
                                                                    color: Colors
                                                                        .black,
                                                                    fontSize:
                                                                        14,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .normal),
                                                                tableBorder: TableBorder.all(
                                                                    color: Colors
                                                                            .grey[
                                                                        400]!,
                                                                    width: 1),
                                                                tableColumnWidth:
                                                                    const FlexColumnWidth(
                                                                        1.0),
                                                              ),
                                                            ),
                                                          ),
                                                          if (trailingIcon !=
                                                              null)
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
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),

                                      SizedBox(height: 24),

                                      // 添加額外的底部間距，為詳解預留空間
                                      if (isCorrect != null &&
                                          isExplanationVisible)
                                        SizedBox(height: 150),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            color: primaryColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: isCorrect == null
                        ? (selectedAnswer != null
                            ? _confirmAnswer
                            : null) // 確認答案
                        : (currentQuestionIndex < questions.length - 1
                            ? _nextQuestion
                            : _showResultDialog), // 下一題或完成測驗
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCorrect == null
                          ? (selectedAnswer != null
                              ? accentColor
                              : Colors.grey) // 未選擇答案時為灰色
                          : accentColor, // 已確認答案時
                      foregroundColor: isCorrect == null
                          ? (selectedAnswer != null
                              ? Colors.white
                              : Colors.grey[600]) // 未選擇答案時文字為深灰色
                          : Colors.white, // 已確認答案時
                      padding:
                          EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      isCorrect == null
                          ? '確認答案' // 未確認答案時
                          : (currentQuestionIndex < questions.length - 1
                              ? '下一題'
                              : '完成測驗'), // 已確認答案時
                      style:
                          _textStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                // Replace question counter with explanation toggle button
                if (isCorrect != null)
                  ElevatedButton(
                    onPressed: _toggleExplanation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isExplanationVisible ? Colors.grey[300] : accentColor,
                      foregroundColor:
                          isExplanationVisible ? Colors.black : Colors.white,
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      isExplanationVisible ? '隱藏詳解' : '查看詳解',
                      style:
                          _textStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
          // Add collapsible explanation section
          if (isCorrect != null && isExplanationVisible)
            Container(
              width: double.infinity,
              constraints: BoxConstraints(
                maxHeight:
                    MediaQuery.of(context).size.height * 0.4, // 限制最大高度為螢幕的40%
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isCorrect! ? Color(0xFF4ADE80) : Color(0xFFF87171),
                    width: 2,
                  ),
                ),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isCorrect! ? Icons.check_circle : Icons.cancel,
                          color: isCorrect!
                              ? Color(0xFF4ADE80)
                              : Color(0xFFF87171),
                          size: 24,
                        ),
                        SizedBox(width: 8),
                        Text(
                          isCorrect! ? '答對了！' : '答錯了！',
                          style: _textStyle(
                              color: isCorrect!
                                  ? Color(0xFF4ADE80)
                                  : Color(0xFFF87171),
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      '解釋：',
                      style: _textStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    MarkdownBody(
                      data: questions[currentQuestionIndex]['explanation'] ??
                          '無解釋',
                      styleSheet: MarkdownStyleSheet(
                        p: _textStyle(
                            color: Colors.black.withOpacity(0.9), fontSize: 16),
                        h1: _textStyle(
                            color: Colors.black,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                        h2: _textStyle(
                            color: Colors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                        h3: _textStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                        code: _textStyle(
                            color: Colors.red,
                            fontSize: 14,
                            fontWeight: FontWeight.w500),
                        codeblockDecoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        blockquote:
                            _textStyle(color: Colors.blue[800]!, fontSize: 16),
                        blockquoteDecoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border(
                            left: BorderSide(color: Colors.blue, width: 4),
                          ),
                        ),
                        // 添加表格樣式
                        tableHead: _textStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                        tableBody: _textStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.normal),
                        tableBorder:
                            TableBorder.all(color: Colors.grey[400]!, width: 1),
                        tableColumnWidth: const FlexColumnWidth(1.0),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // 添加底部導航圖片
          Image.asset(
            'assets/images/quiz-nav.png',
            fit: BoxFit.contain,
            width: double.infinity,
          ),
        ],
      ),
    );
  }
}
