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
          Column(
            children: [
              // Image at the Top
              Image.asset(
                'assets/images/wrong.png', // Keep original image at the top
              ),

              // Search Bar and Select Dropdown
              Padding(
                padding: EdgeInsets.only(left: 20, right: 20, top: 0, bottom: 20),
                child: Row(
                  children: [
                    // Search Bar
                    Expanded(

                      child: TextField(
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                            _filterMistakes();
                          });
                        },
                        decoration: InputDecoration(
                          hintText: "Search by ID...",
                          hintStyle: TextStyle(color: Colors.white54,fontSize:16),
                          filled: true,
                          fillColor: Colors.white10,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: Icon(Icons.search, color: Colors.white),
                          contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 16), 
                        ),
                        style: TextStyle(color: Colors.white),
                      ),
                    ),

                    SizedBox(width: 20), // Space between elements

                    // Select Dropdown Button
                    Container(
                      height: 50, // Set height
                      width: 80, // Set width
                      padding: EdgeInsets.symmetric(horizontal: 10), // Add padding inside the button
                      decoration: BoxDecoration(
                        color: Color(0xFF1A2B3C), // Dark background
                        borderRadius: BorderRadius.circular(10), // Rounded corners
                      ),
                      child: DropdownButtonHideUnderline( // Removes default underline
                        child: DropdownButton<String>(
                          value: _selectedSubject,
                          borderRadius: BorderRadius.circular(10),
                          dropdownColor: Color(0xFF1A2B3C), // Dark dropdown background
                          style: TextStyle(color: Colors.white, fontSize: 16), // Adjust font size
                          icon: Icon(Icons.arrow_drop_down, color: Colors.white),
                          items: ["全部", "數學", "國文", "理化", "歷史"]
                              .map((subject) => DropdownMenuItem<String>(
                                    value: subject,
                                    child: Text(subject, style: TextStyle(color: Colors.white)),
                                  ))
                              .toList(),
                          onChanged: (newValue) {
                            setState(() {
                              _selectedSubject = newValue!;
                              _filterMistakes();
                            });
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
                  padding: EdgeInsets.only(top: 4, left: 6, right: 6), 
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
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0), // Reduce date spacing
                            child: Text(
                              currentDate,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Medium', color: Color.fromARGB(234, 68, 154, 228)),
                            ),
                          ),
                        
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5), // Reduce space between cards
                            child: Card(
                              elevation: 20,
                              color:  Colors.white10,
                              margin: EdgeInsets.zero, // Remove default card margins
                              child: ListTile(
                                visualDensity: VisualDensity.compact, // Make ListTile more compact
                                title: Text('題目編號: ${mistake['q_id']}', style: TextStyle( fontFamily: 'Medium',color: const Color.fromARGB(255, 255, 255, 255))),
                                
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8, // Horizontal space between tags
                                      runSpacing: 10, // Vertical space if it wraps
                                      children: [
                                        _buildTag('${mistake['subject']}'),
                                        _buildTag('${mistake['chapter']}'),
                                        _buildTag('${'★' * _getDifficultyStars(mistake['difficulty'])}'),
                                      ],
                                    ),
                                    SizedBox(height: 10), // Space before preview
                                    FutureBuilder(
                                      future: http.head(Uri.parse('https://superb-backend-1041765261654.asia-east1.run.app/static/${mistake['q_id']}.jpg')),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState == ConnectionState.waiting) {
                                          return SizedBox.shrink(); // Don't show anything while loading
                                        } else if (snapshot.hasError || snapshot.data?.statusCode != 200) {
                                          return Text(
                                            mistake['description'] != null
                                                ? mistake['description'].length > 50
                                                    ? '${mistake['description'].substring(0, 50)}...' // Show first 50 characters
                                                    : mistake['description'] // Show full text if short
                                                : 'No detailed explanation available',
                                            style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          );
                                        } else {
                                          return ClipRRect(
                                            borderRadius: BorderRadius.circular(8), // Rounded corners for preview
                                            child: Image.network(
                                              'https://superb-backend-1041765261654.asia-east1.run.app/static/${mistake['q_id']}.jpg', // Image URL
                                              height: 60, // Thumbnail size
                                              width: double.infinity,
                                              fit: BoxFit.cover, // Adjust image size
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                    SizedBox(height: 5),
                                  ],
                                ),onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => MistakeDetailPage(mistake: mistake),
                                    ),
                                  );
                                },
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

          // "X" Button at the Top-Left Corner
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              icon: Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),

      // Floating Action Button
      floatingActionButton: FloatingActionButton(
        heroTag: 'mistake_book_fab',
        onPressed: () {
          print('Add Mistake Button Pressed');
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddMistakePage()), // 導航到新增錯題頁面
          );
        },
        backgroundColor: Colors.blue,
        child: Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

Widget _buildTag(String text) {
  return Container(
    width: text.length * 17 + 6, // Set a fixed width if needed (optional)
    height: 22,
    padding: EdgeInsets.symmetric(vertical: 0, horizontal: 5), // Padding inside the tag
    decoration: BoxDecoration(
      color: const Color.fromARGB(202, 95, 123, 138), // Dark background
      borderRadius: BorderRadius.circular(8), // Rounded corners
    ),
    child: Text(
      text,
      style: TextStyle(color: const Color.fromARGB(255, 255, 255, 255), fontSize: 14),
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
        title: Text('錯題詳情'),
        backgroundColor: Color(0xFF102031),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<bool>(
              future: _checkImageExistence(widget.mistake),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Text('Error loading image', style: TextStyle(color: Colors.white));
                } else if (snapshot.data == true) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          'https://superb-backend-1041765261654.asia-east1.run.app/static/${widget.mistake['q_id']}.jpg',
                          width: double.infinity,
                          fit: BoxFit.contain,
                        ),
                      ),
                      SizedBox(height: 20),
                    ],
                  );
                }
                return SizedBox.shrink();
              },
            ),
            if (widget.mistake['description'] != null) ...[
              Text(
                '題目描述',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 8),
              Text(
                widget.mistake['description'],
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 24),
            ],
            if (widget.mistake['detailed_answer'] != null) ...[
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showDetailedAnswer = !_showDetailedAnswer;
                  });
                },
                child: Row(
                  children: [
                    Text(
                      '詳細解答',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8),
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
                      padding: EdgeInsets.only(top: 8),
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
          ],
        ),
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
      return 0; // Default case if difficulty is not recognized
  }
}
