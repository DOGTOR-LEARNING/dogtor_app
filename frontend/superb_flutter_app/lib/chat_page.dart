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
  String _response = ""; // 存儲 AI 的回應
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage; // 添加這個變量來存儲選擇的圖片
  
  final List<String> _subjects = [
    '國文',
    '英文',
    '數學',
    '理化',
    '物理',
    '化學',
    '地科',
    '生物',
    '社會',
    '歷史',
    '地理',
    '公民'
  ];
  
  String? _selectedSubject;  // 添加這個變量來存儲選擇的科目
  bool _isLoading = false; // 添加這個變量來追踪加載狀態
  List<String> _items = [];  // Initialize _items to an empty list
  String? _selectedItem;     // Initialize _selectedItem to null

  @override
  void initState() {
    super.initState();
    _loadItems();  // Now fetches from backend
  }

  Future<void> _loadItems() async {
    if (_selectedSubject == null) {
      setState(() {
        _items = []; // 如果沒有選擇科目，清空章節列表
        _selectedItem = null; // 重要：清空選擇的項目
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
          csvPath = ''; // 其他科目暫時不處理
      }

      if (csvPath.isEmpty) {
        setState(() {
          _items = [];
          _selectedItem = null; // 重要：清空選擇的項目
        });
        return;
      }

      // 載入 CSV 檔案
      final String data = await DefaultAssetBundle.of(context).loadString(csvPath);
      final List<String> rows = data.split('\n');
      
      // 從 CSV 中提取章節名稱
      final List<String> chapters = rows.skip(1)
          .where((row) => row.trim().isNotEmpty)
          .map((row) {
            final cols = row.split(',');
            return cols[4]; // 章節名稱
          })
          .toSet() // 去除重複項
          .toList();
      
      setState(() {
        _items = chapters;
        _selectedItem = chapters.isNotEmpty ? chapters[0] : null; // 選擇第一個章節或設為 null
      });
    } catch (e) {
      print('Error loading chapters: $e');
      setState(() {
        _items = [];
        _selectedItem = null;
      });
    }
  }

  void _onSubjectChanged(String? newValue) {
    setState(() {
      _selectedSubject = newValue;
      _selectedItem = null; // 重要：清空選擇的項目
    });
    _loadItems(); // 重新載入章節
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
                Image.file(File(_selectedImage!.path)),
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

  void sendMessage() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      Map<String, dynamic> requestBody = {
        "user_message": _controller.text,
        "subject": _selectedSubject,
        "chapter": _selectedItem,
      };

      // 處理圖片
      if (_selectedImage != null) {
        final bytes = await _selectedImage!.readAsBytes();
        final base64Image = base64Encode(bytes);
        requestBody["image_base64"] = base64Image;
      }

      final response = await http.post(
        Uri.parse("https://superb-backend-1041765261654.asia-east1.run.app/ai/chat"),
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
        //_selectedImage = null; // Clear image after response is received
      });
    } catch (e) {
      setState(() {
        _response = "Error: $e";
        _isLoading = false;
      });
      print("Detailed error: $e");
    }
  }

  Future<void> _handleImageSelection() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          color: Color(0xFF1E3875),
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.photo_library, color: Colors.white),
                title: Text('從相簿選擇', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                  if (image != null) {
                    _handleSelectedImage(image);
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_camera, color: Colors.white),
                title: Text('拍照', style: TextStyle(color: Colors.white)),
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
        );
      },
    );
  }

  void _handleSelectedImage(XFile image) {
    setState(() {
      _selectedImage = image;
    });
  }

  void _showDifficultyDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String difficulty = 'Medium'; // Default difficulty
        return AlertDialog(
          title: Text('Set Question Difficulty'),
          content: DropdownButton<String>(
            value: difficulty,
            items: ['Easy', 'Medium', 'Hard'].map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  difficulty = newValue;
                });
              }
            },
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white, // 設定按鈕內文字的顏色
              ),
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white, // 設定按鈕內文字的顏色
              ),
              child: Text('Submit'),
              onPressed: () {
                _submitQuestion(difficulty);
                Navigator.of(context).pop();
                _selectedImage = null;
              },
            ),
          ],
        );
      },
    );
  }

  void _submitQuestion(String difficulty) async {
    try {
      String q_id = DateTime.now().millisecondsSinceEpoch.toString();
      Map<String, dynamic> requestBody = {
        "q_id": q_id,
        "subject": _selectedSubject,
        "chapter": _selectedItem,
        "description": _controller.text,
        "difficulty": difficulty,
        "simple_answer": "", // Placeholder for now
        "detailed_answer": _response, 
      };

      if (_selectedImage != null) {
        final bytes = await _selectedImage!.readAsBytes();
        final base64Image = base64Encode(bytes);
        requestBody["image_base64"] = base64Image;
      }

      final response = await http.post(
        Uri.parse("https://superb-backend-1041765261654.asia-east1.run.app/submit_question"),
        headers: {"Content-Type": "application/json; charset=UTF-8"},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to submit question: ${response.statusCode}');
      }

      print('Question submitted successfully.');
    } catch (e) {
      print('Error submitting question: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: Color(0xFF102031),
        ),
        padding: EdgeInsets.zero,
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        
        child: Stack(
          children: [
            Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.asset('assets/images/question-sea.png'),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(height: 60),
                        Image.asset('assets/images/question-corgi.png'),
                      ],
                    ),
                    Positioned(
                      bottom: 5,
                      left: 5,
                      right: 5,
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonFormField<String>(
                                value: _selectedSubject,
                                decoration: InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: Colors.transparent,
                                ),
                                icon: Icon(Icons.arrow_drop_down, color: Color(0xFF1E3875)),
                                dropdownColor: Colors.white,
                                style: TextStyle(
                                  color: Color(0xFF1E3875),
                                  fontSize: 16,
                                ),
                                items: _subjects.map((String subject) {
                                  return DropdownMenuItem<String>(
                                    value: subject,
                                    child: Text(subject),
                                  );
                                }).toList(),
                                onChanged: _onSubjectChanged,
                                hint: Text('選擇科目', style: TextStyle(color: Color(0xFF1E3875))),
                              ),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: _selectedItem,
                                decoration: InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: Colors.transparent,
                                ),
                                icon: Icon(Icons.arrow_drop_down, color: Color(0xFF1E3875)),
                                dropdownColor: Colors.white,
                                style: TextStyle(
                                  color: Color(0xFF1E3875),
                                  fontSize: 16,
                                ),
                                items: _items.map((String item) {
                                  return DropdownMenuItem<String>(
                                    value: item,
                                    child: Text(item),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    _selectedItem = newValue;
                                  });
                                },
                                hint: Text('選擇章節', style: TextStyle(color: Color(0xFF1E3875))),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          style: TextStyle(color: Color(0xFF1E3875)),
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            hintText: "輸入您的問題",
                            hintStyle: TextStyle(color: Color(0xFF1E3875).withOpacity(0.6)),
                            prefixIcon: IconButton(
                              icon: Icon(Icons.photo_camera, color: Color(0xFF1E3875)),
                              onPressed: _handleImageSelection,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: sendMessage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color.fromARGB(255, 76, 94, 135),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.horizontal(right: Radius.circular(8)),
                            ),
                            padding: EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: Icon(
                            Icons.send,  // 或者用 Icons.send
                            color: Colors.white,
                          ),
                          //child: Text("查詢", style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                if (_selectedImage != null) ...[
                  SizedBox(height: 16),
                  GestureDetector(
                    onTap: _showFullImage,
                    child: Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Container(
                          height: 100,
                          width: 100,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
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
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.white),
                          onPressed: () {
                            setState(() {
                              _selectedImage = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                ],
                Expanded(
                  child: _isLoading 
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              color: Colors.white,
                            ),
                            SizedBox(height: 16),
                            Text(
                              '思考中...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _buildResponse(_response),
                ),
              ],
            ),
            
            // 添加返回按鈕
            Positioned(
              top: 40,
              left: 16,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'chat_fab',
        onPressed: _showDifficultyDialog,
        backgroundColor: Colors.white,
        child: Icon(Icons.add),
        
      ),
    );
  }

  Widget _buildResponse(String response) {
    return Markdown(
      selectable: true,
      data: response,
      builders: {
        'latex': LatexElementBuilder(
          textStyle: Theme.of(context).textTheme.bodyLarge!,
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