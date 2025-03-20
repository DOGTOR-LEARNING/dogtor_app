import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_markdown_latex/flutter_markdown_latex.dart';
import 'package:markdown/markdown.dart' as md;

class MistakeBookPage extends StatefulWidget {
  @override
  _MistakeBookPageState createState() => _MistakeBookPageState();
}

class _MistakeBookPageState extends State<MistakeBookPage> {
  List<Map<String, dynamic>> _mistakes = [];
  List<Map<String, dynamic>> _filteredMistakes = [];
  String _searchQuery = "";
  String _selectedSubject = "All"; // Default selection

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
        bool matchesSubject = _selectedSubject == "All" ||
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
                padding: const EdgeInsets.all(16.0),
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
                          hintStyle: TextStyle(color: Colors.white54),
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
                    SizedBox(width: 10), // Space between elements

                    // Select Dropdown Button
                    DropdownButton<String>(
                      value: _selectedSubject,
                      dropdownColor: Color(0xFF1A2B3C), // Dark dropdown background
                      style: TextStyle(color: Colors.white), // Dropdown text color
                      icon: Icon(Icons.arrow_drop_down, color: Colors.white),
                      items: ["All", "Math", "Science", "English", "History"]
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
                  ],
                ),
              ),

              // Mistakes List
              Expanded(
                child: ListView.builder(
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
                            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                            child: Text(
                              currentDate,
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF42A5F5)),
                            ),
                          ),
                        Card(
                          color: Color(0xFF102031),
                          child: ListTile(
                            title: Text('題目編號: ${mistake['q_id']}', style: TextStyle(color: Colors.white)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('科目: ${mistake['subject']}', style: TextStyle(color: Colors.white70)),
                                Text('章節: ${mistake['chapter']}', style: TextStyle(color: Colors.white70)),
                                Text('難度: ${'★' * _getDifficultyStars(mistake['difficulty'])}', style: TextStyle(color: Colors.white70)),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MistakeDetailPage(mistake: mistake),
                                ),
                              );
                            },
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

class MistakeDetailPage extends StatelessWidget {
  final Map<String, dynamic> mistake;

  MistakeDetailPage({required this.mistake});

  // Function to check if the image exists
  Future<bool> _checkImageExistence(mistake) async {
    final url = 'http://127.0.0.1:8000/static/${mistake['q_id']}.jpg';

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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Mistake Details'),
          backgroundColor: Color(0xFF102031),
          bottom: TabBar(
            tabs: [
              Tab(text: '題目'),
              Tab(text: '詳解'),
            ],
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
          ),
        ),
        body: TabBarView(
          children: [
            // 題目頁面
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: FutureBuilder<bool>(
                future: _checkImageExistence(mistake),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return CircularProgressIndicator();
                  } else if (snapshot.hasError) {
                    return Text('Error loading image');
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
            
            // 詳解頁面 - 使用 Markdown 和 LaTeX 支援
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Markdown(
                selectable: true,
                data: mistake['detailed_answer'] ?? 'No detailed answer available',
                builders: {
                  'latex': LatexElementBuilder(
                    textStyle: Theme.of(context).textTheme.bodyLarge!,
                    textScaleFactor: 1.1,
                  ),
                },
                extensionSet: md.ExtensionSet(
                  [LatexBlockSyntax()],
                  [LatexInlineSyntax()],
                ),
              ),
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