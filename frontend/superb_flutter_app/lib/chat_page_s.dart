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
import 'package:intl/intl.dart';

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
  bool _hasSubmittedQuestion = false;

  // 新增圖片解析狀態
  bool _isAnalyzingImage = false;

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
  final List<String> _gradeOptions = [
    'G1',
    'G2',
    'G3',
    'G4',
    'G5',
    'G6',
    'G7',
    'G8',
    'G9',
    'G10',
    'G11',
    'G12',
    'teacher',
    'parent'
  ];
  final Map<String, String> _gradeDisplayNames = {
    'G1': '小一',
    'G2': '小二',
    'G3': '小三',
    'G4': '小四',
    'G5': '小五',
    'G6': '小六',
    'G7': '國一',
    'G8': '國二',
    'G9': '國三',
    'G10': '高一',
    'G11': '高二',
    'G12': '高三',
    'teacher': '老師',
    'parent': '家長'
  };

  // 聊天歷史記錄
  List<Map<String, dynamic>> _chatHistory = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchSubjectsAndChapters();
    _loadChatHistory();
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
        Uri.parse(
            'https://superb-backend-1041765261654.asia-east1.run.app/admin/subjects_and_chapters'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        if (data['success']) {
          setState(() {
            _subjects = List<String>.from(data['subjects']);

            // 轉換章節數據結構
            final Map<String, dynamic> chaptersData =
                data['chapters_by_subject'];
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
                Image.file(
                  File(_selectedImage!.path),
                  fit: BoxFit.contain,
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
      options = _gradeOptions
          .map((grade) => _gradeDisplayNames[grade] ?? grade)
          .toList();
      title = '選擇年級';
    } else if (filterTag == '選擇科目' ||
        filterTag.contains('文') ||
        filterTag.contains('數') ||
        filterTag.contains('理') ||
        filterTag.contains('化') ||
        filterTag.contains('物') ||
        filterTag.contains('生') ||
        filterTag.contains('社') ||
        filterTag.contains('史') ||
        filterTag.contains('地') ||
        filterTag == '公民') {
      // 使用API獲取的科目列表
      options = _subjects;
      title = '選擇科目';
    } else {
      // 如果選擇了科目，則顯示該科目的章節列表
      if (_selectedSubject != null &&
          _chaptersMap.containsKey(_selectedSubject)) {
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

  // 加載聊天歷史記錄
  Future<void> _loadChatHistory() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('user_id');
      if (userId == null) return;

      // 修改為本地開發服務器 URL 進行測試
      final response = await http.get(
        Uri.parse(
            'https://superb-backend-1041765261654.asia-east1.run.app/get_chat_history/$userId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success']) {
          setState(() {
            _chatHistory = List<Map<String, dynamic>>.from(data['history']);
          });
          print('load chat history success!');
        }
      }
    } catch (e) {
      print('加載聊天歷史記錄時出錯: $e');
    }
  }

  // 保存聊天記錄
  Future<void> _saveChatHistory(String question, String answer) async {
    try {
      print('! saving chat history...');
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('user_id');
      if (userId == null) {
        print('! Error: userId is null, cannot save chat history');
        return;
      }
      print('! User ID: $userId, Year Grade: $_yearGrade');

      final response = await http.post(
        Uri.parse(
            'https://superb-backend-1041765261654.asia-east1.run.app/save_chat_history'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'question': question,
          'answer': answer,
          'subject': _selectedSubject,
          'chapter': _selectedItem,
          'year_grade': _yearGrade, // 添加年級參數
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
      print('! Request sent, status code: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        print('! decode chat history...');
        print('! Response: ${response.body}');
        if (data['success']) {
          await _loadChatHistory(); // 重新加載歷史記錄
          print('save chat history success!');
        } else {
          print('! Error from server: ${data['message']}');
        }
      } else {
        print('! HTTP error: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      print('保存聊天記錄時出錯: $e');
    }
  }

  // Modify sendMessage method to handle single response and include user info
  void sendMessage() async {
    if (_controller.text.isEmpty && _selectedImage == null ||
        _hasSubmittedQuestion) return;

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
        try {
          final bytes = await _selectedImage!.readAsBytes();
          // 檢查圖片類型
          final mimeType = _selectedImage!.mimeType ?? 'image/jpeg';
          print("上傳圖片類型: $mimeType, 大小: ${bytes.length} bytes");
          final base64Image = base64Encode(bytes);
          requestBody["image_base64"] = base64Image;
          requestBody["image_mime_type"] = mimeType; // 將圖片類型也傳給後端
        } catch (e) {
          print("圖片編碼錯誤: $e");
          // 出錯時仍然繼續，只是不附加圖片
        }
      }

      final response = await http.post(
        Uri.parse(
            "https://superb-backend-1041765261654.asia-east1.run.app/ai/chat"),
        headers: {"Content-Type": "application/json; charset=UTF-8"},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        throw Exception(
            'Server error: ${response.statusCode}\nBody: ${response.body}');
      }

      final responseData = jsonDecode(utf8.decode(response.bodyBytes));
      setState(() {
        _response = responseData["response"] ?? "No response";
        _isLoading = false;
        _hasSubmittedQuestion = true;
      });
      print('response data');

      // 保存聊天記錄
      await _saveChatHistory(_controller.text, _response);
    } catch (e) {
      setState(() {
        _response =
            "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.";
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
                      leading:
                          Icon(Icons.photo_library, color: Color(0xFF1E3875)),
                      title: Text(
                        '從相簿選擇',
                        style: TextStyle(
                          color: Color(0xFF1E3875),
                          fontSize: 16,
                        ),
                      ),
                      onTap: () async {
                        Navigator.pop(context);
                        final XFile? image = await _picker.pickImage(
                            source: ImageSource.gallery);
                        if (image != null) {
                          _handleSelectedImage(image);
                        }
                      },
                    ),
                    ListTile(
                      leading:
                          Icon(Icons.photo_camera, color: Color(0xFF1E3875)),
                      title: Text(
                        '拍照',
                        style: TextStyle(
                          color: Color(0xFF1E3875),
                          fontSize: 16,
                        ),
                      ),
                      onTap: () async {
                        Navigator.pop(context);
                        // 修改拍照設置，明確指定 JPEG 格式和高品質
                        final XFile? photo = await _picker.pickImage(
                          source: ImageSource.camera,
                          imageQuality: 95, // 高品質
                          preferredCameraDevice: CameraDevice.rear,
                          requestFullMetadata: false, // 減少 EXIF 資訊
                        );
                        print("photo path: ${photo?.path}");
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

  Future<void> _handleSelectedImage(XFile image) async {
    print("處理圖片: ${image.path}, 格式: ${image.mimeType ?? '未知'}");

    try {
      // 讀取圖像數據
      final bytes = await image.readAsBytes();
      print("圖片大小: ${bytes.length} bytes");

      // 檢查圖像數據是否有效
      if (bytes.isNotEmpty) {
        setState(() {
          _selectedImage = image;
          _isAnalyzingImage = true; // 開始圖片解析
        });

        // 開始圖片分析流程
        await _analyzeImageWithGemini(bytes);
      } else {
        print('選擇的圖像無效');
      }
    } catch (e) {
      print('處理圖像時出錯: $e');
      // 即使出錯，仍然設置圖像路徑，讓 Image.file 嘗試直接讀取
      setState(() {
        _selectedImage = image;
      });
    }
  }

  // 新增方法：使用 Gemini API 分析圖片
  Future<void> _analyzeImageWithGemini(Uint8List imageBytes) async {
    try {
      // 將圖片轉換為 base64
      final base64Image = base64Encode(imageBytes);

      // 調用後端 API 進行圖片分析
      final response = await http.post(
        Uri.parse(
            'https://superb-backend-1041765261654.asia-east1.run.app/ai/analyze_image'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'image_base64': base64Image,
          'image_mime_type': 'image/jpeg',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success']) {
          final imageDescription = data['description'] as String;
          print('圖片分析結果: $imageDescription');

          // 調用分類 API
          await _classifyText(imageDescription);
        } else {
          print('圖片分析失敗: ${data['message']}');
          setState(() {
            _isAnalyzingImage = false;
          });
        }
      } else {
        print('圖片分析 API 請求失敗: ${response.statusCode}');
        setState(() {
          _isAnalyzingImage = false;
        });
      }
    } catch (e) {
      print('圖片分析時出錯: $e');
      setState(() {
        _isAnalyzingImage = false;
      });
    }
  }

  // 新增方法：調用分類 API
  Future<void> _classifyText(String text) async {
    try {
      final response = await http.post(
        Uri.parse(
            'https://superb-backend-1041765261654.asia-east1.run.app/ai/classify_text'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success']) {
          final classificationLabel = data['predicted_label'] as String;
          final confidence = data['confidence'] as double;

          print(
              '分類結果: $classificationLabel (信心度: ${(confidence * 100).toStringAsFixed(1)}%)');

          // 將分類結果輸入到對話框中
          setState(() {
            // _controller.text = '分類標籤: 氣體 (信心度: 93.2%)\n';
            _controller.text =
                '分類標籤: 圖片分析結果: $text\n\n分類標籤: $classificationLabel (信心度: ${(confidence * 100).toStringAsFixed(1)}%)';
            _isAnalyzingImage = false;
          });
        } else {
          print('文字分類失敗: ${data['message']}');
          setState(() {
            _controller.text = '圖片分析結果: $text\n\n分類失敗，請手動輸入問題。';
            _isAnalyzingImage = false;
          });
        }
      } else {
        print('分類 API 請求失敗: ${response.statusCode}');
        setState(() {
          _controller.text = '圖片分析結果: $text\n\n分類 API 請求失敗，請手動輸入問題。';
          _isAnalyzingImage = false;
        });
      }
    } catch (e) {
      print('文字分類時出錯: $e');
      setState(() {
        _controller.text = '圖片分析結果: $text\n\n分類時出現錯誤，請手動輸入問題。';
        _isAnalyzingImage = false;
      });
    }
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
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _chatHistory.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: Colors.grey[300],
                  ),
                  itemBuilder: (context, index) {
                    final chat = _chatHistory[index];
                    final question = chat['question'] as String;
                    final answer = chat['answer'] as String;
                    final timestamp =
                        DateTime.parse(chat['timestamp'] as String);
                    final formattedTime =
                        DateFormat('yyyy/MM/dd HH:mm').format(timestamp);

                    return ListTile(
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            question,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3875),
                              fontSize: 16,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4),
                          _buildResponse(
                            answer.length > 32
                                ? '${answer.substring(0, 32)}...'
                                : answer,
                            fontSize: 14,
                            textColor: Colors.grey[600]!,
                            textAlign: TextAlign.left,
                          ),
                          SizedBox(height: 4),
                          Text(
                            formattedTime,
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          _controller.text = question;
                          _response = answer;
                          _hasSubmittedQuestion = true;
                        });
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

            // 圖片解析中的載入動畫
            if (_isAnalyzingImage)
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
                            Icons.image_search,
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
                      Text('圖片解析中...',
                          style: TextStyle(color: Colors.white, fontSize: 16)),
                      SizedBox(height: 8),
                      Text('正在分析圖片內容並進行分類',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 14)),
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
                              Icon(Icons.arrow_back,
                                  color: Colors.white, size: 14),
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
                            icon: Icon(Icons.history,
                                size: 18, color: Color(0xFF1E3875)),
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
                            icon: Icon(
                                _isAnalyzingImage
                                    ? Icons.hourglass_empty
                                    : Icons.photo_camera,
                                size: 18,
                                color:
                                    (_hasSubmittedQuestion || _isAnalyzingImage)
                                        ? Colors.grey
                                        : Color(0xFF1E3875)),
                            label: Text(
                              _isAnalyzingImage ? '解析中' : '拍照',
                              style: TextStyle(
                                color:
                                    (_hasSubmittedQuestion || _isAnalyzingImage)
                                        ? Colors.grey
                                        : Color(0xFF1E3875),
                                fontSize: 14,
                              ),
                            ),
                            onPressed:
                                (!_hasSubmittedQuestion && !_isAnalyzingImage)
                                    ? _handleImageSelection
                                    : null,
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
                          left: MediaQuery.of(context).size.width / 2 -
                              70, // 水平置中
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
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
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
                                            color: Color(0xFF1E3875)
                                                .withOpacity(0.6),
                                            fontSize: 16,
                                          ),
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 8),
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
                                      icon:
                                          Icon(Icons.send, color: Colors.white),
                                      onPressed: !_hasSubmittedQuestion
                                          ? sendMessage
                                          : null,
                                      style: IconButton.styleFrom(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Filter chips (fixed at input field below)
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
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
                                          borderRadius:
                                              BorderRadius.circular(8),
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
                                                padding:
                                                    EdgeInsets.only(right: 8),
                                                child: Icon(
                                                  Icons.eco,
                                                  color: Colors.white,
                                                  size: 18,
                                                ),
                                              )
                                            else if (filter == '公民')
                                              Padding(
                                                padding:
                                                    EdgeInsets.only(right: 8),
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
                                margin: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: Stack(
                                  children: [
                                    GestureDetector(
                                      onTap: _showFullImage,
                                      child: Container(
                                        height: 120,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                              color: Colors.grey[300]!,
                                              width: 1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(11),
                                          child: Image.file(
                                            File(_selectedImage!.path),
                                            fit: BoxFit.cover,
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
                                            color:
                                                Colors.black.withOpacity(0.5),
                                            borderRadius:
                                                BorderRadius.circular(12),
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
                                  maxHeight:
                                      MediaQuery.of(context).size.height * 0.5,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Question display
                                      Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Text(
                                          _controller.text.isEmpty
                                              ? "Dogtor, 請幫我回答這一個題目 ;-; "
                                              : _controller.text,
                                          style: TextStyle(
                                            color: Color(0xFF1E3875),
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      // Divider
                                      Divider(
                                          height: 1, color: Colors.grey[300]),
                                      // Response content
                                      Padding(
                                        padding: EdgeInsets.all(16),
                                        child: _buildResponse(
                                          _response,
                                          fontSize: 14,
                                          textColor: Colors.black87,
                                          textAlign: TextAlign.left,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            // Bottom padding
                            SizedBox(
                                height: MediaQuery.of(context).padding.bottom),
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

  Widget _buildResponse(
    String response, {
    double fontSize = 16,
    Color textColor = Colors.black,
    TextAlign textAlign = TextAlign.left,
    bool selectable = true,
    double latexScaleFactor = 1.1,
  }) {
    return Container(
      alignment: textAlign == TextAlign.center
          ? Alignment.center
          : textAlign == TextAlign.right
              ? Alignment.centerRight
              : Alignment.centerLeft,
      child: Markdown(
        selectable: selectable,
        data: response,
        shrinkWrap: true,
        physics: ClampingScrollPhysics(),
        styleSheet: MarkdownStyleSheet(
          p: TextStyle(
            color: textColor,
            fontSize: fontSize,
          ),
          h1: TextStyle(
            color: textColor,
            fontSize: fontSize * 1.5,
            fontWeight: FontWeight.bold,
          ),
          h2: TextStyle(
            color: textColor,
            fontSize: fontSize * 1.3,
            fontWeight: FontWeight.bold,
          ),
          h3: TextStyle(
            color: textColor,
            fontSize: fontSize * 1.2,
            fontWeight: FontWeight.bold,
          ),
          h4: TextStyle(
            color: textColor,
            fontSize: fontSize * 1.1,
            fontWeight: FontWeight.bold,
          ),
          h5: TextStyle(
            color: textColor,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
          ),
          h6: TextStyle(
            color: textColor,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
          ),
          listBullet: TextStyle(
            color: textColor,
            fontSize: fontSize,
          ),
        ),
        builders: {
          'latex': LatexElementBuilder(
            textStyle: TextStyle(
              color: textColor,
              fontSize: fontSize,
            ),
            textScaleFactor: latexScaleFactor,
          ),
        },
        extensionSet: md.ExtensionSet(
          [LatexBlockSyntax()],
          [LatexInlineSyntax()],
        ),
      ),
    );
  }
}
