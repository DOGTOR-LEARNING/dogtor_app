import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';

class QuizPage extends StatefulWidget {
  final String section;
  final Map<String, dynamic> knowledgePoints;
  final String sectionSummary;

  QuizPage({
    required this.section,
    required this.knowledgePoints,
    required this.sectionSummary,
  });

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
  
  // 添加動畫控制器
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
    
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

  Future<void> _fetchQuestions() async {
    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/generate_questions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'section': widget.section,
          'knowledge_points': widget.knowledgePoints,
          'section_summary': widget.sectionSummary,
        }),
      );

      if (response.statusCode == 200) {
        final cleanResponse = response.body
            .replaceAll('"', '')
            .replaceAll('\\n', '\n')
            .trim();
        
        final rows = cleanResponse.split('\n');
        
        final List<Map<String, dynamic>> parsedQuestions = [];
        for (var row in rows) {
          if (row.trim().isEmpty) continue;
          
          final cols = row.split(',');
          if (cols.length >= 7) {
            try {
              parsedQuestions.add({
                'knowledge_point': utf8.decode(cols[0].codeUnits),
                'question': utf8.decode(cols[1].codeUnits),
                'correct_answer': utf8.decode(cols[2].codeUnits),
                'options': [
                  utf8.decode(cols[3].codeUnits),
                  utf8.decode(cols[4].codeUnits),
                  utf8.decode(cols[5].codeUnits),
                  utf8.decode(cols[6].codeUnits),
                ],
              });
            } catch (e) {
              print('Error parsing row: $e');
            }
          }
        }

        setState(() {
          questions = parsedQuestions;
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
    } catch (e) {
      print('Error in _checkAnswer: $e');
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
                  _fetchQuestions();
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