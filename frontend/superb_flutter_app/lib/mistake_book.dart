import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'add_mistake_page.dart';

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
  }

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
          print(_mistakes);
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
                  // Color block above image
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 40,
                      color: Color.fromRGBO(99, 158, 171, 1),
                      width: double.infinity,
                    ),
                  ),
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
                            Icon(Icons.arrow_back, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text(
                              "返回",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Spacer to push content below the image
                SizedBox(height: 100),
                
                // Search and filter container
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    children: [
                      // Search Bar
                      Expanded(
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: TextField(
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                                _filterMistakes();
                              });
                            },
                            decoration: InputDecoration(
                              hintText: "Search by ID...",
                              hintStyle: TextStyle(color: Colors.white54, fontSize: 15),
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

                      // Select Dropdown Button (Styled like a chip)
                      Container(
                        height: 45,
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: Color(0xFF8BB7E0),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedSubject,
                            borderRadius: BorderRadius.circular(12),
                            dropdownColor: Color(0xFF8BB7E0),
                            icon: Icon(Icons.arrow_drop_down, color: Color(0xFF102031)),
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            style: TextStyle(color:Color(0xFF102031), fontSize: 15),
                            items: ["全部", "數學", "國文", "理化", "歷史"]
                                .map((subject) => DropdownMenuItem<String>(
                                      value: subject,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(subject, style: TextStyle(color: Color(0xFF102031))),
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
                      Container(
                        height: 45,
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color:Color.fromARGB(255, 255, 169, 30) ,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedSubject,
                            borderRadius: BorderRadius.circular(12),
                            dropdownColor:  Color.fromARGB(255, 255, 169, 30) ,
                            icon: Icon(Icons.arrow_drop_down, color: Color(0xFF102031)),
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            style: TextStyle(color:Color(0xFF102031), fontSize: 15),
                            items: ["全部", "數學", "國文", "理化", "歷史"]
                                .map((subject) => DropdownMenuItem<String>(
                                      value: subject,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(subject, style: TextStyle(color: Color(0xFF102031))),
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

                // Mistakes List 
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _filteredMistakes.length,
                    itemBuilder: (context, index) {
                      final mistake = _filteredMistakes[_filteredMistakes.length - index - 1];
                      final currentDate = mistake['timestamp'].split('T')[0];
                      final previousDate = (index < _filteredMistakes.length - 1)
                          ? _filteredMistakes[_filteredMistakes.length - index - 2]['timestamp'].split('T')[0]
                          : null;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (index == 0 || currentDate != previousDate)
                            Padding(
                              padding: const EdgeInsets.only(top: 16.0, bottom: 8.0, left: 4.0),
                              child: Text(
                                currentDate,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'Medium',
                                  color: Color.fromARGB(234, 68, 154, 228),
                                ),
                              ),
                            ),
                          
                          Container(
                            margin: EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 244, 243, 243),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => MistakeDetailPage(mistake: mistake),
                                    ),
                                  );
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
                                            '題目編號: ${mistake['q_id']}',
                                            style: TextStyle(
                                              color: Color(0xFF102031),
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Icon(
                                            Icons.arrow_forward_ios,
                                            color: Colors.white60,
                                            size: 16,
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 12),
                                      // Tags with modern design
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _buildChipTag(mistake['subject']),
                                          _buildChipTag(mistake['chapter']),
                                          _buildChipTag('${'★' * _getDifficultyStars(mistake['difficulty'])}'),
                                        ],
                                      ),
                                      SizedBox(height: 12),
                                      // Preview with rounded corners
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
                                                height: 120,
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

          // Floating Action Button 
          Positioned(
            right: 24,
            bottom: 40,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF1E3875).withOpacity(0.3),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: FloatingActionButton(
                heroTag: 'mistake_book_fab',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AddMistakePage()),
                  );
                },
                backgroundColor: Color(0xFF1E3875),
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
        color: Color(0xFF8BB7E0),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: TextStyle(
              color:  Color(0xFF102031),
              fontSize: 13,
              fontWeight: FontWeight.w500,
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
        title: Text('錯題詳情', style: TextStyle(fontSize: 18)),
        backgroundColor: Color.fromRGBO(99, 158, 171, 1),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
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
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '題目編號: ${widget.mistake['q_id']}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            _buildChipTag(widget.mistake['subject']),
                            SizedBox(width: 8),
                            _buildChipTag(widget.mistake['chapter']),
                            SizedBox(width: 8),
                            _buildChipTag('${'★' * _getDifficultyStars(widget.mistake['difficulty'])}'),
                          ],
                        ),
                      ],
                    ),
                  ),

                  FutureBuilder<bool>(
                    future: _checkImageExistence(widget.mistake),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator(color: Colors.white));
                      } else if (snapshot.hasError) {
                        return Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text('Error loading image', style: TextStyle(color: Colors.white)),
                        );
                      } else if (snapshot.data == true) {
                        return Container(
                          margin: EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              'https://superb-backend-1041765261654.asia-east1.run.app/static/${widget.mistake['q_id']}.jpg',
                              width: double.infinity,
                              fit: BoxFit.contain,
                            ),
                          ),
                        );
                      }
                      return SizedBox.shrink();
                    },
                  ),

                  if (widget.mistake['description'] != null) ...[
                    Container(
                      width: double.infinity,
                      margin: EdgeInsets.only(bottom: 20),
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
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

                  if (widget.mistake['detailed_answer'] != null) ...[
                    Container(
                      width: double.infinity,
                      margin: EdgeInsets.only(bottom: 20),
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                                  child: Icon(
                                    Icons.expand_more,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ClipRect(
                            child: AnimatedSize(
                              duration: Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              child: Container(
                                height: _showDetailedAnswer ? null : 0,
                                child: Padding(
                                  padding: EdgeInsets.only(top: 16),
                                  child: Text(
                                    widget.mistake['detailed_answer'],
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ),
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

  // Modern chip-style tag for detail page

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
