import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class BattleQuizPage extends StatefulWidget {
  final String battleId;
  final String opponentName;
  final String? opponentPhotoUrl;
  final String chapter;
  final String subject;

  const BattleQuizPage({
    super.key,
    required this.battleId,
    required this.opponentName,
    this.opponentPhotoUrl,
    required this.chapter,
    required this.subject,
  });

  @override
  _BattleQuizPageState createState() => _BattleQuizPageState();
}

class _BattleQuizPageState extends State<BattleQuizPage>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> questions = [];
  int currentQuestionIndex = 0;
  bool isLoading = true;
  String? selectedAnswer;
  bool? isCorrect;

  // 對戰相關狀態
  int playerScore = 0;
  int opponentScore = 0;
  List<bool> playerAnswers = [];
  List<bool> opponentAnswers = [];

  // 計時器相關
  late Timer _questionTimer;
  int timeLeft = 15; // 每題15秒
  bool timeUp = false;

  // 動畫控制器
  late AnimationController _timerController;
  late AnimationController _scoreController;
  late Animation<double> _timerAnimation;
  late Animation<double> _scoreAnimation;

  // 對戰狀態
  bool battleFinished = false;
  bool waitingForOpponent = false;
  String battleStatus = "準備中...";

  // 顏色定義
  final Color primaryColor = Colors.white;
  final Color backgroundColor = Color(0xFF1E3A8A); // 深藍色背景
  final Color accentColor = Color(0xFFEF9F29); // 橙色
  final Color playerColor = Color(0xFF10B981); // 綠色
  final Color opponentColor = Color(0xFFEF4444); // 紅色
  final Color correctColor = Color(0xFF4ADE80);
  final Color incorrectColor = Color(0xFFF87171);

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _fetchBattleQuestions();
  }

  void _initializeAnimations() {
    _timerController = AnimationController(
      duration: Duration(seconds: 15),
      vsync: this,
    );

    _scoreController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );

    _timerAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _timerController,
      curve: Curves.linear,
    ));

    _scoreAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scoreController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _questionTimer.cancel();
    _timerController.dispose();
    _scoreController.dispose();
    super.dispose();
  }

  Future<void> _fetchBattleQuestions() async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://superb-backend-1041765261654.asia-east1.run.app/battle/questions/${widget.battleId}'),
        headers: {'Accept': 'application/json; charset=utf-8'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['success']) {
          setState(() {
            questions = List<Map<String, dynamic>>.from(data['questions']);
            isLoading = false;
            battleStatus = "對戰開始！";
          });

          // 添加短暫延遲讓用戶準備
          await Future.delayed(Duration(seconds: 2));
          _startQuestion();
        } else {
          _showError('載入題目失敗：${data['message']}');
        }
      } else {
        _showError('伺服器錯誤：${response.statusCode}');
      }
    } catch (e) {
      print('獲取對戰題目錯誤: $e');
      _showError('網路錯誤，請檢查連線');
    }
  }

  void _showError(String message) {
    setState(() {
      isLoading = false;
      battleStatus = message;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: incorrectColor,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _startQuestion() {
    if (currentQuestionIndex >= questions.length) {
      _finishBattle();
      return;
    }

    setState(() {
      selectedAnswer = null;
      isCorrect = null;
      timeLeft = 15;
      timeUp = false;
      battleStatus = "第 ${currentQuestionIndex + 1} 題";
    });

    // 重置並啟動計時器動畫
    _timerController.reset();
    _timerController.forward();

    // 啟動倒數計時器
    _questionTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        timeLeft--;
      });

      if (timeLeft <= 0) {
        timer.cancel();
        _timeUp();
      }
    });
  }

  void _timeUp() {
    if (!mounted) return;

    setState(() {
      timeUp = true;
      battleStatus = "時間到！";
    });

    // 如果時間到還沒選答案，自動提交空答案
    if (selectedAnswer == null) {
      _submitAnswer('');
    }
  }

  void _selectAnswer(String answer) {
    if (timeUp || selectedAnswer != null) return;

    setState(() {
      selectedAnswer = answer;
      battleStatus = "已選擇答案";
    });

    // 延遲提交，讓用戶看到選擇效果
    Future.delayed(Duration(milliseconds: 800), () {
      if (mounted) {
        _submitAnswer(answer);
      }
    });
  }

  Future<void> _submitAnswer(String answer) async {
    if (!mounted) return;

    _questionTimer.cancel();
    _timerController.stop();

    setState(() {
      battleStatus = "提交中...";
    });

    try {
      final currentQuestion = questions[currentQuestionIndex];
      final userId = await _getUserId();

      if (userId == null) {
        _showError('用戶未登入');
        return;
      }

      final response = await http.post(
        Uri.parse(
            'https://superb-backend-1041765261654.asia-east1.run.app/battle/submit_answer'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: json.encode({
          'battle_id': widget.battleId,
          'user_id': userId,
          'question_id': currentQuestion['id'],
          'question_order': currentQuestionIndex,
          'user_answer': answer,
          'answer_time': 15 - timeLeft,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['success']) {
          setState(() {
            isCorrect = data['is_correct'];
            battleStatus = isCorrect! ? "答對了！+${data['score'] ?? 10}" : "答錯了！";
          });

          _updateScores(data);

          // 觸發分數動畫
          _scoreController.forward().then((_) {
            _scoreController.reset();
          });

          // 等待一下再進入下一題
          await Future.delayed(Duration(seconds: 2));
          if (mounted) {
            setState(() {
              currentQuestionIndex++;
            });
            _startQuestion();
          }
        } else {
          _showError('提交答案失敗：${data['message']}');
        }
      } else {
        _showError('伺服器錯誤');
      }
    } catch (e) {
      print('提交答案錯誤: $e');
      _showError('網路錯誤');
    }
  }

  void _updateScores(Map<String, dynamic> data) {
    setState(() {
      playerScore = data['player_score'] ?? playerScore;
      opponentScore = data['opponent_score'] ?? opponentScore;

      // 更新答題記錄
      if (playerAnswers.length <= currentQuestionIndex) {
        playerAnswers.add(isCorrect!);
      }

      // 模擬對手答題（實際應從後端獲取）
      if (opponentAnswers.length <= currentQuestionIndex) {
        opponentAnswers.add(data['opponent_correct'] ?? false);
      }
    });
  }

  Future<void> _finishBattle() async {
    setState(() {
      battleFinished = true;
      battleStatus = "對戰結束！";
    });

    try {
      final response = await http.get(
        Uri.parse(
            'https://superb-backend-1041765261654.asia-east1.run.app/battle/result/${widget.battleId}'),
        headers: {'Accept': 'application/json; charset=utf-8'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['success']) {
          _showResultDialog(data);
        }
      }
    } catch (e) {
      print('獲取對戰結果錯誤: $e');
    }
  }

  void _showResultDialog(Map<String, dynamic> result) {
    final isWinner = result['winner'] == 'player';
    final isDraw = result['winner'] == 'draw';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: primaryColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Center(
          child: Column(
            children: [
              Icon(
                isDraw
                    ? Icons.handshake
                    : (isWinner
                        ? Icons.emoji_events
                        : Icons.sentiment_dissatisfied),
                color: isDraw
                    ? accentColor
                    : (isWinner ? correctColor : incorrectColor),
                size: 64,
              ),
              SizedBox(height: 16),
              Text(
                isDraw ? '平手！' : (isWinner ? '🎉 你贏了！' : '😔 你輸了'),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDraw
                      ? accentColor
                      : (isWinner ? correctColor : incorrectColor),
                ),
              ),
            ],
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 分數對比
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      Text('你',
                          style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text('$playerScore',
                          style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: playerColor)),
                      Text('分',
                          style:
                              TextStyle(fontSize: 14, color: Colors.grey[600])),
                    ],
                  ),
                  Container(
                    width: 2,
                    height: 60,
                    color: Colors.grey[300],
                  ),
                  Column(
                    children: [
                      Text(widget.opponentName,
                          style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text('$opponentScore',
                          style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: opponentColor)),
                      Text('分',
                          style:
                              TextStyle(fontSize: 14, color: Colors.grey[600])),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),

            // 詳細統計
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('答對題數：', style: TextStyle(fontSize: 16)),
                      Text(
                          '${playerAnswers.where((a) => a).length}/${playerAnswers.length}',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('正確率：', style: TextStyle(fontSize: 16)),
                      Text(
                          '${(playerAnswers.where((a) => a).length / playerAnswers.length * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: correctColor)),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('科目章節：', style: TextStyle(fontSize: 16)),
                      Expanded(
                        child: Text('${widget.subject} - ${widget.chapter}',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.right),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // 關閉對話框
                    Navigator.of(context).pop(); // 返回好友頁面
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text('返回',
                      style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // 關閉對話框
                    Navigator.of(context).pop(); // 返回準備頁面
                    // 可以在這裡添加再戰一局的邏輯
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text('再戰一局',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<String?> _getUserId() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getString('user_id');
    } catch (e) {
      print("獲取用戶 ID 時出錯: $e");
      return null;
    }
  }

  Widget _buildPlayerAvatar(
      String name, String? photoUrl, Color color, bool isPlayer) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 3),
          ),
          child: CircleAvatar(
            radius: 25,
            backgroundColor: color,
            backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                ? NetworkImage(photoUrl)
                : null,
            child: photoUrl == null || photoUrl.isEmpty
                ? Text(
                    name[0].toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
        ),
        SizedBox(height: 8),
        Text(
          isPlayer ? '你' : name,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildScoreDisplay(int score, Color color) {
    return ScaleTransition(
      scale: _scoreAnimation,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '$score',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Row(
      children: List.generate(questions.length, (index) {
        Color dotColor = Colors.white.withOpacity(0.3);

        if (index < currentQuestionIndex) {
          // 已完成的題目
          if (index < playerAnswers.length) {
            dotColor = playerAnswers[index] ? correctColor : incorrectColor;
          }
        } else if (index == currentQuestionIndex) {
          // 當前題目
          dotColor = accentColor;
        }

        return Container(
          margin: EdgeInsets.symmetric(horizontal: 2),
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return WillPopScope(
        onWillPop: () async => false, // 載入時不允許返回
        child: Scaffold(
          backgroundColor: backgroundColor,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: accentColor),
                SizedBox(height: 16),
                Text(
                  '準備對戰中...',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                SizedBox(height: 8),
                Text(
                  '正在載入題目',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.7), fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (questions.isEmpty) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: incorrectColor, size: 64),
              SizedBox(height: 16),
              Text(
                '無法載入對戰題目',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: accentColor),
                child: Text('返回'),
              ),
            ],
          ),
        ),
      );
    }

    final currentQuestion = questions[currentQuestionIndex];

    return WillPopScope(
      onWillPop: () async {
        if (battleFinished) return true;

        // 顯示退出確認對話框
        return await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('確認離開'),
                content: Text('對戰進行中，確定要離開嗎？離開將視為放棄對戰。'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text('取消'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text('離開', style: TextStyle(color: incorrectColor)),
                  ),
                ],
              ),
            ) ??
            false;
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              // 頂部對戰資訊
              Container(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    // 玩家資訊和分數
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildPlayerAvatar('你', null, playerColor, true),
                        Column(
                          children: [
                            Row(
                              children: [
                                _buildScoreDisplay(playerScore, playerColor),
                                SizedBox(width: 16),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Text(
                                    'VS',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 16),
                                _buildScoreDisplay(
                                    opponentScore, opponentColor),
                              ],
                            ),
                            SizedBox(height: 12),
                            _buildProgressIndicator(),
                            SizedBox(height: 8),
                            Text(
                              '${widget.subject} - ${widget.chapter}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        _buildPlayerAvatar(widget.opponentName,
                            widget.opponentPhotoUrl, opponentColor, false),
                      ],
                    ),
                    SizedBox(height: 16),

                    // 計時器
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: AnimatedBuilder(
                            animation: _timerAnimation,
                            builder: (context, child) {
                              return CircularProgressIndicator(
                                value: _timerAnimation.value,
                                strokeWidth: 6,
                                backgroundColor: Colors.white.withOpacity(0.3),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  timeLeft <= 5 ? incorrectColor : accentColor,
                                ),
                              );
                            },
                          ),
                        ),
                        Text(
                          '$timeLeft',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      battleStatus,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // 題目區域
              Expanded(
                child: Container(
                  margin: EdgeInsets.all(16),
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 題目編號
                      Text(
                        '第 ${currentQuestionIndex + 1} 題',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 16),

                      // 題目內容
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              MarkdownBody(
                                data: currentQuestion['question'] ?? '',
                                styleSheet: MarkdownStyleSheet(
                                  p: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                              SizedBox(height: 24),

                              // 選項
                              Column(
                                children: (currentQuestion['options'] as List)
                                    .asMap()
                                    .entries
                                    .map<Widget>((entry) {
                                  final index = entry.key;
                                  final option = entry.value;
                                  final isSelected = selectedAnswer == option;

                                  Color optionColor = Colors.grey[100]!;
                                  Color textColor = Colors.black;
                                  IconData? icon;

                                  if (selectedAnswer != null) {
                                    final correctAnswerIndex = int.tryParse(
                                            currentQuestion[
                                                'correct_answer']) ??
                                        0;
                                    final isCorrectOption =
                                        index == correctAnswerIndex;

                                    if (isCorrectOption) {
                                      optionColor =
                                          correctColor.withOpacity(0.2);
                                      textColor = correctColor;
                                      icon = Icons.check_circle;
                                    } else if (isSelected) {
                                      optionColor =
                                          incorrectColor.withOpacity(0.2);
                                      textColor = incorrectColor;
                                      icon = Icons.cancel;
                                    }
                                  } else if (isSelected) {
                                    optionColor = accentColor.withOpacity(0.2);
                                    textColor = accentColor;
                                  }

                                  return Padding(
                                    padding: EdgeInsets.only(bottom: 12),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () => _selectAnswer(option),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          padding: EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: optionColor,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color: isSelected
                                                  ? accentColor
                                                  : Colors.transparent,
                                              width: 2,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 24,
                                                height: 24,
                                                decoration: BoxDecoration(
                                                  color: textColor,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    String.fromCharCode(65 +
                                                        index), // A, B, C, D
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  option,
                                                  style: TextStyle(
                                                    color: textColor,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                              if (icon != null)
                                                Icon(icon,
                                                    color: textColor, size: 24),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
