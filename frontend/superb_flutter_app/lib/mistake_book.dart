import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MistakeBookPage extends StatefulWidget {
  @override
  _MistakeBookPageState createState() => _MistakeBookPageState();
}

class _MistakeBookPageState extends State<MistakeBookPage> {
  List<Map<String, dynamic>> _mistakes = [];

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
      appBar: AppBar(title: Text('Mistake Book')),
      body: ListView.builder(
        itemCount: _mistakes.length,
        itemBuilder: (context, index) {
          final mistake = _mistakes[index];
          return Card(
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
    );
  }
}

class MistakeDetailPage extends StatelessWidget {
  final Map<String, dynamic> mistake;

  MistakeDetailPage({required this.mistake});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Mistake Details'),
          bottom: TabBar(
            tabs: [
              Tab(text: '題目'),
              Tab(text: '詳解'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(mistake['description'] ?? 'No description available'),
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