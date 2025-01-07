import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_markdown_latex/flutter_markdown_latex.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'home_page.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://zgccuixkrlsfmsgblbpe.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpnY2N1aXhrcmxzZm1zZ2JsYnBlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzU5NjI3MzksImV4cCI6MjA1MTUzODczOX0.6SVEK8ib3RDeQ7-Qj3oGUU6e0j_baKkfhH6MoL03sQM',
  );
  
  runApp(MyApp());
}

// MyApp: 應用程序的根組件
// 負責設置應用的整體主題、顏色方案和字體樣式
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI 學習助手',
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Color(0xFF1B3B4B), // 深藍色微偏綠
        colorScheme: ColorScheme.dark(
          primary: Color(0xFF235A6B),    // 藍綠色
          secondary: Color(0xFF2D7A8F),   // 淺藍綠色
          surface: Color(0xFF1B3B4B),     // 深藍色微偏綠
        ),
        textTheme: TextTheme(
          displayLarge: TextStyle(fontSize: 40, fontFamily: 'Heavy', fontWeight: FontWeight.bold, color: Colors.white),
          displayMedium: TextStyle(fontSize: 32, fontFamily: 'Medium', fontWeight: FontWeight.w600, color: Colors.white),
          bodyLarge: TextStyle(fontSize: 20, fontFamily: 'Normal', fontWeight: FontWeight.normal, color: Colors.white70),
          bodyMedium: TextStyle(fontSize: 16, fontFamily: 'Normal', fontWeight: FontWeight.normal, color: Colors.white70),
        ),
      ),
      home: HomePage(),
    );
  }
}

// ChatPage: 聊天界面的有狀態組件
// 作為聊天功能的容器組件，管理用戶輸入和 AI 回應的狀態
class ChatPage extends StatefulWidget {
  @override
  _ChatPageState createState() => _ChatPageState();
}

// _ChatPageState: ChatPage 的狀態管理類
// 實現聊天界面的核心功能，包括：
// 1. 處理用戶輸入
// 2. 發送 HTTP 請求到後端
// 3. 接收並顯示 AI 回應
// 4. 管理 UI 狀態
class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  String _response = ""; // 存儲 AI 的回應
  final _supabase = Supabase.instance.client;
  List<String> _items = [];  // 存儲從數據庫獲取的項目
  String? _selectedItem;     // 存儲選中的項目
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

  @override
  void initState() {
    super.initState();
    _loadItems();  // 當頁面初始化時加載數據
  }

  // 從 Supabase 加載數據
  Future<void> _loadItems() async {
    try {
      print('開始加載數據...');
      final response = await _supabase
          .from('chemistry_chapter')
          .select('chapter_name');

      if (response != null) {
        final uniqueItems = Set<String>.from(
          (response as List).map((item) => item['chapter_name'] as String)
        ).toList();

        setState(() {
          _items = uniqueItems;
        });
        
        print('成功加載數據: $_items');
      }
    } catch (e) {
      print('加載數據時出錯: $e');
      // 使用暫時列表
      setState(() {
        _items = [
          '第一章 緒論',
          '第二章 物質的組成與特性',
          '第三章 化學計量',
          '第四章 原子結構與元素週期表',
          '第五章 化學鍵結',
        ];
      });
    }
  }

  // sendMessage: 處理發送消息的核心方法
  // 將用戶輸入發送到後端 API 並處理回應
  void sendMessage() async {
    setState(() {
      _isLoading = true; // 開始加載
    });
    
    try {
      Map<String, dynamic> requestBody = {
        "user_message": _controller.text,
      };

      // 如果有選擇圖片，添加到請求中
      if (_selectedImage != null) {
        final bytes = await _selectedImage!.readAsBytes();
        final base64Image = base64Encode(bytes);
        requestBody["image_base64"] = base64Image;
      }

      final response = await http.post(
        Uri.parse("http://127.0.0.1:8000/chat"),
        headers: {"Content-Type": "application/json; charset=UTF-8"},
        body: jsonEncode(requestBody),
      );

      final responseData = jsonDecode(utf8.decode(response.bodyBytes));
      setState(() {
        _response = responseData["response"] ?? "No response";
        _selectedImage = null;
        _isLoading = false; // 加載完成
      });
    } catch (e) {
      setState(() {
        _response = "Error: $e";
        _isLoading = false; // 發生錯誤時也要結束加載狀態
      });
      print("Error: $e");
    }
  }

  // 處理選擇圖片或拍照
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
                    // 處理選擇的圖片
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
                    // 處理拍攝的照片
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

  // 處理選擇的圖片
  void _handleSelectedImage(XFile image) {
    setState(() {
      _selectedImage = image;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: Color(0xFF1B3B4B), // 更改為相同的深藍色微偏綠
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            SizedBox(height: 40),
            Text(
              "--- AI 問問題 ---",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 30),
            Row(
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
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedSubject = newValue;
                        });
                      },
                      hint: Text('選擇科目', style: TextStyle(color: Color(0xFF1E3875))),
                    ),
                  ),
                ),
                SizedBox(width: 16), // 兩個下拉選單之間的間距
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
            SizedBox(height: 16),
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
                    height: 56, // 與輸入框同高
                    child: ElevatedButton(
                      onPressed: sendMessage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color.fromARGB(255, 76, 94, 135),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.horizontal(right: Radius.circular(8)),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: Text("查詢", style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            if (_selectedImage != null) ...[
              SizedBox(height: 16),
              Stack(
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
      ),
    );
  }

  // _buildResponse: 構建顯示 AI 回應的 Widget
  // 使用 Markdown_LaTex 渲染器來顯示格式化的回應文本
  Widget _buildResponse(String response) {
    return Markdown(
      selectable: true, // 支持選擇文字
      data: response,
      builders: {
        'latex': LatexElementBuilder(
          textStyle: Theme.of(context).textTheme.bodyLarge!,
          textScaleFactor: 1.1,
        ),
      },
      extensionSet: md.ExtensionSet(
        [LatexBlockSyntax()], // 支持 LaTeX block 語法
        [LatexInlineSyntax()], // 支持 LaTeX inline 語法
      ),
    );
  }
}
