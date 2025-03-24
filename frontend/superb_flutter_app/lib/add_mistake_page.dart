// frontend/superb_flutter_app/lib/add_mistake_page.dart
import 'package:flutter/material.dart';

class AddMistakePage extends StatefulWidget {
  @override
  _AddMistakePageState createState() => _AddMistakePageState();
}

class _AddMistakePageState extends State<AddMistakePage> {
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _simpleAnswerController = TextEditingController();
  final TextEditingController _detailedAnswerController = TextEditingController();

  String _selectedTag = "A"; // Default selection for answer options

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('新增錯題'),
        actions: [
          TextButton(
            onPressed: () {
              // TODO: Submit the data to the backend
              // Call the /submit_question endpoint with the collected data
            },
            child: Text('Submit', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close the page
            },
            child: Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 題目部分
            Text('題目', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            TextField(
              controller: _questionController,
              decoration: InputDecoration(labelText: '輸入題目'),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: () {
                    // TODO: Open camera
                  },
                  child: Text('打開相機'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // TODO: Open gallery
                  },
                  child: Text('從相簿中選擇'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // TODO: Generate summary
                  },
                  child: Text('生成摘要'),
                ),
              ],
            ),

            SizedBox(height: 20),

            // 解答部分
            Text('解答', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Row(
              children: [
                DropdownButton<String>(
                  value: _selectedTag,
                  items: ['A', 'B', 'C', 'D'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _selectedTag = newValue!;
                    });
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _simpleAnswerController,
                    decoration: InputDecoration(labelText: '簡答'),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: () {
                    // TODO: Open camera
                  },
                  child: Text('打開相機'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // TODO: Open gallery
                  },
                  child: Text('從相簿中選擇'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // TODO: Generate answer
                  },
                  child: Text('生成回答'),
                ),
              ],
            ),
            TextField(
              controller: _detailedAnswerController,
              decoration: InputDecoration(labelText: '詳解'),
            ),
          ],
        ),
      ),
    );
  }
}