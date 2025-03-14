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
  //bool _imageExists = false;
  //String _imageUrl = "";

  @override
  void initState() {
    super.initState();
    _loadMistakes();
  }

  Future<void> _loadMistakes() async {
    try {
      final response = await http.get(Uri.parse('http://127.0.0.1:8000/mistake_book'));
      if (response.statusCode == 200) {
        print(response);
        // _mistakes = List<Map<String, dynamic>>.from(jsonDecode(response.body));

        setState(() {
          _mistakes = (jsonDecode(utf8.decode(response.bodyBytes)) as List)
          //_mistakes = (jsonDecode(response.body) as List)
              .map((mistake) => Map<String, dynamic>.from(mistake))
              .toList();
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

  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //appBar: AppBar(title: Text('Mistake Book')),
      backgroundColor: Color(0xFF102031), // Set the background color here
      body: Stack(
        children: [
          Column(
            children: [
              Image.asset(
                'assets/images/wrong.png', // Replace with your image path
                //fit: BoxFit.cover,
                //width: double.infinity,
                //height: 200, // Adjust height as needed
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _mistakes.length,
                  itemBuilder: (context, index) {
                    final mistake = _mistakes[index];
                    return Card(
                      color: Color(0xFF102031),
                      child: ListTile(
                        title: Text('題目編號: ${mistake['q_id']}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('加入時間: ${mistake['timestamp']}'),
                            Text('章節: ${mistake['chapter']}'),
                            Text('難度: ${'★' * _getDifficultyStars(mistake['difficulty'])}'),
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
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
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
          title: Text('Mistake Details'),
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