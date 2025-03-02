import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MistakeBookPage extends StatefulWidget {
  @override
  _MistakeBookPageState createState() => _MistakeBookPageState();
}

class _MistakeBookPageState extends State<MistakeBookPage> {
  List<Map<String, dynamic>> _mistakes = []; // This should be fetched from the backend
  String? _selectedSubject;
  String? _selectedChapter;

  @override
  void initState() {
    super.initState();
    _loadMistakes();
  }

  Future<void> _loadMistakes() async {
    try {
      final response = await http.get(Uri.parse('http://127.0.0.1:8000/mistakes'));
      if (response.statusCode == 200) {
        setState(() {
          _mistakes = List<Map<String, dynamic>>.from(jsonDecode(response.body));
        });
      } else {
        throw Exception('無法載入錯題');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('載入錯誤：$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Mistake Book')),
      body: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  value: _selectedSubject,
                  items: ['Math', 'Science'].map((String subject) {
                    return DropdownMenuItem<String>(
                      value: subject,
                      child: Text(subject),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedSubject = newValue;
                    });
                  },
                  hint: Text('Select Subject'),
                ),
              ),
              Expanded(
                child: DropdownButton<String>(
                  value: _selectedChapter,
                  items: ['Chapter 1', 'Chapter 2'].map((String chapter) {
                    return DropdownMenuItem<String>(
                      value: chapter,
                      child: Text(chapter),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedChapter = newValue;
                    });
                  },
                  hint: Text('Select Chapter'),
                ),
              ),
            ],
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _mistakes.length,
              itemBuilder: (context, index) {
                final mistake = _mistakes[index];
                return GestureDetector(
                  onLongPress: () {
                    // Show options for star or delete
                  },
                  child: Card(
                    child: ListTile(
                      title: Text(mistake['title']),
                      subtitle: Text(mistake['description']),
                      onTap: () {
                        // Navigate to detailed view
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Handle image upload
        },
        child: Icon(Icons.camera_alt),
      ),
    );
  }
} 