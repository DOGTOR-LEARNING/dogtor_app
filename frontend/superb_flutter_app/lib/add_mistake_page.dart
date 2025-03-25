// frontend/superb_flutter_app/lib/add_mistake_page.dart
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

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
  Uint8List? _imageBytes; // for web and mobile
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
    if (_imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('請選擇一張圖片')),
      );
      return;
    }

    setState(() {
      _isLoading = true; // 開始加載
    });

    try {
      // 使用已經讀取的圖片字節
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
      });
      print(_response);
    } catch (e) {
      setState(() {
        _response = "Error: $e";
        _isLoading = false; // 停止加載
      });
      print("Detailed error: $e");
    }
  }

  // 處理圖片選擇的通用方法
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImage = image;
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      print("Error picking image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('選擇圖片時出錯: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('新增錯題'),
        actions: [
          TextButton(
            onPressed: _submitData,
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 題目部分
              Text('題目', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              TextField(
                controller: _questionController,
                decoration: InputDecoration(labelText: '輸入題目'),
              ),
              SizedBox(height: 10),
              
              // 圖片選擇按鈕
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => _pickImage(ImageSource.camera),
                    child: Text('打開相機'),
                  ),
                  ElevatedButton(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    child: Text('從相簿中選擇'),
                  ),
                  ElevatedButton(
                    onPressed: _generateAnswer,
                    child: Text('生成摘要'),
                  ),
                ],
              ),
              
              // 顯示選擇的圖片
              SizedBox(height: 20),
              if (_imageBytes != null)
                Center(
                  child: Image.memory(
                    _imageBytes!,
                    height: 150,
                    fit: BoxFit.contain,
                  ),
                )
              else
                Center(child: Text("尚未選擇圖片")),
              
              // AI 回應顯示
              if (_response.isNotEmpty) ...[
                SizedBox(height: 20),
                Text('AI 回應:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(_response),
                ),
              ],

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
                  SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _detailedAnswerController,
                      decoration: InputDecoration(labelText: '輸入詳解'),
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 20),
              TextField(
                controller: _tagController,
                decoration: InputDecoration(labelText: '備註/標籤'),
              ),
              
              // 加載指示器
              if (_isLoading)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}