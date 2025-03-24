// frontend/superb_flutter_app/lib/add_mistake_page.dart
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import 'dart:typed_data';
import 'dart:html' as html; // Flutter Web only

class AddMistakePage extends StatefulWidget {
  @override
  _AddMistakePageState createState() => _AddMistakePageState();
}

class _AddMistakePageState extends State<AddMistakePage> {
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  final TextEditingController _detailedAnswerController = TextEditingController();

  String _selectedTag = "A"; // Default selection for answer options
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage; // 用於存儲選擇的圖片
  String _response = ""; // 存儲 AI 的回應
  Uint8List? _imageBytes; // for web //late變數型態
  bool _isLoading = false; // 加載狀態
  
  Future<void> _submitData() async {
    setState(() {
      _isLoading = true; // 開始加載
    });

    // 構建請求體
    final Map<String, dynamic> requestBody = {
      "summary": _questionController.text,
      "description": _questionController.text,
      "simple_answer": _selectedTag,
      "detailed_answer": _detailedAnswerController.text,
      "tag": _selectedTag,
    };

    try {
      final response = await http.post(
        Uri.parse("https://superb-backend-1041765261654.asia-east1.run.app/submit_question"),
        headers: {"Content-Type": "application/json; charset=UTF-8"},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}\nBody: ${response.body}');
      }

      final responseData = jsonDecode(utf8.decode(response.bodyBytes));
      setState(() {
        _response = responseData["response"] ?? "No response";
        _isLoading = false; // 停止加載
      });
    } catch (e) {
      setState(() {
        _response = "Error: $e";
        _isLoading = false; // 停止加載
      });
      print("Detailed error: $e");
    }
  }

  Future<void> _generateAnswer() async {
    /*
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('請選擇一張圖片')),
      );
      return;
    }
    */

    setState(() {
      _isLoading = true; // 開始加載
    });

    try {
      // 將選擇的圖片轉換為 Base64 編碼
      //final bytes = await _selectedImage!.readAsBytes();
      //final base64Image = base64Encode(bytes);
      
      final base64Image = base64Encode(_imageBytes!);

      // 構建請求體
      final Map<String, dynamic> requestBody = {
        "image_base64": base64Image,
        "question": _questionController.text,
        // 可以根據需要添加其他字段
      };

      final response = await http.post(
        Uri.parse("https://superb-backend-1041765261654.asia-east1.run.app/summarize"),
        headers: {"Content-Type": "application/json; charset=UTF-8"},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}\nBody: ${response.body}');
      }

      final responseData = jsonDecode(utf8.decode(response.bodyBytes));
      setState(() {
        _response = responseData["response"] ?? "No response";
        _isLoading = false; // 停止加載
      }
      );
      print(_response);
    } catch (e) {
      setState(() {
        _response = "Error: $e";
        _isLoading = false; // 停止加載
      });
      print("Detailed error: $e");
    }
  }

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
                  onPressed: () async {
                    // 打開相機
                    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
                    if (image != null) {
                      setState(() {
                        _selectedImage = image; // 存儲選擇的圖片
                      });
                    }
                  },
                  child: Text('打開相機'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                    if (image != null) {
                      final bytes = await image.readAsBytes();  // ✅ 可跨平台 Web/iOS/Android
                      setState(() {
                        _imageBytes = bytes;
                      });
                    }
                  },
                  child: Text("從相簿中選擇"),
                ),
                /*
                ElevatedButton(
                  onPressed: () async {
                    // 從相簿中選擇
                    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                    if (image != null) {
                      setState(() {
                        _selectedImage = image; // 存儲選擇的圖片
                      });
                    }
                  },
                  child: Text('從相簿中選擇'),
                ),
                */
                ElevatedButton(
                  onPressed: _generateAnswer, // 生成回答
                  child: Text('生成摘要'),
                ),
                // 顯示選擇的圖片 (web不支援)
                /*
                if (_selectedImage != null) ...[
                  SizedBox(height: 20),
                  Image.file(File(_selectedImage!.path), height: 100), // 顯示選擇的圖片
                ],
                */
                _imageBytes != null
                ? Image.memory(_imageBytes!)
                : Text("尚未選擇圖片")
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
                    controller: _detailedAnswerController,
                    decoration: InputDecoration(labelText: '輸入詳解'),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    // 打開相機
                    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
                    if (image != null) {
                      setState(() {
                        _selectedImage = image; // 存儲選擇的圖片
                      });
                    }
                  },
                  child: Text('打開相機'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // 從相簿中選擇
                    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                    if (image != null) {
                      setState(() {
                        _selectedImage = image; // 存儲選擇的圖片
                      });
                    }
                  },
                  child: Text('從相簿中選擇'),
                ),
                ElevatedButton(
                  onPressed: _generateAnswer, // 生成回答
                  child: Text('生成回答'),
                ),
                // 顯示選擇的圖片
                if (_selectedImage != null) ...[
                  SizedBox(height: 20),
                  Image.file(File(_selectedImage!.path), height: 100), // 顯示選擇的圖片
                ],
              ],
            ),
            TextField(
              controller: _tagController,
              decoration: InputDecoration(labelText: '備註/標籤'),
            ),
          ],
        ),
      ),
    );
  }
}