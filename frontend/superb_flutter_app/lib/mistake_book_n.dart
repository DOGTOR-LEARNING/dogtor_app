import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'add_mistake_page.dart';

import 'package:hive/hive.dart';
import 'dart:typed_data';

class MistakeBookPage extends StatefulWidget {
  const MistakeBookPage({super.key});

  @override
  _MistakeBookPageState createState() => _MistakeBookPageState();
}

class _MistakeBookPageState extends State<MistakeBookPage> {
  List<Map<String, dynamic>> _mistakes = [];
  List<Map<String, dynamic>> _filteredMistakes = [];
  String _searchQuery = "";
  String _selectedSubject = "全部"; // Default selection

  @override
  void initState() {
    super.initState();
    _reloadLocalMistakes(); // 每次進入頁面時從Hive讀取本地錯題
  }

  // Load added mistakes from Hive
  Future<void> _reloadLocalMistakes() async {
    try {
      var box = await Hive.openBox('questionsBox'); // 打開 Hive Box
      print('📦 Box Length: ${box.length}');
      print('📦 Keys: ${box.keys}');

      for (var key in box.keys) {
        final value = box.get(key);
        print('🔑 $key: $value');
      }
      List<Map<String, dynamic>> localMistakes = [];

      // 迭代 Hive 中的所有項目
      box.toMap().forEach((key, value) {
        localMistakes.add({
          'q_id': key,
          'summary': value['summary'],
          'subject': value['subject'],
          'chapter': value['chapter'],
          'description': value['description'],
          'difficulty': value['difficulty'],
          'answer':
              value['answer'] ?? value['detailed_answer'] ?? '', // 支援舊格式的向後相容
          'tag': value['tag'],
          'note': value['note'] ?? '', // 給自己的小提醒
          'created_at':
              value['created_at'] ?? value['timestamp'] ?? '', // 支援舊格式的向後相容
          // 支援新的分離圖片欄位，同時向後相容舊格式
          'question_image_base64':
              value['question_image_base64'] ?? value['image_base64'] ?? '',
          'answer_image_base64': value['answer_image_base64'] ?? '',
          // 保留舊欄位以向後相容
          "image_base64":
              value['image_base64'] ?? value['question_image_base64'] ?? '',
          'is_sync': value['is_sync'] ?? false, // 同步狀態
        });
      });

      setState(() {
        _mistakes = localMistakes; // 更新錯題列表
        _filteredMistakes = _mistakes; // 初始顯示所有錯題
      });

      // 自動同步未同步的資料
      await _autoSyncUnsyncedData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading local mistakes: $e')),
      );
    }
  }

  // 自動同步未同步的資料
  Future<void> _autoSyncUnsyncedData() async {
    try {
      var box = await Hive.openBox('questionsBox');
      List<String> unsyncedIds = [];

      // 找出所有未同步的資料
      box.toMap().forEach((key, value) {
        if (value['is_sync'] == false || value['is_sync'] == null) {
          unsyncedIds.add(key.toString());
        }
      });

      if (unsyncedIds.isEmpty) {
        print("沒有需要同步的資料");
        return;
      }

      print("發現 ${unsyncedIds.length} 筆未同步資料，開始自動同步...");

      // 逐一同步未同步的資料
      for (String qId in unsyncedIds) {
        var mistakeData = box.get(qId);
        if (mistakeData != null) {
          await _syncSingleMistake(qId, mistakeData, box);
        }
      }

      print("自動同步完成");
    } catch (e) {
      print("自動同步錯誤: $e");
      // 不顯示錯誤給用戶，因為這是背景自動同步
    }
  }

  // 同步單筆錯題到雲端
  Future<void> _syncSingleMistake(
      String qId, Map<dynamic, dynamic> mistakeData, var box) async {
    try {
      final requestBody = {
        'summary': mistakeData['summary'] ?? '',
        'subject': mistakeData['subject'] ?? '',
        'chapter': mistakeData['chapter'] ?? '',
        'description': mistakeData['description'] ?? '',
        'difficulty': mistakeData['difficulty'] ?? 'Medium',
        'answer': mistakeData['answer'] ?? '',
        'tag': mistakeData['tag'] ?? '',
        'note': mistakeData['note'] ?? '',
        'created_at':
            mistakeData['created_at'] ?? DateTime.now().toIso8601String(),
        'question_image_base64': mistakeData['question_image_base64'] ?? '',
        'answer_image_base64': mistakeData['answer_image_base64'] ?? '',
        'user_id': 'default_user', // 預設用戶ID
      };

      final response = await http.post(
        Uri.parse(
            'https://superb-backend-1041765261654.asia-east1.run.app/mistake-book/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        // 同步成功，解析回應獲取雲端 ID
        final responseData = jsonDecode(response.body);
        final cloudId = responseData['q_id']?.toString();

        if (cloudId != null && cloudId != qId) {
          // 如果雲端 ID 不同於本地 ID，需要更新本地儲存
          // 刪除舊的本地 ID 記錄
          await box.delete(qId);
          // 用雲端 ID 重新儲存，並標記為已同步
          mistakeData['is_sync'] = true;
          await box.put(cloudId, mistakeData);
          print("錯題 $qId 同步成功，更新為雲端 ID: $cloudId");
        } else {
          // 如果 ID 相同或沒有雲端 ID，只更新同步狀態
          mistakeData['is_sync'] = true;
          await box.put(qId, mistakeData);
          print("錯題 $qId 同步成功");
        }
      } else {
        print("錯題 $qId 同步失敗：狀態碼 ${response.statusCode}");
      }
    } catch (e) {
      print("錯題 $qId 同步錯誤: $e");
    }
  }

  // 從雲端同步錯題資料到本地Hive
  Future<void> _syncMistakesFromCloud() async {
    try {
      // 顯示載入中對話框
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Color(0xFF102031),
            content: Row(
              children: [
                CircularProgressIndicator(color: Colors.blue),
                SizedBox(width: 20),
                Text('同步中...', style: TextStyle(color: Colors.white)),
              ],
            ),
          );
        },
      );

      final response = await http.get(Uri.parse(
          'https://superb-backend-1041765261654.asia-east1.run.app/mistake-book/'));

      Navigator.pop(context); // 關閉載入對話框

      if (response.statusCode == 200) {
        final cloudMistakes =
            (jsonDecode(utf8.decode(response.bodyBytes)) as List)
                .map((mistake) => Map<String, dynamic>.from(mistake))
                .toList();

        // 開啟Hive box並更新資料
        var box = await Hive.openBox('questionsBox');

        for (var cloudMistake in cloudMistakes) {
          await box.put(cloudMistake['id'].toString(), {
            'summary': cloudMistake['summary'] ?? '',
            'subject': cloudMistake['subject'] ?? '',
            'chapter': cloudMistake['chapter'] ?? '',
            'description': cloudMistake['description'] ?? '',
            'difficulty': cloudMistake['difficulty'] ?? 'Medium',
            'answer': cloudMistake['answer'] ?? '',
            'tag': cloudMistake['tag'] ?? '',
            'note': cloudMistake['note'] ?? '', // 給自己的小提醒
            'created_at':
                cloudMistake['created_at'] ?? DateTime.now().toIso8601String(),
            // 同步時使用新的分離圖片欄位
            'question_image_base64':
                cloudMistake['question_image_base64'] ?? '',
            'answer_image_base64': cloudMistake['answer_image_base64'] ?? '',
            // 保留舊欄位以向後相容
            'image_base64': cloudMistake['question_image_base64'] ?? '',
            'is_sync': true, // 從雲端同步的資料標記為已同步
          });
        }

        // 重新載入本地資料
        await _reloadLocalMistakes();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('同步完成！已更新 ${cloudMistakes.length} 筆錯題'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('同步失敗：狀態碼 ${response.statusCode}');
      }
    } catch (e) {
      Navigator.pop(context); // 確保關閉載入對話框
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('同步錯誤: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Function to filter mistakes based on search query and selected subject
  void _filterMistakes() {
    setState(() {
      _filteredMistakes = _mistakes.where((mistake) {
        bool matchesSearch = _searchQuery.isEmpty ||
            mistake['q_id'].toString().contains(_searchQuery);
        bool matchesSubject =
            _selectedSubject == "全部" || mistake['subject'] == _selectedSubject;

        return matchesSearch && matchesSubject;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF102031),
      body: Stack(
        children: [
          // Background color and image at top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 240,
            child: Container(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Image positioned below color block
                  Positioned(
                    top: 40,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Image.asset(
                      'assets/images/wrong.png',
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Main content
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Top bar with back button
                Container(
                  height: 56,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Row(
                          children: [
                            Icon(Icons.arrow_back,
                                color: Colors.white, size: 24),
                            SizedBox(width: 4),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            '錯題本',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 24), // 為平衡佈局
                    ],
                  ),
                ),

                // Spacer to push content below the image
                SizedBox(height: 100),

                // Search and filter container with rounded design
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      // Search Bar with improved styling
                      Expanded(
                        child: Container(
                          height: 45,
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.1))),
                          child: TextField(
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                                _filterMistakes();
                              });
                            },
                            decoration: InputDecoration(
                              hintText: "依題號搜尋...",
                              hintStyle: TextStyle(
                                  color: Colors.white70, fontSize: 15),
                              filled: true,
                              fillColor: Colors.transparent,
                              border: InputBorder.none,
                              prefixIcon: Icon(Icons.search,
                                  color: Colors.white70, size: 20),
                              contentPadding:
                                  EdgeInsets.symmetric(vertical: 12),
                            ),
                            style: TextStyle(color: Colors.white, fontSize: 15),
                          ),
                        ),
                      ),

                      SizedBox(width: 12),

                      // Select Dropdown Button with improved styling
                      Container(
                        height: 45,
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade500,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedSubject,
                            borderRadius: BorderRadius.circular(15),
                            dropdownColor: Colors.blue.shade500,
                            icon: Icon(Icons.arrow_drop_down,
                                color: Colors.white),
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600),
                            items: ["全部", "數學", "國文", "自然", "歷史"]
                                .map((subject) => DropdownMenuItem<String>(
                                      value: subject,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(subject,
                                              style: TextStyle(
                                                  color: Colors.white)),
                                        ],
                                      ),
                                    ))
                                .toList(),
                            onChanged: (newValue) {
                              if (newValue != _selectedSubject) {
                                setState(() {
                                  _selectedSubject = newValue!;
                                  _filterMistakes();
                                });
                              }
                            },
                          ),
                        ),
                      ),

                      SizedBox(width: 12),

                      // 同步按鈕
                      Container(
                        height: 45,
                        decoration: BoxDecoration(
                          color: Colors.green.shade500,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(25),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(25),
                            onTap: _syncMistakesFromCloud,
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.sync,
                                      color: Colors.white, size: 20),
                                  SizedBox(width: 4),
                                  Text(
                                    '同步',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Mistakes List with improved card design
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: _filteredMistakes.length,
                    itemBuilder: (context, index) {
                      final mistake = _filteredMistakes[
                          _filteredMistakes.length - index - 1];
                      final Uint8List? imageBytes =
                          mistake['image_base64'] != null &&
                                  mistake['image_base64'].isNotEmpty
                              ? base64Decode(mistake['image_base64'])
                              : null;
                      final currentDate =
                          mistake['created_at']?.split('T')[0] ?? '';
                      final nextDate = (index > 0)
                          ? _filteredMistakes[_filteredMistakes.length - index]
                                      ['created_at']
                                  ?.split('T')[0] ??
                              ''
                          : null;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (index == 0 || currentDate != nextDate)
                            Padding(
                              padding: const EdgeInsets.only(
                                  top: 8.0, bottom: 8.0, left: 4.0),
                              child: Text(
                                currentDate,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade300,
                                ),
                              ),
                            ),
                          Container(
                            margin: EdgeInsets.only(bottom: 12, top: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 10,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () async {
                                  final refreshNeeded = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          MistakeDetailPage(mistake: mistake),
                                    ),
                                  );

                                  // If we got back true, refresh the mistakes list
                                  if (refreshNeeded == true) {
                                    //_loadMistakes();
                                  }
                                },
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              mistake['description'] ??
                                                  mistake['summary'] ??
                                                  '無標題',
                                              style: TextStyle(
                                                color: Color(0xFF102031),
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          // Stars for difficulty
                                          Text(
                                            '★' * _getDifficultyStars(mistake['difficulty']),
                                            style: TextStyle(
                                              color: Color(0xFFFFA368),
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 12),
                                      // Tags with improved design
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          if (mistake['subject'] != '') ...[
                                            _buildChipTag(mistake['subject']),
                                          ],
                                          if (mistake['chapter'] != '') ...[
                                            _buildChipTag(mistake['chapter']),
                                          ],
                                          if (mistake['tag'] != '') ...[
                                            _buildChipTag(mistake['tag']),
                                          ],
                                        ],
                                      ),
                                      SizedBox(height: 12),

                                      // Check for image_base64 and display image if available
                                      if (imageBytes != null) ...[
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: Image.memory(
                                            imageBytes,
                                            height: 80,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ],

                                      // Image preview from cloud run with better error handling
                                      FutureBuilder(
                                        future: http.head(Uri.parse(
                                            'https://superb-backend-1041765261654.asia-east1.run.app/static/${mistake['q_id']}.jpg')),
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState ==
                                              ConnectionState.waiting) {
                                            return SizedBox.shrink();
                                          } else if (snapshot.hasError ||
                                              snapshot.data?.statusCode !=
                                                  200) {
                                            return SizedBox.shrink();
                                          } else {
                                            return ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Image.network(
                                                'https://superb-backend-1041765261654.asia-east1.run.app/static/${mistake['q_id']}.jpg',
                                                height: 80,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Floating Action Button with improved design
          Positioned(
            right: 24,
            bottom: 40,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.shade700.withOpacity(0.4),
                    blurRadius: 15,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: FloatingActionButton(
                heroTag: 'mistake_book_fab',
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AddMistakePage()),
                  );

                  if (result == true) {
                    _reloadLocalMistakes();
                  }
                },
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                elevation: 0,
                child: Icon(Icons.add, size: 28),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildChipTag(String text) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.blue.shade100,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: TextStyle(
            color: Colors.blue.shade800,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class MistakeDetailPage extends StatefulWidget {
  final Map<String, dynamic> mistake;

  const MistakeDetailPage({super.key, required this.mistake});

  @override
  _MistakeDetailPageState createState() => _MistakeDetailPageState();
}

class _MistakeDetailPageState extends State<MistakeDetailPage> {
  // 刪除確認對話框
  Future<void> _showDeleteConfirmationDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Color(0xFF102031),
          title: Text(
            '確認刪除',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            '確定要刪除這道錯題嗎？此操作無法復原。',
            style: TextStyle(color: Colors.white70),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                '取消',
                style: TextStyle(color: Colors.white70),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(
                '刪除',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteMistake();
              },
            ),
          ],
        );
      },
    );
  }

  // 刪除錯題
  Future<void> _deleteMistake() async {
    try {
      // 顯示載入中對話框
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Color(0xFF102031),
            content: Row(
              children: [
                CircularProgressIndicator(color: Colors.blue),
                SizedBox(width: 20),
                Text('刪除中...', style: TextStyle(color: Colors.white)),
              ],
            ),
          );
        },
      );

      String qId = widget.mistake['q_id']?.toString() ?? '';

      // 先從本地 Hive 刪除
      var box = await Hive.openBox('questionsBox');
      await box.delete(qId);

      // 呼叫後端 delete_mistake_book API
      final response = await http.delete(
        Uri.parse(
            'https://superb-backend-1041765261654.asia-east1.run.app/mistake-book/$qId'),
      );

      Navigator.pop(context); // 關閉載入對話框

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('錯題刪除成功！'),
            backgroundColor: Colors.green,
          ),
        );
        // 返回上一頁並告知需要重新載入
        Navigator.pop(context, true);
      } else {
        // 如果雲端刪除失敗，還原本地資料（重新儲存）
        await box.put(qId, {
          'summary': widget.mistake['summary'],
          'subject': widget.mistake['subject'],
          'chapter': widget.mistake['chapter'],
          'description': widget.mistake['description'],
          'difficulty': widget.mistake['difficulty'],
          'answer': widget.mistake['answer'],
          'tag': widget.mistake['tag'],
          'note': widget.mistake['note'],
          'created_at': widget.mistake['created_at'],
          'question_image_base64': widget.mistake['question_image_base64'],
          'answer_image_base64': widget.mistake['answer_image_base64'],
          'is_sync': widget.mistake['is_sync'] ?? false,
        });

        throw Exception('雲端刪除失敗：狀態碼 ${response.statusCode}');
      }
    } catch (e) {
      Navigator.pop(context); // 確保關閉載入對話框
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('刪除錯誤: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF102031),
      appBar: AppBar(
        title: Text('錯題詳情',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            )),
        backgroundColor: Color(0xFF102031),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddMistakePage(
                    isEditMode: true,
                    mistakeToEdit: widget.mistake,
                  ),
                ),
              );

              if (result == true) {
                Navigator.pop(context, true);
              }
            },
            child: Text(
              '編輯',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              await _showDeleteConfirmationDialog();
            },
            child: Text(
              '刪除',
              style: TextStyle(
                color: Colors.red,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Main scrollable content
            SingleChildScrollView(
              padding: EdgeInsets.all(20.0),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question info card at top
                  Container(
                    width: double.infinity,
                    margin: EdgeInsets.only(bottom: 20),
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              widget.mistake['summary'],
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '★' * _getDifficultyStars(widget.mistake['difficulty']),
                              style: TextStyle(
                                color: Color(0xFFFFA368),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (widget.mistake['subject'] != null &&
                                widget.mistake['subject'] != '') ...[
                              _buildChipTag(widget.mistake['subject']),
                            ],
                            if (widget.mistake['chapter'] != null &&
                                widget.mistake['chapter'] != '') ...[
                              _buildChipTag(widget.mistake['chapter']),
                            ],
                            if (widget.mistake['tag'] != null &&
                                widget.mistake['tag'] != '') ...[
                              _buildChipTag(widget.mistake['tag']),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Description section
                  if (widget.mistake['description'] != null) ...[
                    Container(
                      width: double.infinity,
                      margin: EdgeInsets.only(bottom: 20),
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '題目描述',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 12),

                          // Description text
                          Text(
                            widget.mistake['description'],
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              height: 1.5,
                            ),
                          ),

                          // 題目圖片（從 Hive 讀取）
                          if (widget.mistake['question_image_base64'] != null &&
                              widget.mistake['question_image_base64']
                                  .isNotEmpty) ...[
                            Container(
                              margin: EdgeInsets.only(top: 16),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  base64Decode(
                                      widget.mistake['question_image_base64']),
                                  width: double.infinity,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  // Detailed answer section with local state management
                  if (widget.mistake['answer'] != null &&
                      widget.mistake['answer'].isNotEmpty) ...[
                    _DetailedAnswerSection(
                      detailedAnswer: widget.mistake['answer'],
                      answerImageBase64: widget.mistake['answer_image_base64'],
                    ),
                  ],

                  // 給自己的小提醒區域
                  if (widget.mistake['note'] != null &&
                      widget.mistake['note'].isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      margin: EdgeInsets.only(bottom: 20),
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.lightbulb_outline,
                                color: Colors.orange,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                '給自己的小提醒',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Text(
                            widget.mistake['note'],
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Add extra space at the bottom
                  SizedBox(height: 120),
                ],
              ),
            ),

            // Island image at bottom right - fixed position
            Positioned(
              right: -120,
              bottom: -20,
              child: IgnorePointer(
                child: Image.asset(
                  'assets/images/island-mistakedetail.png',
                  width: 700,
                ),
              ),
            ),
            Positioned(
              right: 170,
              bottom: 70,
              child: IgnorePointer(
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.rotationY(3.1416), // flip horizontally
                  child: Image.asset(
                    'assets/images/upset-corgi-1.png',
                    width: 70,
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

// Create a separate stateful widget for the detailed answer section
class _DetailedAnswerSection extends StatefulWidget {
  final String detailedAnswer;
  final String? answerImageBase64;

  const _DetailedAnswerSection({
    required this.detailedAnswer,
    this.answerImageBase64,
  });

  @override
  _DetailedAnswerSectionState createState() => _DetailedAnswerSectionState();
}

class _DetailedAnswerSectionState extends State<_DetailedAnswerSection> {
  bool _showDetailedAnswer = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 20),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with tap gesture
          GestureDetector(
            onTap: () {
              setState(() {
                _showDetailedAnswer = !_showDetailedAnswer;
              });
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '詳細解答',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                AnimatedRotation(
                  duration: Duration(milliseconds: 300),
                  turns: _showDetailedAnswer ? 0.5 : 0,
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.expand_more,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content container with animations
          Container(
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(),
            height: _showDetailedAnswer ? null : 0,
            child: AnimatedOpacity(
              opacity: _showDetailedAnswer ? 1.0 : 0.0,
              duration: Duration(milliseconds: 300),
              child: AnimatedPadding(
                duration: Duration(milliseconds: 300),
                padding: EdgeInsets.only(
                  top: _showDetailedAnswer ? 16 : 0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 詳解文字
                    Text(
                      widget.detailedAnswer,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        height: 1.5,
                      ),
                    ),
                    // 詳解圖片（如果有的話）
                    if (widget.answerImageBase64 != null &&
                        widget.answerImageBase64!.isNotEmpty) ...[
                      Container(
                        margin: EdgeInsets.only(top: 16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            base64Decode(widget.answerImageBase64!),
                            width: double.infinity,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

int _getDifficultyStars(String difficulty) {
  switch (difficulty) {
    case 'Easy':
      return 1;
    case 'Medium':
      return 2;
    case 'Hard':
      return 3;
    default:
      return 0;
  }
}
