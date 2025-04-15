import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'add_mistake_page.dart';

import 'package:hive/hive.dart';
import 'dart:typed_data';


class MistakeBookPage extends StatefulWidget {
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
    _loadMistakes();
    //_loadLocalMistakes();
  }

  // Load added mistakes from Hive
  Future<void> _reloadLocalMistakes() async {
    try {
      var box = await Hive.openBox('questionsBox'); // 打開 Hive Box
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
          'simple_answer': value['simple_answer'],
          'detailed_answer': value['detailed_answer'],
          'tag': value['tag'],
          'timestamp': value['timestamp'],
          "image_base64": value['image_base64'],
        });
      });

      setState(() {
        _mistakes = localMistakes; // 更新錯題列表
        _filteredMistakes = _mistakes; // 初始顯示所有錯題
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading local mistakes: $e')),
      );
    }
  }

  // Load mistakes from cloud sql
  Future<void> _loadMistakes() async {
    try {
      final response = await http.get(Uri.parse('https://superb-backend-1041765261654.asia-east1.run.app/mistake_book'));
      if (response.statusCode == 200) {
        setState(() {
          _mistakes = (jsonDecode(utf8.decode(response.bodyBytes)) as List)
              .map((mistake) => Map<String, dynamic>.from(mistake))
              .toList();
          _filteredMistakes = _mistakes; // Initially show all mistakes
          print("hi from load mistakes");
          //print(len(_mistakes));
          print(_mistakes[5]);
        });
      } else {
        throw Exception('Failed to load mistakes');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading mistakes: $e')),
      );
    }
  }

  // Function to filter mistakes based on search query and selected subject
  void _filterMistakes() {
    setState(() {
      _filteredMistakes = _mistakes.where((mistake) {
        bool matchesSearch = _searchQuery.isEmpty ||
            mistake['q_id'].toString().contains(_searchQuery);
        bool matchesSubject = _selectedSubject == "全部" ||
            mistake['subject'] == _selectedSubject;

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
                            Icon(Icons.arrow_back, color: Colors.white, size: 24),
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
                            border: Border.all(color: Colors.white.withOpacity(0.1))
                          ),
                          child: TextField(
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                                _filterMistakes();
                              });
                            },
                            decoration: InputDecoration(
                              hintText: "依題號搜尋...",
                              hintStyle: TextStyle(color: Colors.white70, fontSize: 15),
                              filled: true,
                              fillColor: Colors.transparent,
                              border: InputBorder.none,
                              prefixIcon: Icon(Icons.search, color: Colors.white70, size: 20),
                              contentPadding: EdgeInsets.symmetric(vertical: 12),
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
                            icon: Icon(Icons.arrow_drop_down, color: Colors.white),
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                            items: ["全部", "數學", "國文", "理化", "歷史"]
                                .map((subject) => DropdownMenuItem<String>(
                                      value: subject,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(subject, style: TextStyle(color: Colors.white)),
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
                    ],
                  ),
                ),

                // Mistakes List with improved card design
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: _filteredMistakes.length,
                    itemBuilder: (context, index) {
                      final mistake = _filteredMistakes[_filteredMistakes.length - index - 1];
                      final Uint8List? imageBytes = mistake['image_base64'] != null && mistake['image_base64'].isNotEmpty
                          ? base64Decode(mistake['image_base64'])
                          : null;
                      final currentDate = mistake['timestamp'].split('T')[0];
                      final nextDate = (index > 0)
                          ? _filteredMistakes[_filteredMistakes.length - index]['timestamp'].split('T')[0]
                          : null;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          
                          if (index == 0 || currentDate != nextDate)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0, bottom: 8.0, left: 4.0),
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
                                      builder: (context) => MistakeDetailPage(mistake: mistake),
                                    ),
                                  );
                                  
                                  // If we got back true, refresh the mistakes list
                                  if (refreshNeeded == true) {
                                    _loadMistakes();
                                  }
                                },
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            mistake['q_id'],
                                            style: TextStyle(
                                              color: Color(0xFF102031),
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          // Stars for difficulty
                                          Text(
                                            '${'★' * _getDifficultyStars(mistake['difficulty'])}',
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
                                          if(mistake['subject'] != '')...[
                                            _buildChipTag(mistake['subject']),
                                          ],
                                          if(mistake['chapter'] != '')...[
                                            _buildChipTag(mistake['chapter']),
                                          ],
                                          if(mistake['tag'] != '')...[
                                            _buildChipTag(mistake['tag']),
                                          ],
                                        ],
                                      ),
                                      SizedBox(height: 12),

                                      // Check for image_base64 and display image if available
                                      if (imageBytes != null) ...[
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
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
                                        future: http.head(Uri.parse('https://superb-backend-1041765261654.asia-east1.run.app/static/${mistake['q_id']}.jpg')),
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState == ConnectionState.waiting) {
                                            return SizedBox.shrink();
                                          } else if (snapshot.hasError || snapshot.data?.statusCode != 200) {
                                            return SizedBox.shrink();
                                          } else {
                                            return ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
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

  MistakeDetailPage({required this.mistake});

  @override
  _MistakeDetailPageState createState() => _MistakeDetailPageState();
}

class _MistakeDetailPageState extends State<MistakeDetailPage> {
  bool _showDetailedAnswer = false;

  Future<bool> _checkImageExistence(mistake) async {
    final url = 'https://superb-backend-1041765261654.asia-east1.run.app/static/${mistake['q_id']}.jpg';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF102031),
      appBar: AppBar(
        title: Text('錯題詳情', style: TextStyle(
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
        ],
      ),
      body: Container(
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
                              '${'★' * _getDifficultyStars(widget.mistake['difficulty'])}',
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
                            if(widget.mistake['subject'] != '')...[
                              _buildChipTag(widget.mistake['subject']),
                            ],
                            if(widget.mistake['chapter'] != '')...[
                              _buildChipTag(widget.mistake['chapter']),
                            ],
                            if(widget.mistake['tags'] != null)...[
                              _buildChipTag(widget.mistake['tags']),
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
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
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
                          
                          // Image inside the description section
                          FutureBuilder<bool>(
                            future: _checkImageExistence(widget.mistake),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return Center(
                                  child: Container(
                                    height: 60,
                                    child: CircularProgressIndicator(color: Colors.white),
                                  )
                                );
                              } else if (snapshot.hasError || snapshot.data != true) {
                                return SizedBox.shrink(); // No image to display
                              } else {
                                return Container(
                                  margin: EdgeInsets.only(bottom: 16),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      'https://superb-backend-1041765261654.asia-east1.run.app/static/${widget.mistake['q_id']}.jpg',
                                      width: double.infinity,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                          
                          // Description text
                          Text(
                            widget.mistake['description'],
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

                  // Detailed answer section with local state management
                  if (widget.mistake['detailed_answer'] != null) ...[
                    _DetailedAnswerSection(
                      detailedAnswer: widget.mistake['detailed_answer'],
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

  _DetailedAnswerSection({required this.detailedAnswer});

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
                child: Text(
                  widget.detailedAnswer,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    height: 1.5,
                  ),
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
