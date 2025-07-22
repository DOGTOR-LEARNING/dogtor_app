// frontend/superb_flutter_app/lib/add_mistake_page.dart
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';

class AddMistakePage extends StatefulWidget {
  final bool isEditMode;
  final Map<String, dynamic>? mistakeToEdit;

  AddMistakePage({
    this.isEditMode = false,
    this.mistakeToEdit,
  });

  @override
  _AddMistakePageState createState() => _AddMistakePageState();
}

class _AddMistakePageState extends State<AddMistakePage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  final TextEditingController _detailedAnswerController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  String _selectedTag = "A"; // Default selection for answer options
  String _selectedSubject = "數學"; // Default subject
  String _selectedDifficulty = "Medium"; // Default difficulty
  
  final ImagePicker _picker = ImagePicker();
  // 題目區圖片
  XFile? _questionImage;
  Uint8List? _questionImageBytes;
  // 詳解區圖片
  XFile? _answerImage;
  Uint8List? _answerImageBytes;
  String _response = ""; // 存儲 AI 的標題摘要回應
  bool _isLoading = false; // 加載狀態
  String _mistakeId = ""; // Store the ID for edits
  
  @override
  void initState() {
    super.initState();
    
    // If in edit mode, populate the fields with existing data
    if (widget.isEditMode && widget.mistakeToEdit != null) {
      _populateFieldsWithExistingData();
    }
  }
  
  // Helper method to populate fields with existing data
  void _populateFieldsWithExistingData() {
    final mistake = widget.mistakeToEdit!;
    
    // Populate text fields
    _titleController.text = mistake['summary'] ?? '';  // 錯題卡標題
    _questionController.text = mistake['description'] ?? '';
    _tagController.text = mistake['tag'] ?? '';
    _detailedAnswerController.text = mistake['answer'] ?? mistake['detailed_answer'] ?? '';  // 答案
    _noteController.text = mistake['note'] ?? '';  // 給自己的小提醒
    
    // Make sure we have valid default values that exist in our dropdown lists
    setState(() {
      // For the subject dropdown, verify it's in our list
      final subjectValue = mistake['subject'] ?? '數學';
      if (["數學", "國文", "理化", "歷史"].contains(subjectValue)) {
        _selectedSubject = subjectValue;
      } else {
        _selectedSubject = "數學"; // Default if invalid
      }
      
      // For the tag dropdown, make sure it's A, B, C, or D
      final tagValue = mistake['simple_answer'] ?? 'A';
      if (['A', 'B', 'C', 'D'].contains(tagValue)) {
        _selectedTag = tagValue;
      } else {
        _selectedTag = "A"; // Default if invalid
      }
      
      // For difficulty, validate it's in our list
      final difficultyValue = mistake['difficulty'] ?? 'Medium';
      if (['Easy', 'Medium', 'Hard'].contains(difficultyValue)) {
        _selectedDifficulty = difficultyValue;
      } else {
        _selectedDifficulty = "Medium"; // Default if invalid
      }
      
      _mistakeId = mistake['q_id'] ?? ''; // Store the ID for the update request
    });
    
    // Try to load the existing image for question and answer (如有需求可擴充)
    // 目前只支援一張圖，這裡可根據資料結構擴充
    _loadExistingQuestionImage();
    _loadExistingAnswerImage();
  }
  
  // Helper method to load the existing question image if available
  Future<void> _loadExistingQuestionImage() async {
    // 若有題目圖片URL，可在此載入
    // 目前暫不實作
  }
  // Helper method to load the existing answer image if available
  Future<void> _loadExistingAnswerImage() async {
    // 若有詳解圖片URL，可在此載入
    // 目前暫不實作
  }

  Future<void> _submitData() async {
    // Validate required fields before submission
    if (_questionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('請輸入題目內容'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    String? base64QuestionImage;
    String? base64AnswerImage;
    if (_questionImage != null) {
      final bytes = await _questionImage!.readAsBytes();
      base64QuestionImage = base64Encode(bytes);
    }
    if (_answerImage != null) {
      final bytes = await _answerImage!.readAsBytes();
      base64AnswerImage = base64Encode(bytes);
    }

    // 取得 user_id
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String userId = prefs.getString('user_id') ?? "default_user";

    try {
      // Construct the request body for question data
      final Map<String, dynamic> requestBody = {
        "user_id": userId, // 您可以根據需要修改user_id邏輯
        "summary": _response.isEmpty ? _titleController.text : _response,
        "subject": _selectedSubject,
        "chapter": "", // 可以添加章節選擇器
        "difficulty": _selectedDifficulty,
        "tag": _tagController.text,
        "description": _questionController.text,
        "answer": _detailedAnswerController.text,
        "note": _noteController.text, // 給自己的小提醒
        "created_at": DateTime.now().toIso8601String(),
        "question_image_base64": base64QuestionImage ?? "",
        "answer_image_base64": base64AnswerImage ?? "",
      };
      print("Request body: $requestBody");
      
      // If in edit mode, include the ID
      if (widget.isEditMode && _mistakeId.isNotEmpty) {
        requestBody["q_id"] = _mistakeId;
      }

      /*
      // Cloud端：上傳錯題資訊到後端
      // Choose endpoint based on whether we're editing or creating
      final endpoint = widget.isEditMode 
          ? "https://superb-backend-1041765261654.asia-east1.run.app/mistake-book/update_question"
          : "https://superb-backend-1041765261654.asia-east1.run.app/mistake-book/";
          
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {"Content-Type": "application/json; charset=UTF-8"},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        print("API error: ${response.body}");
        throw Exception('伺服器錯誤: ${response.statusCode}');
      }
      

      print("hi submitted response");
      final responseData = jsonDecode(utf8.decode(response.bodyBytes));
      
      /*
      // 取得回傳的q_id或生成一個唯一ID
      String questionId;
      if (widget.isEditMode) {
        questionId = _mistakeId;
      } else {
        questionId = responseData["q_id"]?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
      }
      */
      
      setState(() {
        _response = responseData["status"] ?? "No response";
        _isLoading = false;
      });
      print(_response);
      */
      
      // 生成錯題 ID
      String questionId;
      if (widget.isEditMode && _mistakeId.isNotEmpty) {
        // 編輯模式：使用現有的 ID
        questionId = _mistakeId;
      } else {
        // 新增模式：生成新的 ID（使用時間戳 + 隨機數確保唯一性）
        questionId = DateTime.now().millisecondsSinceEpoch.toString();
      }
      
      // Local端：儲存錯題資訊到 Hive
      var box = await Hive.openBox('questionsBox');
      await box.put(questionId, {
        'summary': requestBody['summary'],
        'subject': requestBody['subject'],
        'chapter': requestBody['chapter'],
        'description': requestBody['description'],
        'difficulty': requestBody['difficulty'],
        'answer': requestBody['answer'],
        'tag': requestBody['tag'],
        'note': requestBody['note'], // 給自己的小提醒
        'created_at': requestBody['created_at'],
        'question_image_base64': base64QuestionImage ?? "",
        'answer_image_base64': base64AnswerImage ?? "",
        'is_sync': false, // 預設為未同步狀態
      });

      print("已儲存錯題資訊到 Hive");

      // 嘗試同步到雲端
      await _syncToCloud(questionId, requestBody, base64QuestionImage, base64AnswerImage);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isEditMode ? '錯題更新成功！' : '錯題添加成功！'),
          backgroundColor: Color(0xFF1E3875),
        ),
      );
      
      // Navigate back after successful submission with result
      Future.delayed(Duration(seconds: 1), () {
        Navigator.pop(context, true); // Return true to indicate successful edit
      });
      
    } catch (e) {
      setState(() {
        _response = "Error: $e";
        _isLoading = false;
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

  // 同步到雲端的方法
  Future<void> _syncToCloud(String questionId, Map<String, dynamic> requestBody, String? base64QuestionImage, String? base64AnswerImage) async {
    try {
      // 準備同步到雲端的請求
      final syncRequestBody = Map<String, dynamic>.from(requestBody);
      syncRequestBody['question_image_base64'] = base64QuestionImage ?? "";
      syncRequestBody['answer_image_base64'] = base64AnswerImage ?? "";

      // 發送 POST 請求到 add_mistake_book API
      final response = await http.post(
        Uri.parse('https://superb-backend-1041765261654.asia-east1.run.app/mistake-book/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(syncRequestBody),
      );

      if (response.statusCode == 200) {
        // 雲端同步成功，解析回應獲取雲端 ID
        final responseData = jsonDecode(response.body);
        final cloudId = responseData['q_id']?.toString();
        
        var box = await Hive.openBox('questionsBox');
        
        if (cloudId != null && cloudId != questionId) {
          // 如果雲端 ID 不同於本地 ID，需要更新本地儲存
          var existingData = box.get(questionId);
          if (existingData != null) {
            // 刪除舊的本地 ID 記錄
            await box.delete(questionId);
            // 用雲端 ID 重新儲存，並標記為已同步
            existingData['is_sync'] = true;
            await box.put(cloudId, existingData);
          }
        } else {
          // 如果 ID 相同或沒有雲端 ID，只更新同步狀態
          var existingData = box.get(questionId);
          if (existingData != null) {
            existingData['is_sync'] = true;
            await box.put(questionId, existingData);
          }
        }
        print("已成功同步到雲端");
      } else {
        print("雲端同步失敗：狀態碼 ${response.statusCode}");
        // 不拋出異常，讓用戶操作繼續，稍後會有自動同步機制
      }
    } catch (e) {
      print("雲端同步錯誤: $e");
      // 不拋出異常，讓用戶操作繼續，稍後會有自動同步機制
    }
  }

  Future<void> _generateSummary() async {
    // 這個方法只針對題目區圖片生成摘要
    if (_questionImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('請先在題目區選擇一張圖片'),
          backgroundColor: Colors.red,
        )
      );
      return;
    }

    setState(() {
      _isLoading = true; // 開始加載
    });

    try {
      final bytes = await _questionImage!.readAsBytes();
      setState(() {
        _questionImageBytes = bytes; // Set the image bytes for display
      });
      
      final base64Image = base64Encode(bytes);

      // 構建請求體
      final Map<String, dynamic> requestBody = {
        "image_base64": base64Image,
        "user_message": _questionController.text,
      };

      final response = await http.post(
        Uri.parse("https://superb-backend-1041765261654.asia-east1.run.app/ai/summarize"),
        headers: {"Content-Type": "application/json; charset=UTF-8"},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}\nBody: ${response.body}');
      }

      final responseData = jsonDecode(utf8.decode(response.bodyBytes));
      setState(() {
        _response = responseData["response"] ?? "No response";
        _titleController.text = _response; // Set the title field with the AI response
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
                // Top bar with back button and title
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
                            Icon(Icons.arrow_back, color: Colors.white, size: 24),
                            SizedBox(width: 4),
                          ],
                        ),
                      ),
                      Text(
                        widget.isEditMode ? "編輯錯題" : "新增錯題", // Change title based on mode
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _submitData,
                        style: ElevatedButton.styleFrom( 
                          foregroundColor: Colors.white,
                          backgroundColor: Color(0xFFFFA368),
                          elevation: 20,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Color(0xFFFFA368)),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          fixedSize: Size(60, 20),
                        ),
                        child: Text(
                          widget.isEditMode ? "更新" : "提交", // Change button text based on mode
                          style: TextStyle(
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
                        // Mistake Card Title
                        // AI response display
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
                                "錯題卡標題",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontFamily: 'Medium',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 12),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: TextField(
                                  controller: _titleController,
                                  style: TextStyle(color: Colors.black87, fontSize: 16),
                                  decoration: InputDecoration(
                                    hintText: "想不到適合的標題可以點擊下面的「生成摘要」喔！",
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
                              
                              // Image preview for question
                              Container(
                                width: double.infinity,
                                height: 180,
                                decoration: BoxDecoration(
                                  color: Colors.black12,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white24, width: 1),
                                ),
                                child: _questionImage != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: FutureBuilder<Uint8List>(
                                        future: _questionImage!.readAsBytes(),
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState == ConnectionState.waiting) {
                                            return Center(child: CircularProgressIndicator());
                                          } else if (snapshot.hasError) {
                                            return Center(child: Text('Error loading image', style: TextStyle(color: Colors.white70)));
                                          } else if (snapshot.hasData) {
                                            return Image.memory(
                                              snapshot.data!,
                                              fit: BoxFit.contain,
                                            );
                                          } else {
                                            return Center(child: Text('No image selected', style: TextStyle(color: Colors.white70)));
                                          }
                                        },
                                      ),
                                    )
                                  : _questionImageBytes != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.memory(
                                          _questionImageBytes!,
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
                              
                              // Image selection buttons for question
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
                                            _questionImage = image;
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
                                            _questionImage = image;
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
                                      onPressed: _questionImage != null ? () {
                                        _generateSummary();
                                      } : null,
                                      disabledColor: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        
                        
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
                                                if (newValue != null) {
                                                  setState(() {
                                                    _selectedSubject = newValue;
                                                  });
                                                }
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
                                              style: TextStyle(color: Color(0xFF102031), fontSize: 12),
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
                        // Detailed answer
                      
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
                                "答案",
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
                                  controller: _detailedAnswerController,
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 16.0,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: "輸入詳解",
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
                              
                              // Image preview for answer
                              Container(
                                width: double.infinity,
                                height: 180,
                                decoration: BoxDecoration(
                                  color: Colors.black12,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white24, width: 1),
                                ),
                                child: _answerImage != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: FutureBuilder<Uint8List>(
                                        future: _answerImage!.readAsBytes(),
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState == ConnectionState.waiting) {
                                            return Center(child: CircularProgressIndicator());
                                          } else if (snapshot.hasError) {
                                            return Center(child: Text('Error loading image', style: TextStyle(color: Colors.white70)));
                                          } else if (snapshot.hasData) {
                                            return Image.memory(
                                              snapshot.data!,
                                              fit: BoxFit.contain,
                                            );
                                          } else {
                                            return Center(child: Text('No image selected', style: TextStyle(color: Colors.white70)));
                                          }
                                        },
                                      ),
                                    )
                                  : _answerImageBytes != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.memory(
                                          _answerImageBytes!,
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
                              
                              // Image selection buttons for answer
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
                                            _answerImage = image;
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
                                            _answerImage = image;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                  // 詳解區不提供AI摘要
                                ],
                              ),
                            ],
                          ),
                        ),

                        // note section
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
                                "給自己的小提醒",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontFamily: 'Medium',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 12),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: TextField(
                                  controller: _noteController,
                                  style: TextStyle(color: Colors.black87, fontSize: 16),
                                  decoration: InputDecoration(
                                    hintText: "可以在這裡輸入卡關的點喔！（選填）",
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
    VoidCallback? onPressed,
    Color iconColor = const Color(0xFF102031),
    Color color = Colors.white,
    Color textColor = const Color(0xFF102031),
    Color disabledColor = Colors.grey,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: onPressed == null ? disabledColor : color,
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