// 現有代碼...
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert' show utf8;  // 確保導入 utf8
import 'dart:math';  // 添加導入math庫，用於min函數
import 'package:shared_preferences/shared_preferences.dart';

class UserStatsPage extends StatefulWidget {
  const UserStatsPage({Key? key}) : super(key: key);

  @override
  _UserStatsPageState createState() => _UserStatsPageState();
}

class _UserStatsPageState extends State<UserStatsPage> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  String _errorMessage = '';
  late TabController _tabController;
  
  // 更新主題色彩以匹配 chapter_detail_page_n.dart
  final Color primaryColor = Color(0xFF1E5B8C);  // 深藍色主題
  final Color secondaryColor = Color(0xFF2A7AB8); // 較淺的藍色
  final Color accentColor = Color.fromARGB(255, 238, 159, 41);    // 橙色強調色
  final Color cardColor = Color(0xFF3A8BC8);      // 淺藍色卡片背景色

  // 新增知識點分數數據
  List<Map<String, dynamic>> _knowledgeScores = [];
  // 新增學習趨勢數據
  Map<String, List<Map<String, dynamic>>> _weeklyStats = {};
  // 新增弱點知識點
  List<Map<String, dynamic>> _weakPoints = [];
  // 新增學習連續性
  int _streak = 0;
  int _currentStreak = 0;
  int _maxStreak = 0;
  // 新增學習建議
  List<String> _learningTips = [];
  // 新增推薦章節
  List<Map<String, dynamic>> _recommendedChapters = [];
  // 新增科目能力統計
  List<Map<String, dynamic>> _subjectAbilities = [];

  // 新增篩選選項狀態變數
  String? _selectedSubject;
  String? _selectedChapter;
  
  // 是否已點擊學習建議按鈕
  bool _hasClickedLearningTips = false;

  String _nickname = '';
  String _yearGrade = '';
  String _introduction = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabChange);
    
    // 設置加載狀態
    setState(() {
      _isLoading = true;
      // 確保下拉選單狀態初始化為空
      _selectedSubject = null;
      _selectedChapter = null;
    });
    
    // 加載用戶個人資訊
    _loadUserProfile();
    
    // 同時加載所有數據，並在全部完成後更新狀態
    Future.wait([
      _fetchUserStats(),
      _fetchKnowledgeScores(),
      _fetchWeeklyStats(),
      _fetchLearningDays(),
      _fetchSubjectAbilities(),
    ]).then((_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }).catchError((error) {
      print('初始化數據加載時出錯: $error');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  // 處理標籤變更
  void _handleTabChange() {
    // 不自動加載學習建議，等待用戶點擊按鈕
  }
  
  // 學習建議是否已加載標記
  bool _isLearningTipsLoaded = false;
  // 是否正在生成學習建議
  bool _isGeneratingTips = false;
  // 個性化學習建議列表
  List<String> _personalizedTips = [];
  // 個性化學習段落
  Map<String, String> _learningSections = {
    'priority': '優先學習內容還未生成',
    'review': '需要複習的內容還未生成',
    'improve': '可以提升的內容還未生成'
  };

  // 使用Gemini生成學習建議
  Future<void> _generateLearningTipsWithGemini() async {
    if (_isGeneratingTips) return;
    
    setState(() {
      _isGeneratingTips = true;
      print("開始生成學習建議...");
    });
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      // 準備用戶數據提示
      String prompt = _prepareGeminiPrompt();
      
      print("已準備Gemini提示文本: ${prompt.substring(0, min(100, prompt.length))}...");
      
      // 若有暱稱則優先使用暱稱
      String userDisplayName = _nickname.isNotEmpty ? _nickname : (user.displayName ?? '');
      
      // 調用後端API發送給Gemini
      final response = await http.post(
        Uri.parse('https://superb-backend-1041765261654.asia-east1.run.app/generate_learning_suggestions'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json; charset=utf-8',
        },
        body: jsonEncode({
          'user_id': user.uid,
          'prompt': prompt,
          'user_name': userDisplayName,
          'year_grade': _yearGrade,
          'user_introduction': _introduction
        }),
      );
      
      print("API回應狀態碼: ${response.statusCode}");
      
      if (response.statusCode == 200) {
        final jsonString = utf8.decode(response.bodyBytes);
        final data = jsonDecode(jsonString);
        if (data['success']) {
          print("成功獲取個人化學習建議");
          setState(() {
            _personalizedTips = List<String>.from(data['suggestions'] ?? []);
            
            // 也獲取學習段落內容
            if (data.containsKey('sections')) {
              _learningSections = {
                'priority': data['sections']['priority'] ?? '優先學習內容還未生成',
                'review': data['sections']['review'] ?? '需要複習的內容還未生成',
                'improve': data['sections']['improve'] ?? '可以提升的內容還未生成'
              };
            }
            
            _isGeneratingTips = false;
            _isLearningTipsLoaded = true;
          });
        } else {
          print("API回應成功但數據處理失敗: ${data['message']}");
          setState(() {
            _isGeneratingTips = false;
            // 使用默認建議
            _personalizedTips = _learningTips;
          });
        }
      } else {
        print("API調用失敗: ${response.statusCode}");
        setState(() {
          _isGeneratingTips = false;
          // 使用默認建議
          _personalizedTips = _learningTips;
        });
      }
    } catch (e) {
      print('生成學習建議時出錯: $e');
      setState(() {
        _isGeneratingTips = false;
        // 使用默認建議
        _personalizedTips = _learningTips;
      });
    }
  }
  
  // 準備發送給Gemini的提示文本
  String _prepareGeminiPrompt() {
    // 收集用戶數據
    StringBuffer promptBuffer = StringBuffer();
    
    // 添加用戶個人資訊
    final user = FirebaseAuth.instance.currentUser;
    String userName = user?.displayName ?? '';
    
    // 若有暱稱則優先使用暱稱
    String userDisplayName = _nickname.isNotEmpty ? _nickname : userName;
    
    // 添加用戶個人資訊到提示中
    promptBuffer.writeln('用戶個人資訊:');
    if (userDisplayName.isNotEmpty) {
      promptBuffer.writeln('姓名: $userDisplayName');
    }
    if (_yearGrade.isNotEmpty) {
      // 轉換年級顯示格式，例如 G10 轉為 高一
      String gradeDisplay = '';
      if (_yearGrade.startsWith('G')) {
        String gradeNum = _yearGrade.substring(1);
        switch (gradeNum) {
          case '1':
            gradeDisplay = '國小一年級';
            break;
          case '2':
            gradeDisplay = '國小二年級';
            break;
          case '3':
            gradeDisplay = '國小三年級';
            break;
          case '4':
            gradeDisplay = '國小四年級';
            break;
          case '5':
            gradeDisplay = '國小五年級';
            break;
          case '6':
            gradeDisplay = '國小六年級';
            break;
          case '7':
            gradeDisplay = '國一';
            break;
          case '8':
            gradeDisplay = '國二';
            break;
          case '9':
            gradeDisplay = '國三';
            break;
          case '10':
            gradeDisplay = '高一';
            break;
          case '11':
            gradeDisplay = '高二';
            break;
          case '12':
            gradeDisplay = '高三';
            break;
          default:
            gradeDisplay = '$gradeNum年級';
        }
      } else {
        gradeDisplay = _yearGrade;
      }
      promptBuffer.writeln('年級: $gradeDisplay');
    }
    if (_introduction.isNotEmpty) {
      promptBuffer.writeln('自我介紹: $_introduction');
    }
    promptBuffer.writeln();
    
    // 添加用戶統計信息
    promptBuffer.writeln('用戶學習數據摘要:');
    
    // 添加完成的關卡數據
    int totalLevels = _stats['total_levels'] ?? 0;
    int todayLevels = _stats['today_levels'] ?? 0;
    double accuracy = _stats['accuracy'] ?? 0;
    promptBuffer.writeln('總完成關卡數: $totalLevels');
    promptBuffer.writeln('今日完成關卡數: $todayLevels');
    promptBuffer.writeln('答題正確率: $accuracy%');
    
    // 添加弱點知識點 (最多15個)
    promptBuffer.writeln('\n弱點知識點:');
    int weakPointCount = 0;
    for (var point in _weakPoints) {
      if (weakPointCount >= 15) break;
      String pointName = point['point_name'] ?? '';
      String subject = point['subject'] ?? '';
      double score = (point['score'] as num?)?.toDouble() ?? 0;
      promptBuffer.writeln('- $pointName (科目: $subject, 分數: $score/10)');
      weakPointCount++;
    }
    
    // 添加科目能力數據
    promptBuffer.writeln('\n科目能力:');
    for (var ability in _subjectAbilities) {
      String subject = ability['subject'] ?? '';
      double score = (ability['average_score'] as num?)?.toDouble() ?? 0;
      promptBuffer.writeln('- $subject: $score/10');
    }
    
    // 添加學習連續性數據
    promptBuffer.writeln('\n學習連續性:');
    promptBuffer.writeln('當前連續學習天數: $_currentStreak');
    
    // 添加提示指南
    promptBuffer.writeln('\n請根據上述用戶數據，完成以下兩個任務：');
    promptBuffer.writeln('\n任務1：生成5條針對性的學習建議，每條建議以簡潔明了的條目形式呈現，適合中學生理解。建議應該涵蓋弱點科目、可提升空間、學習習慣和學習方法等方面，可以跟我們這個 Dogtor : AI 學習關卡是 app 相關，給實際一點的建議，不要說一些中學生難做的事。每條建議應該是一個完整的句子，以動詞開頭，提供明確可行的學習指導。');
    
    promptBuffer.writeln('\n任務2：生成三個簡短的學習方向段落，分別是：');
    promptBuffer.writeln('1. 優先學習（列出2-3個最需要優先學習的知識點或科目）');
    promptBuffer.writeln('2. 需要複習（列出2-3個需要複習的知識點或科目）');
    promptBuffer.writeln('3. 可以提升（列出2-3個有潛力提升的知識點或科目）');
    
    promptBuffer.writeln('\n請以JSON格式回應，結構如下：');
    promptBuffer.writeln('{');
    promptBuffer.writeln('  "suggestions": ["建議1", "建議2", "建議3", "建議4", "建議5"],');
    promptBuffer.writeln('  "sections": {');
    promptBuffer.writeln('    "priority": "優先學習的內容...",');
    promptBuffer.writeln('    "review": "需要複習的內容...",');
    promptBuffer.writeln('    "improve": "可以提升的內容..."');
    promptBuffer.writeln('  }');
    promptBuffer.writeln('}');
    
    return promptBuffer.toString();
  }

  Future<void> _fetchUserStats() async {
    setState(() {
      _errorMessage = '';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = '請先登入';
        });
        return;
      }

      final response = await http.post(
        Uri.parse('https://superb-backend-1041765261654.asia-east1.run.app/get_user_stats'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json; charset=utf-8',
        },
        body: jsonEncode({'user_id': user.uid}),
      );

      if (response.statusCode == 200) {
        final jsonString = utf8.decode(response.bodyBytes);
        final data = jsonDecode(jsonString);
        if (data['success']) {
          setState(() {
            _stats = data['stats'];
          });
        } else {
          setState(() {
            _errorMessage = data['message'] ?? '獲取數據失敗';
          });
        }
      } else {
        setState(() {
          _errorMessage = '伺服器錯誤: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '發生錯誤: $e';
      });
    }
    
    // 獲取本月科目進度數據
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final response = await http.post(
        Uri.parse('https://superb-backend-1041765261654.asia-east1.run.app/get_monthly_subject_progress'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json; charset=utf-8',
        },
        body: jsonEncode({'user_id': user.uid}),
      );

      if (response.statusCode == 200) {
        final jsonString = utf8.decode(response.bodyBytes);
        final data = jsonDecode(jsonString);
        if (data['success']) {
          setState(() {
            final updatedStats = {..._stats};
            updatedStats['monthly_subjects'] = data['monthly_subjects'];
            updatedStats['month_info'] = data['month_info'];
            _stats = updatedStats;
          });
        }
      }
    } catch (e) {
      print('獲取本月科目進度時出錯: $e');
    }
  }

  // 獲取知識點分數
  Future<void> _fetchKnowledgeScores() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final response = await http.get(
        Uri.parse('https://superb-backend-1041765261654.asia-east1.run.app/get_knowledge_scores/${user.uid}'),
        headers: {
          'Accept': 'application/json; charset=utf-8',
        },
      );

      if (response.statusCode == 200) {
        final jsonString = utf8.decode(response.bodyBytes);
        final data = jsonDecode(jsonString);
        if (data['success']) {
          setState(() {
            _knowledgeScores = List<Map<String, dynamic>>.from(data['scores']);
            
            // 找出弱點知識點（分數低於5分的）
            _weakPoints = _knowledgeScores
                .where((score) => (score['score'] as num) < 5 && (score['score'] as num) > 0)
                .toList()
              ..sort((a, b) => (a['score'] as num).compareTo(b['score'] as num));
          });
        }
      }
    } catch (e) {
      print('獲取知識點分數時出錯: $e');
    }
  }

  // 獲取學習天數數據，包括當前連續天數和歷史最高連續天數
  Future<void> _fetchLearningDays() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final response = await http.get(
        Uri.parse('https://superb-backend-1041765261654.asia-east1.run.app/get_learning_days/${user.uid}'),
        headers: {
          'Accept': 'application/json; charset=utf-8',
        },
      );

      if (response.statusCode == 200) {
        final jsonString = utf8.decode(response.bodyBytes);
        final data = jsonDecode(jsonString);
        if (data['success']) {
          setState(() {
            _currentStreak = data['current_streak'] ?? 0;
            _maxStreak = data['total_streak'] ?? 0;
            
            // 確保weekly stats API返回前也能顯示連續天數
            if (_streak == 0) {
              _streak = _currentStreak;
            }
          });
        }
      }
    } catch (e) {
      print('獲取學習天數記錄時出錯: $e');
    }
  }

  // 獲取每週學習統計
  Future<void> _fetchWeeklyStats() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final response = await http.get(
        Uri.parse('https://superb-backend-1041765261654.asia-east1.run.app/get_weekly_stats/${user.uid}'),
        headers: {
          'Accept': 'application/json; charset=utf-8',
        },
      );

      if (response.statusCode == 200) {
        final jsonString = utf8.decode(response.bodyBytes);
        final data = jsonDecode(jsonString);
        if (data['success']) {
          setState(() {
            _weeklyStats = {
              '本週': List<Map<String, dynamic>>.from(data['weekly_stats']['this_week']),
              '上週': List<Map<String, dynamic>>.from(data['weekly_stats']['last_week']),
            };
            _streak = data['streak'];
          });
        }
      }
    } catch (e) {
      print('獲取每週統計時出錯: $e');
    }
  }

  // 獲取學習建議
  Future<void> _fetchLearningSuggestions() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final response = await http.get(
        Uri.parse('https://superb-backend-1041765261654.asia-east1.run.app/get_learning_suggestions/${user.uid}'),
        headers: {
          'Accept': 'application/json; charset=utf-8',
        },
      );

      if (response.statusCode == 200) {
        final jsonString = utf8.decode(response.bodyBytes);
        final data = jsonDecode(jsonString);
        if (data['success']) {
          setState(() {
            // 確保只獲取分數大於 0 的弱點知識點
            List<Map<String, dynamic>> weakPoints = List<Map<String, dynamic>>.from(data['weak_points']);
            _weakPoints = weakPoints.where((point) => (point['score'] as num) > 0).toList();
            
            _recommendedChapters = List<Map<String, dynamic>>.from(data['recommended_chapters']);
            _learningTips = List<String>.from(data['tips']);
          });
        }
      }
    } catch (e) {
      print('獲取學習建議時出錯: $e');
    }
  }

  // 獲取科目能力統計
  Future<void> _fetchSubjectAbilities() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final response = await http.post(
        Uri.parse('https://superb-backend-1041765261654.asia-east1.run.app/get_subject_abilities'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json; charset=utf-8',
        },
        body: jsonEncode({'user_id': user.uid}),
      );
      
      if (response.statusCode == 200) {
        final jsonString = utf8.decode(response.bodyBytes);
        final data = jsonDecode(jsonString);
        if (data['success']) {
          if (mounted) {
            // 確保數據有效且包含所需欄位
            List<Map<String, dynamic>> validAbilities = [];
            List<dynamic> rawAbilities = data['subject_abilities'] ?? [];
            
            for (var ability in rawAbilities) {
              // 檢查每個科目能力記錄是否包含所需欄位
              if (ability is Map<String, dynamic> && 
                  ability.containsKey('subject') && 
                  ability.containsKey('total_attempts') && 
                  ability.containsKey('correct_attempts') && 
                  ability.containsKey('ability_score')) {
                // 確保資料類型正確
                Map<String, dynamic> validAbility = {
                  'subject': ability['subject'],
                  'total_attempts': ability['total_attempts'] is int ? ability['total_attempts'] : (ability['total_attempts'] is double ? (ability['total_attempts'] as double).toInt() : 0),
                  'correct_attempts': ability['correct_attempts'] is int ? ability['correct_attempts'] : (ability['correct_attempts'] is double ? (ability['correct_attempts'] as double).toInt() : 0),
                  'ability_score': ability['ability_score'] is double ? ability['ability_score'] : (ability['ability_score'] is int ? (ability['ability_score'] as int).toDouble() : 0.0)
                };
                validAbilities.add(validAbility);
              }
            }
            
            setState(() {
              _subjectAbilities = validAbilities;
              print("成功獲取科目能力統計: ${_subjectAbilities.length} 個科目");
            });
          }
        } else {
          print("API返回失敗: ${data['message']}");
        }
      } else {
        print("API請求失敗: ${response.statusCode}");
      }
    } catch (e) {
      print('獲取科目能力統計時出錯: $e');
    }
  }

  // 加載用戶個人資訊
  Future<void> _loadUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _nickname = prefs.getString('nickname') ?? '';
        _yearGrade = prefs.getString('year_grade') ?? '';
        _introduction = prefs.getString('introduction') ?? '';
      });
      print('已加載用戶資訊: 暱稱=$_nickname, 年級=$_yearGrade');
    } catch (e) {
      print('加載用戶資訊時出錯: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的學習統計'),
        backgroundColor: primaryColor,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: accentColor,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(icon: Icon(Icons.dashboard), text: '總覽'),
            Tab(icon: Icon(Icons.trending_up), text: '學習趨勢'),
            Tab(icon: Icon(Icons.psychology), text: '科目能力'),
            Tab(icon: Icon(Icons.lightbulb), text: '學習建議'),
          ],
        ),
      ),
      body: Container(
        // 添加漸變背景，模擬海洋效果
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [primaryColor, Color(0xFF0D3B69)],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color.fromARGB(255, 238, 159, 41)),
              ))
            : _errorMessage.isNotEmpty
                ? Center(child: Text(_errorMessage, style: TextStyle(color: Colors.red)))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(),
                      _buildTrendsTab(),
                      _buildKnowledgeTab(),
                      _buildSuggestionsTab(),
                    ],
                  ),
      ),
    );
  }

  // 總覽標籤頁
  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _fetchUserStats();
        await _fetchKnowledgeScores();
        await _fetchWeeklyStats();
        await _fetchLearningSuggestions();
      },
      color: accentColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTodayStats(),
            const SizedBox(height: 24),
            _buildSubjectStats(),
            const SizedBox(height: 24),
            _buildTotalStats(),
            const SizedBox(height: 24),
            _buildRecentLevels(),
          ],
        ),
      ),
    );
  }

  // 學習趨勢標籤頁
  Widget _buildTrendsTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _fetchWeeklyStats();
        // 同時刷新月度科目進度數據
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          try {
            final response = await http.post(
              Uri.parse('https://superb-backend-1041765261654.asia-east1.run.app/get_monthly_subject_progress'),
              headers: {
                'Content-Type': 'application/json; charset=utf-8',
                'Accept': 'application/json; charset=utf-8',
              },
              body: jsonEncode({'user_id': user.uid}),
            );

            if (response.statusCode == 200) {
              final jsonString = utf8.decode(response.bodyBytes);
              final data = jsonDecode(jsonString);
              if (data['success'] && mounted) {
                setState(() {
                  final updatedStats = {..._stats};
                  updatedStats['monthly_subjects'] = data['monthly_subjects'];
                  updatedStats['month_info'] = data['month_info'];
                  _stats = updatedStats;
                });
              }
            }
          } catch (e) {
            print('刷新月度科目進度時出錯: $e');
          }
        }
      },
      color: accentColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWeeklyTrends(),
            const SizedBox(height: 24),
            _buildLearningStreak(),
            const SizedBox(height: 24),
            // 不再顯示月度科目進度
          ],
        ),
      ),
    );
  }

  // 知識掌握標籤頁
  Widget _buildKnowledgeTab() {
    return RefreshIndicator(
      onRefresh: _fetchSubjectAbilities,
      color: accentColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSubjectAbilityChart(),
            const SizedBox(height: 24),
            _buildSubjectRanking(),
          ],
        ),
      ),
    );
  }

  // 學習建議標籤頁
  Widget _buildSuggestionsTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _fetchUserStats();
        await _fetchKnowledgeScores();
        await _fetchWeeklyStats();
        await _fetchLearningSuggestions();
      },
      color: accentColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWeakPointsCard(),
            const SizedBox(height: 24),
            _buildLearningTips(),
            const SizedBox(height: 24),
            _buildNextSteps(),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayStats() {
    final todaySubjectLevels = _stats['today_subject_levels'] as List<dynamic>? ?? [];
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
                  child: Icon(
                    Icons.today,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  '今日學習',
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatCard(
                  icon: Icons.star,
                  color: accentColor,
                  value: _stats['today_levels'].toString(),
                  label: '今日完成關卡',
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (todaySubjectLevels.isNotEmpty)
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: secondaryColor.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '今日各科目完成情況',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: todaySubjectLevels.map<Widget>((subject) {
                        final subjectName = subject['subject'] as String;
                        final levelCount = subject['level_count'] as int;
                        
                        // 定義科目顏色映射
                        final subjectColors = {
                          '數學': Colors.blue,
                          '國文': Colors.green,
                          '英文': Colors.purple,
                          '自然': const Color.fromARGB(255, 246, 172, 61),
                          '生物': Colors.red,
                          '地科': Colors.brown,
                          '化學': Colors.blueGrey,
                          '物理': Colors.deepPurple,
                          '歷史': Colors.deepOrange,
                          '地理': Colors.teal,
                          '公民': Colors.pink,
                        };
                        
                        return Chip(
                          backgroundColor: subjectColors[subjectName]?.withOpacity(0.8) ?? Colors.grey,
                          avatar: CircleAvatar(
                            backgroundColor: Colors.white,
                            child: Icon(Icons.book, size: 16, color: subjectColors[subjectName] ?? Colors.grey),
                          ),
                          label: Text(
                            '$subjectName: $levelCount 關',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 學習趨勢圖表
  Widget _buildWeeklyTrends() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
                  child: Icon(
                    Icons.trending_up,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  '本週學習趨勢',
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 300,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: secondaryColor.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _weeklyStats.isEmpty
                  ? Center(child: Text('暫無數據', style: TextStyle(color: Colors.white70)))
                  : LineChart(
                      LineChartData(
                        lineTouchData: LineTouchData(
                          enabled: true,
                          touchTooltipData: LineTouchTooltipData(
                            tooltipPadding: EdgeInsets.all(8),
                            tooltipMargin: 8,
                            getTooltipItems: (List<LineBarSpot> spots) {
                              return spots.map((spot) {
                                return LineTooltipItem(
                                  '${spot.y.toInt()} 關',
                                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                );
                              }).toList();
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (double value, TitleMeta meta) {
                                final now = DateTime.now();
                                final today = DateTime(now.year, now.month, now.day);
                                final date = today.subtract(Duration(days: 6 - value.toInt()));
                                return Text(
                                  '${date.month}/${date.day}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                );
                              },
                              reservedSize: 30,
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (double value, TitleMeta meta) {
                                if (value == 0) return const Text('0', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 10));
                                if (value % 2 == 0) return Text(value.toInt().toString(), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 10));
                                return const Text('');
                              },
                              reservedSize: 30,
                            ),
                          ),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: FlGridData(
                          show: true,
                          checkToShowHorizontalLine: (value) => value % 2 == 0,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: Colors.white10,
                            strokeWidth: 1,
                          ),
                          drawVerticalLine: false,
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: _getLineSpots('本週'),
                            isCurved: false,
                            color: Colors.blue,
                            barWidth: 2,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: 4,
                                  color: Colors.blue,
                                  strokeWidth: 0,
                                );
                              },
                              checkToShowDot: (spot, barData) => true,
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Colors.blue.withOpacity(0.1),
                            ),
                          ),
                        ],
                        extraLinesData: ExtraLinesData(
                          horizontalLines: [],
                          verticalLines: _getVerticalTextLines('本週'),
                        ),
                      ),
                    ),
            ),
            // 移除本週/上週的按鈕和圖例，只保留本週數據
          ],
        ),
      ),
    );
  }

  // 新增方法：獲取折線圖數據點
  List<FlSpot> _getLineSpots(String week) {
    if (!_weeklyStats.containsKey(week)) return [];
    
    List<FlSpot> spots = [];
    final weekData = _weeklyStats[week] ?? [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // 創建過去7天的日期列表（包含今天）
    List<DateTime> last7Days = List.generate(7, (index) {
      return today.subtract(Duration(days: 6 - index));
    });
    
    // 為每一天創建數據點
    for (int i = 0; i < 7; i++) {
      final targetDate = last7Days[i];
      final dayData = weekData.firstWhere(
        (data) {
          final dataDate = DateTime.parse(data['date']);
          return dataDate.year == targetDate.year &&
                 dataDate.month == targetDate.month &&
                 dataDate.day == targetDate.day;
        },
        orElse: () => {'levels': 0},
      );
      
      spots.add(FlSpot(i.toDouble(), (dayData['levels'] as int? ?? 0).toDouble()));
    }
    
    return spots;
  }

  // 新增方法：為折線圖數據點添加數字標記
  List<VerticalLine> _getVerticalTextLines(String week) {
    if (!_weeklyStats.containsKey(week)) return [];
    
    List<VerticalLine> lines = [];
    final weekData = _weeklyStats[week] ?? [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // 創建過去7天的日期列表（包含今天）
    List<DateTime> last7Days = List.generate(7, (index) {
      return today.subtract(Duration(days: 6 - index));
    });
    
    // 為每一天創建垂直線
    for (int i = 0; i < 7; i++) {
      final targetDate = last7Days[i];
      final dayData = weekData.firstWhere(
        (data) {
          final dataDate = DateTime.parse(data['date']);
          return dataDate.year == targetDate.year &&
                 dataDate.month == targetDate.month &&
                 dataDate.day == targetDate.day;
        },
        orElse: () => {'levels': 0},
      );
      
      final value = dayData['levels'] as int? ?? 0;
      if (value > 0) {
        lines.add(
          VerticalLine(
            x: i.toDouble(),
            label: VerticalLineLabel(
              show: true,
              alignment: Alignment.topCenter,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              labelResolver: (line) => value.toString(),
            ),
            color: Colors.transparent,
          ),
        );
      }
    }
    
    return lines;
  }

  // 更新學習連續性Widget
  Widget _buildLearningStreak() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
                  child: Icon(
                    Icons.local_fire_department,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  '學習連續性',
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 當前連續學習天數
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: secondaryColor.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.local_fire_department,
                    color: Colors.orange,
                    size: 40,
                  ),
                  SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '當前連續學習',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '$_currentStreak 天',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 歷史最高連續學習天數
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: secondaryColor.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.emoji_events,
                    color: Colors.amber,
                    size: 40,
                  ),
                  SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '歷史最高連續',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '$_maxStreak 天',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 使用友好檔案頁面風格的近7天學習記錄
            _buildPast7DaysLearningRecord(),
          ],
        ),
      ),
    );
  }

  // 添加新方法：顯示過去7天學習記錄，使用圓形風格
  Widget _buildPast7DaysLearningRecord() {
    // 獲取過去7天日期
    final now = DateTime.now();
    final pastDays = List.generate(7, (index) => 
      DateTime(now.year, now.month, now.day - (6 - index)));
    
    // 星期幾的顯示文字
    final weekdayNames = ['一', '二', '三', '四', '五', '六', '日'];
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: secondaryColor.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // 標題
          Text(
            '近7天學習記錄',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          // 日期圓點
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: pastDays.map((date) {
              final isToday = date.year == now.year && 
                             date.month == now.month && 
                             date.day == now.day;
              
              // 檢查該日期是否有學習記錄
              // 使用 _weeklyStats 數據判斷是否學習
              bool hasLearned = false;
              if (_weeklyStats.containsKey('本週')) {
                final weekData = _weeklyStats['本週'] ?? [];
                for (var data in weekData) {
                  final dataDate = DateTime.parse(data['date']);
                  if (dataDate.year == date.year && 
                      dataDate.month == date.month && 
                      dataDate.day == date.day && 
                      (data['levels'] as int? ?? 0) > 0) {
                    hasLearned = true;
                    break;
                  }
                }
              }
              
              // 決定顯示的顏色
              final baseColor = hasLearned 
                  ? accentColor
                  : Colors.grey.shade700;
              
              return Column(
                children: [
                  // 星期幾
                  Text(
                    weekdayNames[date.weekday - 1],
                    style: TextStyle(
                      color: isToday
                          ? Colors.white
                          : Colors.white70,
                      fontSize: 14,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  SizedBox(height: 8),
                  // 圓點或日期
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasLearned ? baseColor : Colors.white24,
                      border: isToday
                          ? Border.all(
                              color: Colors.white,
                              width: 2,
                            )
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        date.day.toString(),
                        style: TextStyle(
                          color: hasLearned ? Colors.white : Colors.white70,
                          fontWeight: isToday || hasLearned 
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  // 有學習記錄的顯示勾
                  if (hasLearned)
                    Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 16,
                    )
                  else
                    SizedBox(height: 16),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // 新增方法：科目進度
  Widget _buildSubjectProgress() {
    final subjectLevels = _stats['subject_levels'] as List<dynamic>? ?? [];
    
    // 定義科目顏色映射
    final subjectColors = {
      '數學': Colors.blue,
      '國文': Colors.green,
      '英文': Colors.purple,
      '自然': const Color.fromARGB(255, 246, 172, 61),
      '生物': Colors.red,
      '地科': Colors.brown,
      '化學': Colors.blueGrey,
      '物理': Colors.deepPurple,
      '歷史': Colors.deepOrange,
      '地理': Colors.teal,
      '公民': Colors.pink,
    };
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
                  child: Icon(
                    Icons.subject,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  '科目進度',
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (subjectLevels.isEmpty)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: secondaryColor.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '尚未完成任何關卡',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              )
            else
              Column(
                children: subjectLevels.map<Widget>((subject) {
                  final subjectName = subject['subject'] as String;
                  final levelCount = subject['level_count'] as int;
                  final color = subjectColors[subjectName] ?? Colors.grey;
                  
                  // 假設每個科目總共有30關
                  final totalLevels = 30;
                  final progress = levelCount / totalLevels;
                  
                  return Container(
                    margin: EdgeInsets.only(bottom: 12),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: secondaryColor.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: color,
                              radius: 12,
                              child: Icon(Icons.book, size: 14, color: Colors.white),
                            ),
                            SizedBox(width: 8),
                            Text(
                              subjectName,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Spacer(),
                            Text(
                              '$levelCount/$totalLevels 關',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.white24,
                            color: color,
                            minHeight: 8,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '完成度: ${(progress * 100).toInt()}%',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  // 修改：下一步學習計劃
  Widget _buildNextSteps() {
    // 如果尚未點擊獲取建議按鈕，則不顯示
    if (!_hasClickedLearningTips) {
      return SizedBox();
    }
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
                  child: Icon(
                    Icons.next_plan,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  '下一步學習計劃',
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isGeneratingTips)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: secondaryColor.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '正在生成學習計劃...',
                    style: TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: secondaryColor.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildNextStepItem(
                      icon: Icons.priority_high,
                      title: '優先學習',
                      content: _learningSections['priority'] ?? '優先學習內容還未生成',
                      color: Colors.red,
                    ),
                    Divider(color: Colors.white24, height: 24),
                    _buildNextStepItem(
                      icon: Icons.refresh,
                      title: '需要複習',
                      content: _learningSections['review'] ?? '需要複習的內容還未生成',
                      color: Colors.orange,
                    ),
                    Divider(color: Colors.white24, height: 24),
                    _buildNextStepItem(
                      icon: Icons.trending_up,
                      title: '可以提升',
                      content: _learningSections['improve'] ?? '可以提升的內容還未生成',
                      color: Colors.green,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 新增方法：下一步學習項目
  Widget _buildNextStepItem({
    required IconData icon,
    required String title,
    required String content,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 4),
              Text(
                content,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 顯示詳細對話框
  void _showDetailDialog(String title, String description) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        title: Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          description,
          style: TextStyle(
            color: Colors.white70,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '確定',
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // 這裡可以添加創建自訂學習計劃的導航
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('即將推出：訂製學習計劃功能'),
                  backgroundColor: accentColor,
                ),
              );
            },
            child: Text(
              '立即開始學習',
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 生成個人化學習計劃
  void _generatePersonalizedPlan() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        title: Row(
          children: [
            Icon(Icons.auto_awesome, color: accentColor),
            SizedBox(width: 8),
            Text(
              '個人化學習計劃',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
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
                '根據您的學習數據，我們為您生成了以下學習計劃：',
                style: TextStyle(color: Colors.white70),
              ),
              SizedBox(height: 16),
              _buildPlanDay('週一', '代數方程式 (30分鐘)', '英語閱讀理解 (20分鐘)'),
              _buildPlanDay('週二', '化學反應式平衡 (30分鐘)', '複習三角函數 (20分鐘)'),
              _buildPlanDay('週三', '代數方程式 (30分鐘)', '物理力學 (20分鐘)'),
              _buildPlanDay('週四', '化學反應式平衡 (30分鐘)', '統計概率 (20分鐘)'),
              _buildPlanDay('週五', '複習本週內容 (45分鐘)', ''),
              _buildPlanDay('週末', '自選挑戰題 (60分鐘)', ''),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '取消',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已保存您的個人化學習計劃'),
                  backgroundColor: accentColor,
                ),
              );
            },
            child: Text(
              '保存計劃',
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 輔助方法：學習計劃日程
  Widget _buildPlanDay(String day, String mainTask, String secondaryTask) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 70,
            child: Text(
              day,
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mainTask,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (secondaryTask.isNotEmpty)
                  Text(
                    secondaryTask,
                    style: TextStyle(
                      color: Colors.white70,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 輔助方法：根據分數獲取顏色
  Color _getScoreColor(double score) {
    if (score < 3) return Colors.red;
    if (score < 5) return Colors.orange;
    if (score < 7) return Colors.yellow;
    if (score < 9) return Colors.lightGreen;
    return Colors.green;
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: secondaryColor.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectStats() {
    final subjectLevels = _stats['subject_levels'] as List<dynamic>? ?? [];
    
    // 定義科目顏色映射
    final subjectColors = {
      '數學': Colors.blue,
      '國文': Colors.green,
      '英文': Colors.purple,
      '自然': const Color.fromARGB(255, 246, 172, 61),
      '生物': Colors.red,
      '地科': Colors.brown,
      '化學': Colors.blueGrey,
      '物理': Colors.deepPurple,
      '歷史': Colors.deepOrange,
      '地理': Colors.teal,
      '公民': Colors.pink,
    };

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
                  child: Icon(
                    Icons.pie_chart,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  '各科目學習統計',
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (subjectLevels.isEmpty)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: secondaryColor.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '尚未完成任何關卡',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              )
            else
              Column(
                children: [
                  SizedBox(
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        sections: subjectLevels.map((subject) {
                          final subjectName = subject['subject'] as String;
                          final levelCount = subject['level_count'] as int;
                          return PieChartSectionData(
                            color: subjectColors[subjectName] ?? Colors.grey,
                            value: levelCount.toDouble(),
                            title: subjectName, // 只顯示科目名稱，不顯示數字
                            radius: 80,
                            titleStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        }).toList(),
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: secondaryColor.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: subjectLevels.map<Widget>((subject) {
                        final subjectName = subject['subject'] as String;
                        final levelCount = subject['level_count'] as int;
                        return Chip(
                          backgroundColor: subjectColors[subjectName]?.withOpacity(0.8) ?? Colors.grey,
                          avatar: CircleAvatar(
                            backgroundColor: Colors.white,
                            child: Icon(Icons.book, size: 16, color: subjectColors[subjectName] ?? Colors.grey),
                          ),
                          label: Text(
                            '$subjectName: $levelCount 關',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalStats() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
                  child: Icon(
                    Icons.bar_chart,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  '總體學習統計',
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatCard(
                  icon: Icons.emoji_events,
                  color: accentColor,
                  value: _stats['total_levels'].toString(),
                  label: '總完成關卡',
                ),
                _buildStatCard(
                  icon: Icons.check_circle,
                  color: Colors.green,
                  value: '${_stats['accuracy']}%',
                  label: '總答對率',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentLevels() {
    final recentLevels = _stats['recent_levels'] as List<dynamic>? ?? [];

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
                  child: Icon(
                    Icons.history,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  '最近完成的關卡',
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (recentLevels.isEmpty)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: secondaryColor.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '尚未完成任何關卡',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentLevels.length,
                separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white24),
                itemBuilder: (context, index) {
                  final level = recentLevels[index];
                  final DateTime answeredAt = DateTime.parse(level['answered_at']);
                  final formattedDate = DateFormat('yyyy/MM/dd HH:mm').format(answeredAt);
                  
                  final subject = level['subject'] is String ? level['subject'] : '未知科目';
                  final chapterName = level['chapter_name'] is String ? level['chapter_name'] : '未知章節';
                  final subjectInitial = subject.isNotEmpty ? subject[0] : '?';
                  
                  // 定義科目顏色映射
                  final subjectColors = {
                    '數學': Colors.blue,
                    '國文': Colors.green,
                    '英文': Colors.purple,
                    '自然': const Color.fromARGB(255, 246, 172, 61),
                    '生物': Colors.red,
                    '地科': Colors.brown,
                    '化學': Colors.blueGrey,
                    '物理': Colors.deepPurple,
                    '歷史': Colors.deepOrange,
                    '地理': Colors.teal,
                    '公民': Colors.pink,
                  };
                  
                  final backgroundColor = subjectColors[subject] ?? Colors.blue[700];
                  
                  return Container(
                    margin: EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: secondaryColor.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: backgroundColor,
                        child: Text(subjectInitial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(
                        '$chapterName',
                        style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Row(
                        children: [
                          const Icon(Icons.access_time, size: 14, color: Colors.white70),
                          const SizedBox(width: 4),
                          Text(formattedDate, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          3,
                          (i) => Icon(
                            Icons.star,
                            color: i < (level['stars'] ?? 0) ? accentColor : Colors.white30,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // 科目能力圖表
  Widget _buildSubjectAbilityChart() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
                  child: Icon(
                    Icons.radar,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  '科目能力分析',
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_subjectAbilities.isEmpty)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: secondaryColor.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '尚未獲取科目能力數據',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              )
            else
              Container(
                height: 300,
                padding: EdgeInsets.symmetric(vertical: 16),
                child: RadarChart(
                  RadarChartData(
                    radarShape: RadarShape.polygon,
                    dataSets: [
                      RadarDataSet(
                        dataEntries: _getAbilityDataEntries(),
                        fillColor: accentColor.withOpacity(0.3),
                        borderColor: accentColor,
                        borderWidth: 2,
                        entryRadius: 5,
                      ),
                    ],
                    radarBackgroundColor: Colors.transparent,
                    borderData: FlBorderData(show: false),
                    gridBorderData: BorderSide(color: Colors.white10, width: 1),
                    ticksTextStyle: const TextStyle(
                      color: Colors.white70, 
                      fontSize: 10,
                    ),
                    tickCount: 5,
                    titleTextStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    getTitle: (index, angle) {
                      if (_subjectAbilities.isEmpty || index >= _subjectAbilities.length) {
                        return RadarChartTitle(text: '', angle: angle);
                      }
                      // 使用科目名稱
                      final subject = _subjectAbilities[index]['subject'] as String;
                      return RadarChartTitle(text: subject, angle: angle);
                    },
                  ),
                ),
              ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: secondaryColor.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '分數計算公式',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '科目能力分數綜合考慮答題正確率和答題次數，能力值滿分為10分。',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
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

  // 獲取能力雷達圖數據
  List<RadarEntry> _getAbilityDataEntries() {
    // 如果數據為空，返回空列表
    if (_subjectAbilities.isEmpty) {
      return [];
    }
    
    // 確保至少取前6個科目（或全部如果少於6個）
    final int maxSubjects = 8;
    final subjectsToShow = _subjectAbilities.length > maxSubjects 
        ? _subjectAbilities.sublist(0, maxSubjects) 
        : _subjectAbilities;
    
    return subjectsToShow.map((subject) {
      final abilityScore = (subject['ability_score'] as num?)?.toDouble() ?? 0.0;
      return RadarEntry(value: abilityScore);
    }).toList();
  }

  // 科目掌握排行榜
  Widget _buildSubjectRanking() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
                  child: Icon(
                    Icons.leaderboard,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  '科目掌握排行',
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_subjectAbilities.isEmpty)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: secondaryColor.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '尚未有科目能力數據',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              )
            else
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: secondaryColor.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            '科目',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '統計',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            '分數',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    Divider(color: Colors.white30),
                    ..._subjectAbilities.map((subject) {
                      final subjectName = subject['subject'] as String;
                      // 修改類型轉換以確保兼容
                      final totalAttempts = (subject['total_attempts'] is int) 
                          ? subject['total_attempts'] as int 
                          : (subject['total_attempts'] as double).toInt();
                      final correctAttempts = (subject['correct_attempts'] is int) 
                          ? subject['correct_attempts'] as int 
                          : (subject['correct_attempts'] as double).toInt();
                      final abilityScore = subject['ability_score'] as num;
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: _getSubjectColor(subjectName),
                                    radius: 12,
                                    child: Text(
                                      subjectName.isNotEmpty ? subjectName[0] : '?',
                                      style: TextStyle(
                                        color: Colors.white, 
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    subjectName,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '${correctAttempts}/${totalAttempts}題',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getScoreColor(abilityScore.toDouble()),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  abilityScore.toStringAsFixed(1),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 新增方法：弱點知識點卡片
  Widget _buildWeakPointsCard() {
    // 應用篩選器過濾弱點知識點
    var filteredWeakPoints = _weakPoints.where((point) =>
      (point['score'] as num) > 0 && 
      (_selectedSubject == null || point['subject'] == _selectedSubject) &&
      (_selectedChapter == null || point['chapter_name'] == _selectedChapter)
    ).toList();
    
    // 獲取所有可用的科目和章節（用於篩選器）
    Set<String> subjects = {};
    Set<String> chapters = {};
    
    for (var point in _weakPoints) {
      if ((point['score'] as num) > 0) {
        String subject = point['subject'] as String? ?? '';
        String chapter = point['chapter_name'] as String? ?? '';
        if (subject.isNotEmpty) subjects.add(subject);
        if (chapter.isNotEmpty) chapters.add(chapter);
      }
    }
    
    // 確保選定的科目在列表中存在
    if (_selectedSubject != null && !subjects.contains(_selectedSubject)) {
      _selectedSubject = null;
    }
    
    // 確保選定的章節在列表中存在
    if (_selectedChapter != null) {
      bool chapterExists = false;
      if (_selectedSubject == null) {
        chapterExists = chapters.contains(_selectedChapter);
      } else {
        chapterExists = _weakPoints.any((point) => 
          point['subject'] == _selectedSubject && 
          point['chapter_name'] == _selectedChapter
        );
      }
      
      if (!chapterExists) {
        _selectedChapter = null;
      }
    }
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
                  child: Icon(
                    Icons.warning_amber,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  '需要加強的知識點',
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 新增篩選器
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: secondaryColor.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '篩選:',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white10,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            hintText: '選擇科目',
                            hintStyle: TextStyle(color: Colors.white70),
                          ),
                          dropdownColor: secondaryColor,
                          value: _selectedSubject,
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text('所有科目', style: TextStyle(color: Colors.white)),
                            ),
                            ...subjects.toList().map((subject) => 
                              DropdownMenuItem<String?>(
                                value: subject,
                                child: Text(subject, style: TextStyle(color: Colors.white)),
                              )
                            ).toList(),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedSubject = value;
                              // 如果選擇了新科目，重置章節篩選
                              if (_selectedChapter != null) {
                                bool chapterBelongsToSubject = _weakPoints.any((point) => 
                                  point['subject'] == value && 
                                  point['chapter_name'] == _selectedChapter
                                );
                                if (!chapterBelongsToSubject) {
                                  _selectedChapter = null;
                                }
                              }
                            });
                          },
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white10,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            hintText: '選擇章節',
                            hintStyle: TextStyle(color: Colors.white70),
                          ),
                          dropdownColor: secondaryColor,
                          value: _selectedChapter,
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text('所有章節', style: TextStyle(color: Colors.white)),
                            ),
                            ...chapters.toList().where((chapter) => 
                              _selectedSubject == null || 
                              _weakPoints.any((point) => 
                                point['subject'] == _selectedSubject && 
                                point['chapter_name'] == chapter
                              )
                            ).map((chapter) => 
                              DropdownMenuItem<String?>(
                                value: chapter,
                                child: Text(chapter, style: TextStyle(color: Colors.white)),
                              )
                            ).toList(),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedChapter = value;
                              // 如果選擇了章節但沒有選科目，自動選擇對應科目
                              if (_selectedChapter != null && _selectedSubject == null) {
                                for (var point in _weakPoints) {
                                  if (point['chapter_name'] == _selectedChapter) {
                                    _selectedSubject = point['subject'] as String?;
                                    break;
                                  }
                                }
                              }
                            });
                          },
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            if (filteredWeakPoints.isEmpty)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: secondaryColor.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    _weakPoints.isEmpty 
                      ? '太棒了！目前沒有需要特別加強的知識點'
                      : '目前沒有符合篩選條件的知識點',
                    style: TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: secondaryColor.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: filteredWeakPoints.take(5).map((point) {
                    final pointName = point['point_name'] as String? ?? '';
                    final sectionName = point['section_name'] as String? ?? '';
                    final chapterName = point['chapter_name'] as String? ?? '';
                    final subject = point['subject'] as String? ?? '';
                    final score = (point['score'] as num?)?.toDouble() ?? 0;
                    
                    return Container(
                      margin: EdgeInsets.only(bottom: 12),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  pointName,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getScoreColor(score),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${score.toStringAsFixed(1)}/10',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            '科目: $subject',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '章節: $chapterName',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '小節: $sectionName',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: score / 10,
                              backgroundColor: Colors.white24,
                              color: _getScoreColor(score),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            
            const SizedBox(height: 16),
            
            // 添加學習建議按鈕
            if (!_hasClickedLearningTips)
              InkWell(
                onTap: () {
                  setState(() {
                    _hasClickedLearningTips = true;
                  });
                  
                  // 獲取學習建議和弱點知識點
                  _fetchLearningSuggestions();
                  _generateLearningTipsWithGemini();
                },
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lightbulb, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        '獲取學習建議',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 新增方法：學習建議
  Widget _buildLearningTips() {
    // 如果尚未點擊獲取建議按鈕，則不顯示
    if (!_hasClickedLearningTips) {
      return SizedBox();
    }
    
    // 使用個人化建議或默認建議
    final displayTips = _personalizedTips.isNotEmpty ? _personalizedTips : _learningTips;
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
                  child: Icon(
                    Icons.lightbulb,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  '學習建議',
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isGeneratingTips)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: secondaryColor.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '正在生成個人化學習建議...',
                        style: TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: secondaryColor.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: displayTips.map((tip) {
                    return Container(
                      margin: EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: accentColor,
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              tip,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 獲取科目對應的顏色
  Color _getSubjectColor(String subject) {
    final subjectColors = {
      '數學': Colors.blue,
      '國文': Colors.green,
      '英文': Colors.purple,
      '自然': const Color.fromARGB(255, 246, 172, 61),
      '生物': Colors.red,
      '地科': Colors.brown,
      '化學': Colors.blueGrey,
      '物理': Colors.deepPurple,
      '歷史': Colors.deepOrange,
      '地理': Colors.teal,
      '公民': Colors.pink,
      '未分類': Colors.grey,
    };
    
    return subjectColors[subject] ?? Colors.grey;
  }
}