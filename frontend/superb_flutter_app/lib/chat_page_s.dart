import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_markdown_latex/flutter_markdown_latex.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class ChatPage extends StatefulWidget {
  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  String _response = ""; // Store AI's response
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  bool _isKeyboardVisible = false;
  bool _hasSubmittedQuestion = false;  // Add this line to track if a question has been submitted
  
  // 用於存儲從API獲取的所有科目
  List<String> _subjects = [];
  // 用於存儲從API獲取的所有章節，按科目分類
  Map<String, List<Map<String, dynamic>>> _chaptersMap = {};
  
  String? _selectedSubject;
  bool _isLoading = false;
  List<dynamic> _items = [];
  String? _selectedItem;
  
  // 用戶資料
  String _userId = '';
  String _displayName = '';
  String _nickname = '';
  String _yearGrade = '';
  String _introduction = '';
  
  // Filter tags with placeholder text
  final List<String> _filterTags = ['選擇年級', '選擇科目', '選擇章節'];
  List<String> _activeFilters = [];

  // 年級選項和顯示名稱
  final List<String> _gradeOptions = ['G1', 'G2', 'G3', 'G4', 'G5', 'G6', 'G7', 'G8', 'G9', 'G10', 'G11', 'G12', 'teacher', 'parent'];
  final Map<String, String> _gradeDisplayNames = {
    'G1': '小一', 'G2': '小二', 'G3': '小三', 'G4': '小四', 'G5': '小五', 'G6': '小六',
    'G7': '國一', 'G8': '國二', 'G9': '國三', 'G10': '高一', 'G11': '高二', 'G12': '高三',
    'teacher': '老師', 'parent': '家長'
  };

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchSubjectsAndChapters();
  }

  // 加載用戶數據
  Future<void> _loadUserData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      setState(() {
        _userId = prefs.getString('user_id') ?? '';
        _displayName = prefs.getString('display_name') ?? '同學';
        _nickname = prefs.getString('nickname') ?? '';
        _yearGrade = prefs.getString('year_grade') ?? 'G10'; // 預設高一
        _introduction = prefs.getString('introduction') ?? '';
        
        // 根據用戶年級設置默認過濾器
        if (_yearGrade.isNotEmpty) {
          _filterTags[0] = _gradeDisplayNames[_yearGrade] ?? _yearGrade;
        }
      });
    } catch (e) {
      print('加載用戶數據時出錯: $e');
    }
  }

  // 從後端獲取科目和章節數據
  Future<void> _fetchSubjectsAndChapters() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('https://superb-backend-1041765261654.asia-east1.run.app/get_subjects_and_chapters'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        
        if (data['success']) {
          setState(() {
            _subjects = List<String>.from(data['subjects']);
            
            // 轉換章節數據結構
            final Map<String, dynamic> chaptersData = data['chapters_by_subject'];
            _chaptersMap = {};
            
            chaptersData.forEach((subject, chapters) {
              _chaptersMap[subject] = List<Map<String, dynamic>>.from(chapters);
            });
            
            _isLoading = false;
          });
        } else {
          print('獲取科目和章節數據失敗: ${data['message']}');
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        print('API請求失敗: ${response.statusCode}');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('獲取科目和章節時出錯: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadItems() async {
    if (_selectedSubject == null) {
      setState(() {
        _items = []; // Clear chapter list if no subject is selected
      });
      return;
    }

    try {
      // 從緩存中獲取選定科目的章節列表
      if (_chaptersMap.containsKey(_selectedSubject)) {
        setState(() {
          _items = _chaptersMap[_selectedSubject]!;
        });
      } else {
        setState(() {
          _items = [
            {'id': '-1', 'chapter_name': '當前科目讀取章節失敗'},
          ];
        });
      }
    } catch (e) {
      print('Error loading chapters: $e');
      setState(() {
        _items = [
          {'id': '-1', 'chapter_name': '發生錯誤'},
        ];
      });
    }
  }

  void _onSubjectChanged(String? newValue) {
    setState(() {
      _selectedSubject = newValue;
      _selectedItem = null;
    });
    _loadItems();
  }

  void _showFullImage() {
    if (_selectedImage != null) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                
                FutureBuilder<Uint8List>(
                  future: _selectedImage!.readAsBytes(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return Image.memory(
                        snapshot.data!,
                        fit: BoxFit.contain,
                      );
                    }
                    return Center(child: CircularProgressIndicator());
                  },
                ),
                TextButton(
                  child: Text('Close'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          );
        },
      );
    }
  }

  void _showFilterOptions(String filterTag) {
    List<dynamic> options = [];
    String title = '';
    
    if (filterTag == '選擇年級' || _gradeDisplayNames.values.contains(filterTag)) {
      options = _gradeOptions.map((grade) => _gradeDisplayNames[grade] ?? grade).toList();
      title = '選擇年級';
    } else if (filterTag == '選擇科目' || filterTag.contains('文') || filterTag.contains('數') || 
              filterTag.contains('理') || filterTag.contains('化') || filterTag.contains('物') || 
              filterTag.contains('生') || filterTag.contains('社') || filterTag.contains('史') || 
              filterTag.contains('地') || filterTag == '公民') {
      // 使用API獲取的科目列表
      options = _subjects;
      title = '選擇科目';
    } else {
      // 如果選擇了科目，則顯示該科目的章節列表
      if (_selectedSubject != null && _chaptersMap.containsKey(_selectedSubject)) {
        options = _chaptersMap[_selectedSubject]!;
      } else {
        options = [];
      }
      title = '選擇章節';
    }

    // 如果沒有選項可供選擇，提示用戶先選擇其他選項
    if (options.isEmpty && title == '選擇章節') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('請先選擇科目'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.withOpacity(0.2),
                    ),
                  ),
                ),
                child: Center(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E3875),
                    ),
                  ),
                ),
              ),
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    // 根據選項類型顯示不同內容
                    String optionText;
                    dynamic optionValue;
                    
                    if (title == '選擇科目') {
                      optionText = options[index];
                      optionValue = options[index];
                    } else if (title == '選擇章節') {
                      // 章節選項是一個包含id和chapter_name的Map
                      optionText = options[index]['chapter_name'];
                      optionValue = options[index];
                    } else {
                      // 年級選項
                      optionText = options[index];
                      // 找到年級代碼
                      String? gradeCode;
                      _gradeDisplayNames.forEach((code, displayName) {
                        if (displayName == optionText) {
                          gradeCode = code;
                        }
                      });
                      optionValue = gradeCode ?? optionText;
                    }
                    
                    return ListTile(
                      title: Text(
                        optionText,
                        style: TextStyle(
                          color: Color(0xFF1E3875),
                          fontSize: 16,
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          int tagIndex = _filterTags.indexOf(filterTag);
                          if (tagIndex != -1) {
                            if (title == '選擇科目') {
                              _filterTags[tagIndex] = optionText;
                              _selectedSubject = optionText;
                              // 選擇科目後重設章節
                              _filterTags[2] = '選擇章節';
                              _selectedItem = null;
                              // 重新加載該科目的章節
                              _loadItems();
                            } else if (title == '選擇章節') {
                              _filterTags[tagIndex] = optionText;
                              // 保存選擇的章節ID
                              _selectedItem = optionValue['chapter_name'];
                            } else {
                              // 更新年級顯示和內部存儲
                              _filterTags[tagIndex] = optionText;
                              _yearGrade = optionValue;
                            }
                          }
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Modify sendMessage method to handle single response and include user info
  void sendMessage() async {
    if (_controller.text.isEmpty && _selectedImage == null || _hasSubmittedQuestion) return;
    
    FocusScope.of(context).unfocus();
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // 使用暱稱或顯示名稱
      String userDisplayName = _nickname.isNotEmpty ? _nickname : _displayName;
      
      Map<String, dynamic> requestBody = {
        "user_message": _controller.text,
        "subject": _selectedSubject,
        "chapter": _selectedItem,
        "user_name": userDisplayName,
        "user_introduction": _introduction,
        "year_grade": _yearGrade,
      };

      if (_selectedImage != null) {
        final bytes = await _selectedImage!.readAsBytes();
        final base64Image = base64Encode(bytes);
        requestBody["image_base64"] = base64Image;
      }

      final response = await http.post(
        Uri.parse("https://superb-backend-1041765261654.asia-east1.run.app/chat"),
        headers: {"Content-Type": "application/json; charset=UTF-8"},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}\nBody: ${response.body}');
      }

      final responseData = jsonDecode(utf8.decode(response.bodyBytes));
      setState(() {
        _response = responseData["response"] ?? "No response";
        _isLoading = false;
        _hasSubmittedQuestion = true;
      });
    } catch (e) {
      setState(() {
        _response = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.";
        _isLoading = false;
        _hasSubmittedQuestion = true;
      });
      print("Detailed error: $e");
    }
  }

  Future<void> _handleImageSelection() async {
    showModalBottomSheet(
      context: context,
    backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.withOpacity(0.2),
                  ),
                ),
              ),
              child: Center(
                child: Text(
                  '選擇照片',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
          color: Color(0xFF1E3875),
                  ),
                ),
              ),
            ),
            Container(
              child: Column(
                children: [
              ListTile(
                    leading: Icon(Icons.photo_library, color: Color(0xFF1E3875)),
                    title: Text(
                      '從相簿選擇',
                      style: TextStyle(
                        color: Color(0xFF1E3875),
                        fontSize: 16,
                      ),
                    ),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                  if (image != null) {
                    _handleSelectedImage(image);
                  }
                },
              ),
              ListTile(
                    leading: Icon(Icons.photo_camera, color: Color(0xFF1E3875)),
                    title: Text(
                      '拍照',
                      style: TextStyle(
                        color: Color(0xFF1E3875),
                        fontSize: 16,
                      ),
                    ),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
                  if (photo != null) {
                    _handleSelectedImage(photo);
                  }
                },
                  ),
                ],
              ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleSelectedImage(XFile image) {
    setState(() {
      _selectedImage = image;
    });
  }

  void _toggleFilter(String filter) {
    setState(() {
      if (_activeFilters.contains(filter)) {
        _activeFilters.remove(filter);
      } else {
        _activeFilters.add(filter);
      }
    });
  }

  void _showHistory() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.withOpacity(0.2),
                    ),
                  ),
                ),
                child: Center(
                  child: Text(
                    '歷史紀錄',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E3875),
                    ),
                  ),
                ),
              ),
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(
                      title: Text(
                        'Previous question 1',
                        style: TextStyle(
                          color: Color(0xFF1E3875),
                          fontSize: 16,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                      },
                    ),
                    ListTile(
                      title: Text(
                        'Previous question 2',
                        style: TextStyle(
                          color: Color(0xFF1E3875),
                          fontSize: 16,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                      },
                    ),
                    ListTile(
                      title: Text(
                        'Previous question 3',
                        style: TextStyle(
                          color: Color(0xFF1E3875),
                          fontSize: 16,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
              },
            ),
          ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    _isKeyboardVisible = bottomInset > 0;
    
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Color(0xFF102031),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            // Background color for top area
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 240, // Increased height to accommodate color block
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
                        color: Color.fromRGBO(99, 158, 171, 1),
                        width: double.infinity,
                      ),
                    ),
                    // Image positioned below color block
                      Positioned(
                      top: 40,
                      left: 0,
                      right: 0,
                      bottom: 0,
                        child: Image.asset(
                        'assets/images/question-cor-top.png',
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Loading overlay
            if (_isLoading)
              Container(
                width: double.infinity,
                height: double.infinity,
                color: Color(0xFF102031).withOpacity(0.8),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                          children: [
                          Icon(
                            Icons.lightbulb_outline,
                            color: Colors.white,
                            size: 48,
                          ),
                          SizedBox(
                            width: 80,
                            height: 80,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Text('思考中...', style: TextStyle(color: Colors.white)),
                    ],
                                ),
                              ),
                            ),

            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // Top bar with back button
                  Container(
                    height: 56,
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
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
                      ],
                    ),
                  ),
                
                  // Main content area (scrollable)
                  Expanded(
                    child: Stack(
                      children: [],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom input section with external buttons
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // External buttons (history and camera)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.2),
                            ),
                          ),
                          child: TextButton.icon(
                            icon: Icon(Icons.history, size: 18, color: Color(0xFF1E3875)),
                            label: Text(
                              '歷史紀錄',
                              style: TextStyle(
                                color: Color(0xFF1E3875),
                                fontSize: 14,
                              ),
                            ),
                            onPressed: _showHistory,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                            ),
                          ),
                        ),
                Container(
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.2),
                            ),
                          ),
                          child: TextButton.icon(
                            icon: Icon(Icons.photo_camera, size: 18, color: Color(0xFF1E3875)),
                          label: Text(
                              '拍照',
                            style: TextStyle(
                                color: Color(0xFF1E3875),
                                fontSize: 14,
                              ),
                            ),
                            onPressed: !_hasSubmittedQuestion ? _handleImageSelection : null,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Stack for corgi and input container
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Corgi image positioned behind input container
                      if (!_hasSubmittedQuestion)
                        Positioned(
                          top: -115, // 調整位置
                          left: MediaQuery.of(context).size.width / 2 - 70, // 水平置中
                          child: Image.asset(
                            'assets/images/question-corgi.png',
                            width: 160, // 調整大小
                          ),
                        ),

                      // White input container
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white, // 稍微調整透明度，讓柯基若隱若現
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(24),
                            topRight: Radius.circular(24),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: Offset(0, -2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Input field and send button
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      constraints: BoxConstraints(
                                        minHeight: 40,
                                        maxHeight: 120,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: TextField(
                                        controller: _controller,
                                        enabled: !_hasSubmittedQuestion,
                                        minLines: 1,
                                        maxLines: 5,
                                        style: TextStyle(
                                          color: Color(0xFF1E3875),
                                          fontSize: 16,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: "輸入或拍照⋯⋯",
                                          hintStyle: TextStyle(
                                            color: Color(0xFF1E3875).withOpacity(0.6),
                                            fontSize: 16,
                                          ),
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Color(0xFF1E3875),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: IconButton(
                                      icon: Icon(Icons.send, color: Colors.white),
                                      onPressed: !_hasSubmittedQuestion ? sendMessage : null,
                                      style: IconButton.styleFrom(
                                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Filter chips (fixed at input field below)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: _filterTags.map((filter) {
                                  return Padding(
                                    padding: EdgeInsets.only(right: 8),
                                    child: GestureDetector(
                                      onTap: () => _showFilterOptions(filter),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: filter == '國中' 
                                              ? Color(0xFFFFA368) 
                                              : Color(0xFF8BB7E0),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 10,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (filter == '國中')
                                              Padding(
                                                padding: EdgeInsets.only(right: 8),
                                                child: Icon(
                                                  Icons.eco,
                                                  color: Colors.white,
                                                  size: 18,
                                                ),
                                              )
                                            else if (filter == '公民')
                                              Padding(
                                                padding: EdgeInsets.only(right: 8),
                                                child: Icon(
                                                  Icons.menu_book,
                                                  color: Colors.white,
                                                  size: 18,
                                                ),
                                              ),
                                            Text(
                                              filter,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),

                            // Image preview (if image is selected)
                            if (_selectedImage != null)
                              Container(
                                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Stack(
                                  children: [
                                    GestureDetector(
                                      onTap: _showFullImage,
                                      child: Container(
                                        height: 120,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.grey[300]!, width: 1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(11),
                                          child: FutureBuilder<Uint8List>(
                                            future: _selectedImage!.readAsBytes(),
                                            builder: (context, snapshot) {
                                              if (snapshot.hasData) {
                                                return Image.memory(
                                                  snapshot.data!,
                                                  fit: BoxFit.cover,
                                                );
                                              }
                                              return Center(child: CircularProgressIndicator());
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Close button
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedImage = null;
                                          });
                                        },
                                        child: Container(
                                          padding: EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.5),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Response container (only show if there's a response)
                            if (_response.isNotEmpty)
                              Container(
                                margin: EdgeInsets.all(16),
                                constraints: BoxConstraints(
                                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey[300]!,
                                    width: 1,
                                  ),
                                ),
                                child: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Question display
                                      Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Text(
                                          _controller.text.isEmpty ? "Dogtor, 請幫我回答這一個題目 ;-; " : _controller.text,
                                          style: TextStyle(
                                            color: Color(0xFF1E3875),
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      // Divider
                                      Divider(height: 1, color: Colors.grey[300]),
                                      // Response content
                                      Padding(
                                        padding: EdgeInsets.all(16),
                                        child: _buildResponse(_response),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            // Bottom padding
                            SizedBox(height: MediaQuery.of(context).padding.bottom),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberedPoint(String number, String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$number. ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              '$title：',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        Padding(
          padding: EdgeInsets.only(left: 20, top: 4),
          child: Text(
            content,
            style: TextStyle(
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResponse(String response) {
    return Markdown(
      selectable: true,
      data: response,
      shrinkWrap: true,
      physics: ClampingScrollPhysics(),
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(color: Colors.black, fontSize: 16),
        h1: TextStyle(color: Colors.black),
        h2: TextStyle(color: Colors.black),
        h3: TextStyle(color: Colors.black),
        h4: TextStyle(color: Colors.black),
        h5: TextStyle(color: Colors.black),
        h6: TextStyle(color: Colors.black),
        listBullet: TextStyle(color: Colors.black),
      ),
      builders: {
        'latex': LatexElementBuilder(
          textStyle: TextStyle(color: Colors.black, fontSize: 16),
          textScaleFactor: 1.1,
        ),
      },
      extensionSet: md.ExtensionSet(
        [LatexBlockSyntax()],
        [LatexInlineSyntax()],
      ),
    );
  }
}