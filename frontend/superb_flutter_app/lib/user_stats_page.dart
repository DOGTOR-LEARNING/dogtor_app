import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert' show utf8;  // 確保導入 utf8

class UserStatsPage extends StatefulWidget {
  const UserStatsPage({Key? key}) : super(key: key);

  @override
  _UserStatsPageState createState() => _UserStatsPageState();
}

class _UserStatsPageState extends State<UserStatsPage> {
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  String _errorMessage = '';
  
  // 更新主題色彩以匹配 chapter_detail_page_n.dart
  final Color primaryColor = Color(0xFF1E5B8C);  // 深藍色主題
  final Color secondaryColor = Color(0xFF2A7AB8); // 較淺的藍色
  final Color accentColor = Color.fromARGB(255, 238, 159, 41);    // 橙色強調色
  final Color cardColor = Color(0xFF3A8BC8);      // 淺藍色卡片背景色

  @override
  void initState() {
    super.initState();
    _fetchUserStats();
  }

  Future<void> _fetchUserStats() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
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
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = data['message'] ?? '獲取數據失敗';
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = '伺服器錯誤: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '發生錯誤: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的學習統計'),
        backgroundColor: primaryColor,
        elevation: 0,
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
                : _buildStatsContent(),
      ),
    );
  }

  Widget _buildStatsContent() {
    return RefreshIndicator(
      onRefresh: _fetchUserStats,
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

  Widget _buildTodayStats() {
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
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectStats() {
    final subjectLevels = _stats['subject_levels'] as List<dynamic>;
    
    // 定義科目顏色映射
    final subjectColors = {
      '數學': Colors.blue,
      '國文': Colors.green,
      '英文': Colors.purple,
      '理化': Colors.orange,
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
                            title: '$subjectName\n$levelCount',
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
    final recentLevels = _stats['recent_levels'] as List<dynamic>;

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
                    '理化': Colors.orange,
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
} 