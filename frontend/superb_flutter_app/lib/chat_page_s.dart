import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_markdown_latex/flutter_markdown_latex.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:image_picker/image_picker.dart';
import 'dart:io';

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
  
  final List<String> _subjects = [
    '國文', '英文', '數學', '理化', '物理', '化學', '地科', '生物', '社會', '歷史', '地理', '公民'
  ];
  
  String? _selectedSubject;
  bool _isLoading = false;
  List<String> _items = [];
  String? _selectedItem;
  
  // Filter tags with placeholder text
  final List<String> _filterTags = ['選擇教育階段', '選擇科目', '選擇知識'];
  List<String> _activeFilters = [];

  // Add these filter options maps
  final Map<String, List<String>> _filterOptions = {
    '教育階段': ['國中', '高中'],
    '科目': ['國文', '英文', '數學', '理化', '物理', '化學', '地科', '生物', '社會', '歷史', '地理', '公民'],
    '知識': ['憲政體制的分權制衡', '民主政治', '人權保障', '法治國家'],
  };

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    if (_selectedSubject == null) {
      setState(() {
        _items = []; // Clear chapter list if no subject is selected
      });
      return;
    }

    try {
      String csvPath = '';
      switch (_selectedSubject) {
        case '化學':
          csvPath = 'assets/edu_data/high_chemistry_chapter.csv';
          break;
        case '理化':
          csvPath = 'assets/edu_data/junior_science_chapter.csv';
          break;
        default:
          csvPath = ''; // Other subjects not handled yet
      }

      if (csvPath.isEmpty) {
        setState(() {
          _items = [
            '當前科目讀取章節失敗',
          ];
        });
        return;
      }

      final String data = await DefaultAssetBundle.of(context).loadString(csvPath);
      final List<String> rows = data.split('\n');
      
      setState(() {
        _items = rows
            .skip(1)
            .where((row) => row.trim().isNotEmpty)
            .map((row) => row.split(',')[4].trim())
            .toSet()
            .toList();
      });
    } catch (e) {
      print('Error loading chapters: $e');
      setState(() {
        _items = [
          '發生錯誤',
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
    List<String> options = [];
    String title = '';
    
    if (filterTag == '選擇教育階段' || filterTag == '國中' || filterTag == '高中') {
      options = _filterOptions['教育階段']!;
      title = '選擇教育階段';
    } else if (filterTag == '選擇科目' || filterTag.contains('文') || filterTag.contains('數') || 
              filterTag.contains('理') || filterTag.contains('化') || filterTag.contains('物') || 
              filterTag.contains('生') || filterTag.contains('社') || filterTag.contains('史') || 
              filterTag.contains('地') || filterTag == '公民') {
      options = _filterOptions['科目']!;
      title = '選擇科目';
    } else {
      options = _filterOptions['知識點']!;
      title = '選擇知識';
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
                    final option = options[index];
                    return ListTile(
                      title: Text(
                        option,
                        style: TextStyle(
                          color: Color(0xFF1E3875),
                          fontSize: 16,
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          int tagIndex = _filterTags.indexOf(filterTag);
                          if (tagIndex != -1) {
                            _filterTags[tagIndex] = option;
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

  // Modify sendMessage method to handle single response
  void sendMessage() async {
    if (_controller.text.isEmpty && _selectedImage == null || _hasSubmittedQuestion) return;
    
    FocusScope.of(context).unfocus();
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      Map<String, dynamic> requestBody = {
        "user_message": _controller.text,
        "subject": _selectedSubject,
        "chapter": _selectedItem,
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
                                          _controller.text.isEmpty ? "什麼是民主憲政體制？" : _controller.text,
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