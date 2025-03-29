// frontend/superb_flutter_app/lib/add_mistake_page.dart
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import 'dart:typed_data';// Flutter Web only

class AddMistakePage extends StatefulWidget {
  @override
  _AddMistakePageState createState() => _AddMistakePageState();
}

class _AddMistakePageState extends State<AddMistakePage> {
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  final TextEditingController _detailedAnswerController = TextEditingController();

  String _selectedTag = "A"; // Default selection for answer options
  String _selectedSubject = "數學"; // Default subject
  String _selectedDifficulty = "Medium"; // Default difficulty
  
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
      "tag": _tagController.text,
      "subject": _selectedSubject,
      "difficulty": _selectedDifficulty,
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
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('錯題添加成功！'),
          backgroundColor: Color(0xFF1E3875),
        ),
      );
      
      // Navigate back after successful submission
      Future.delayed(Duration(seconds: 1), () {
        Navigator.pop(context);
      });
      
    } catch (e) {
      setState(() {
        _response = "Error: $e";
        _isLoading = false; // 停止加載
      });
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('錯誤: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _generateAnswer() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('請選擇一張圖片'),
          backgroundColor: Colors.red,
        )
      );
      return;
    }

    setState(() {
      _isLoading = true; // 開始加載
    });

    try {
      final bytes = await _selectedImage!.readAsBytes();
      setState(() {
        _imageBytes = bytes; // Set the image bytes for display
      });
      
      final base64Image = base64Encode(bytes);

      // 構建請求體
      final Map<String, dynamic> requestBody = {
        "image_base64": base64Image,
        "question": _questionController.text,
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
    } catch (e) {
      setState(() {
        _response = "Error: $e";
        _isLoading = false; // 停止加載
      });
    }
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
                      color:  Color(0xFF102031),
                      width: double.infinity,
                    ),
                  ),
                  // Image positioned below color block
 
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                      Text(
                        "新增錯題",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: _submitData,
                        child: Text(
                          "提交",
                          style: TextStyle(
                            color:  Color(0xFFFFA368),
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Medium',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Scrollable form
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // FIRST GROUP: Question input and image selection together
                        Container(
                          margin: EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Question input
                              Text(
                                "題目",
                                style: TextStyle(
                                  color: const Color.fromARGB(255, 255, 255, 255),
                                  fontSize: 18,
                                  fontFamily: 'Medium',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 16),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: TextField(
                                  controller: _questionController,
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 16.0,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: "輸入題目",
                                    hintStyle: TextStyle(color: Colors.black54),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                  maxLines: 5,
                                  minLines: 1,
                                ),
                              ),
                              SizedBox(height: 16),
                              
                              // Image section
                              
                              SizedBox(height: 8),
                              
                              // Image preview
                              Container(
                                width: double.infinity,
                                height: 180,
                                decoration: BoxDecoration(
                                  color: Colors.black12,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white24, width: 1),
                                ),
                                child: _imageBytes != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.memory(
                                        _imageBytes!,
                                        fit: BoxFit.contain,
                                      ),
                                    )
                                  : Center(
                                      child: Text(
                                        "尚未選擇圖片",
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                    ),
                              ),
                              SizedBox(height: 16),
                              
                              // Image selection buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildActionButton(
                                      icon: Icons.camera_alt,
                                      label: "相機",
                                      onPressed: () async {
                                        final XFile? image = await _picker.pickImage(source: ImageSource.camera);
                                        if (image != null) {
                                          setState(() {
                                            _selectedImage = image;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: _buildActionButton(
                                      icon: Icons.photo_library,
                                      label: "相簿",
                                      onPressed: () async {
                                        final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                                        if (image != null) {
                                          setState(() {
                                            _selectedImage = image;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: _buildActionButton(
                                      icon: Icons.auto_awesome,
                                      label: "生成摘要",
                                      color: Color(0xFF1E3875),
                                      iconColor: Color(0xFFFFA368),
                                      textColor: Colors.white,
                                      onPressed: _generateAnswer,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        // AI response display
                        if (_response.isNotEmpty) ...[
                          Container(
                            width: double.infinity,
                            margin: EdgeInsets.only(bottom: 16),
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "AI 回應",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  _response,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        
                        // SECOND GROUP: Subject, difficulty dropdowns and tag input
                        Container(
                          margin: EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "分類與標籤",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontFamily: 'Medium',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 12),
                              
                              // Subject and difficulty dropdowns
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        
                                        SizedBox(height: 6),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Color(0xFF8BB7E0),
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          padding: EdgeInsets.symmetric(horizontal: 12),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              isExpanded: true,
                                              value: _selectedSubject,
                                              borderRadius: BorderRadius.circular(12),
                                              dropdownColor: Color(0xFF8BB7E0),
                                              icon: Icon(Icons.arrow_drop_down, color: Color(0xFF102031)),
                                              style: TextStyle(color: Color(0xFF102031), fontSize: 15),
                                              items: ["數學", "國文", "理化", "歷史"]
                                                  .map((subject) => DropdownMenuItem<String>(
                                                        value: subject,
                                                        child: Text(subject),
                                                      ))
                                                  .toList(),
                                              onChanged: (newValue) {
                                                setState(() {
                                                  _selectedSubject = newValue!;
                                                });
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        
                                        SizedBox(height: 6),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Color(0xFF8BB7E0),
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          padding: EdgeInsets.symmetric(horizontal: 12),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              isExpanded: true,
                                              value: _selectedDifficulty,
                                              borderRadius: BorderRadius.circular(12),
                                              dropdownColor: Color(0xFF8BB7E0),
                                              icon: Icon(Icons.arrow_drop_down, color: Color(0xFF102031)),
                                              style: TextStyle(color: Color(0xFF102031), fontSize: 15),
                                              items: ["Easy", "Medium", "Hard"]
                                                  .map((difficulty) => DropdownMenuItem<String>(
                                                        value: difficulty,
                                                        child: Row(
                                                          children: [
                                                            Text(
                                                              '★' * (_getDifficultyStars(difficulty)),
                                                              style: TextStyle(
                                                                color: Color(0xFFFFA368),
                                                              ),
                                                            ),
                                                            SizedBox(width: 8),
                                                            Text(difficulty),
                                                          ],
                                                        ),
                                                      ))
                                                  .toList(),
                                              onChanged: (newValue) {
                                                setState(() {
                                                  _selectedDifficulty = newValue!;
                                                });
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              
                              // Tags input
                              
                              SizedBox(height: 6),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: TextField(
                                  controller: _tagController,
                                  style: TextStyle(color: Colors.black87, fontSize: 16),
                                  decoration: InputDecoration(
                                    hintText: "輸入標籤 (選填)",
                                    hintStyle: TextStyle(color: Colors.black54),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Answer section
                        Container(
                          margin: EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "答案",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontFamily: 'Medium',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 12),
                              
                              // Simple answer
                              Row(
                                children: [
                                  Text(
                                    "選項: ",
                                    style: TextStyle(color: Colors.white, fontSize: 15),
                                  ),
                                  SizedBox(width: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Color(0xFF8BB7E0),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: EdgeInsets.symmetric(horizontal: 8),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _selectedTag,
                                        dropdownColor: Color(0xFF8BB7E0),
                                        icon: Icon(Icons.arrow_drop_down, color: Color(0xFF102031)),
                                        style: TextStyle(color: Color(0xFF102031), fontSize: 15),
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
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              
                              // Detailed answer
                              
                              SizedBox(height: 6),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: TextField(
                                  controller: _detailedAnswerController,
                                  style: TextStyle(color: Colors.black87, fontSize: 16),
                                  decoration: InputDecoration(
                                    hintText: "輸入詳解",
                                    hintStyle: TextStyle(color: Colors.black54),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.all(12),
                                  ),
                                  maxLines: 4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Submit button
                        Container(
                          margin: EdgeInsets.only(bottom: 60), // Extra space at bottom
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF1E3875).withOpacity(0.3),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black54,
              width: double.infinity,
              height: double.infinity,
              child: Center(
                child: Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Color(0xFF102031),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8BB7E0)),
                      ),
                      SizedBox(height: 16),
                      Text(
                        "處理中...",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  // Helper methods for UI components
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
  
  Widget _buildInputContainer({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
  
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color iconColor = const Color(0xFF102031),
    Color color = Colors.white,
    Color textColor = const Color(0xFF102031),
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: textColor,
        elevation: 0,
        padding: EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: iconColor),
          SizedBox(width: 6),
          Text(label),
        ],
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
      return 0;
  }
}