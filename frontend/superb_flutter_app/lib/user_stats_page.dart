import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class UserStatsPage extends StatefulWidget {
  const UserStatsPage({Key? key}) : super(key: key);

  @override
  _UserStatsPageState createState() => _UserStatsPageState();
}

class _UserStatsPageState extends State<UserStatsPage> {
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  String _errorMessage = '';

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
        Uri.parse('https://dogtor-backend-gg-ew.onrender.com/get_user_stats'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': user.uid}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
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
        backgroundColor: Colors.blue[700],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage, style: TextStyle(color: Colors.red)))
              : _buildStatsContent(),
    );
  }

  Widget _buildStatsContent() {
    return RefreshIndicator(
      onRefresh: _fetchUserStats,
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '今日學習',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatCard(
                  icon: Icons.star,
                  color: Colors.amber,
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '各科目學習統計',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (subjectLevels.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('尚未完成任何關卡'),
                ),
              )
            else
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: subjectLevels.map<Widget>((subject) {
                final subjectName = subject['subject'] as String;
                final levelCount = subject['level_count'] as int;
                return Chip(
                  avatar: CircleAvatar(
                    backgroundColor: subjectColors[subjectName] ?? Colors.grey,
                    child: const Icon(Icons.book, size: 16, color: Colors.white),
                  ),
                  label: Text('$subjectName: $levelCount 關'),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalStats() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '總體學習統計',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatCard(
                  icon: Icons.emoji_events,
                  color: Colors.amber,
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '最近完成的關卡',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (recentLevels.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('尚未完成任何關卡'),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentLevels.length,
                itemBuilder: (context, index) {
                  final level = recentLevels[index];
                  final DateTime answeredAt = DateTime.parse(level['answered_at']);
                  final formattedDate = DateFormat('yyyy/MM/dd HH:mm').format(answeredAt);
                  
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue[700],
                      child: Text(level['subject'][0], style: const TextStyle(color: Colors.white)),
                    ),
                    title: Text('${level['subject']} - ${level['chapter_name']}'),
                    subtitle: Text('完成時間: $formattedDate'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        3,
                        (i) => Icon(
                          Icons.star,
                          color: i < level['stars'] ? Colors.amber : Colors.grey[300],
                          size: 20,
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
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
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
} 