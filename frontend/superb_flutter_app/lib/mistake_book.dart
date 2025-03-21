import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

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
      final response = await http.get(Uri.parse('http://127.0.0.1:8000/mistake_book'));
      if (response.statusCode == 200) {
        setState(() {
          _mistakes = (jsonDecode(utf8.decode(response.bodyBytes)) as List)
              .map((mistake) => Map<String, dynamic>.from(mistake))
              .toList();
          _filteredMistakes = _mistakes; // Initially show all mistakes
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
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 77, 210, 247)),
                            ),
                          ),
                        
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5), // Reduce space between cards
                            child: Card(
                              elevation: 20,
                              color: Color.fromARGB(192, 0, 0, 0),
                              margin: EdgeInsets.zero, // Remove default card margins
                              child: ListTile(
                                visualDensity: VisualDensity.compact, // Make ListTile more compact
                                title: Text('題目編號: ${mistake['q_id']}', style: TextStyle(color: Colors.white)),
                                
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
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
                                      future: http.head(Uri.parse('http://127.0.0.1:8000/static/${mistake['q_id']}.jpg')),
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
                                              'http://127.0.0.1:8000/static/${mistake['q_id']}.jpg', // Image URL
                                              height: 60, // Thumbnail size
                                              width: double.infinity,
                                              fit: BoxFit.cover, // Adjust image size
                                            ),
                                          );
                                        }
                                      },
                                    ),
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
          print('Floating Action Button Pressed');
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
      color: Colors.blueGrey[800], // Dark background
      borderRadius: BorderRadius.circular(8), // Rounded corners
    ),
    child: Text(
      text,
      style: TextStyle(color: Colors.white, fontSize: 14),
    ),
  );
}


class MistakeDetailPage extends StatelessWidget {
  final Map<String, dynamic> mistake;

  MistakeDetailPage({required this.mistake}); //傳遞參數

  // Function to check if the image exists
  Future<bool> _checkImageExistence(mistake) async {
    final url = 'http://127.0.0.1:8000/static/${mistake['q_id']}.jpg';

    try {
      final response = await http.get(Uri.parse(url)); // 發送 GET 請求
      if (response.statusCode == 200) {
        return true; // 如果狀態碼是 200，則返回 true
      } else {
        return false; // 如果狀態碼不是 200，則返回 false
      }
    } catch (e) {
      return false; // 如果發生錯誤，返回 false
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Mis Color(0xFF102031)take Details'),
          backgroundColor: Color(0xFF102031),
          bottom: TabBar(
            tabs: [
              Tab(text: '題目'),
              Tab(text: '詳解'),
            ],
            labelColor: Colors.white, // Set the selected tab text color to white
            unselectedLabelColor: Colors.white70, // Set the unselected tab text color to a lighter white
          ),
        ),
        body: TabBarView(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: FutureBuilder<bool>(
                future: _checkImageExistence(mistake),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return CircularProgressIndicator(); // Show a loading indicator while waiting
                  } else if (snapshot.hasError) {
                    return Text('Error loading image'); // Handle error
                  } else if (snapshot.data == true) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Image.network('http://127.0.0.1:8000/static/${mistake['q_id']}.jpg'),
                        SizedBox(height: 10),
                        Text(mistake['description'] ?? 'No description available'),
                      ],
                    );
                  } else {
                    return Text(mistake['description'] ?? 'No description available');
                  }
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(mistake['detailed_answer'] ?? 'No detailed answer available'),
            ),
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
