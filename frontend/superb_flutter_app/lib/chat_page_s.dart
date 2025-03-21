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

class Message {
  final String text;
  final bool isUser;
  final XFile? image;
  final String? subject;
  final String? chapter;
  final List<String> tags;

  Message({
    required this.text, 
    required this.isUser, 
    this.image, 
    this.subject, 
    this.chapter,
    this.tags = const [],
  });
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  bool _isKeyboardVisible = false;
  bool _isLoading = false;
  
  // Chat messages
  List<Message> _messages = [];
  
  final List<String> _subjects = [
    '國中',
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
  
  String? _selectedSubject = '國中';
  List<String> _chapters = [];
  String? _selectedChapter = '公民';
  
  // Currently selected tags
  String? _selectedTag = '憲政體制的分權制衡';

  @override
  void initState() {
    super.initState();
    _loadChapters();
  }

  Future<void> _loadChapters() async {
    // In a real app, you'd load chapters based on selected subject
    // For now, we'll just set some sample data
    setState(() {
      _chapters = ['公民', '歷史', '地理'];
    });
  }

  void _sendMessage() async {
    if (_controller.text.trim().isEmpty && _selectedImage == null) return;
    
    final userMessage = Message(
      text: _controller.text,
      isUser: true,
      image: _selectedImage,
      subject: _selectedSubject,
      chapter: _selectedChapter,
      tags: _selectedTag != null ? [_selectedTag!] : [],
    );
    
    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
      _controller.clear();
    });
    
    try {
      Map<String, dynamic> requestBody = {
        "user_message": userMessage.text,
        "subject": _selectedSubject,
        "chapter": _selectedChapter,
      };

      // Handle images
      if (userMessage.image != null) {
        final bytes = await userMessage.image!.readAsBytes();
        final base64Image = base64Encode(bytes);
        requestBody["image_base64"] = base64Image;
      }

      final response = await http.post(
        Uri.parse("http://127.0.0.1:8000/chat"),
        headers: {"Content-Type": "application/json; charset=UTF-8"},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}\nBody: ${response.body}');
      }

      final responseData = jsonDecode(utf8.decode(response.bodyBytes));
      
      setState(() {
        _messages.add(Message(
          text: responseData["response"] ?? "No response",
          isUser: false,
          subject: _selectedSubject,
          chapter: _selectedChapter,
          tags: _selectedTag != null ? [_selectedTag!] : [],
        ));
        _isLoading = false;
        _selectedImage = null;
      });
    } catch (e) {
      setState(() {
        _messages.add(Message(
          text: "Error: $e",
          isUser: false,
        ));
        _isLoading = false;
        _selectedImage = null;
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
                    setState(() {
                      _selectedImage = image;
                    });
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
                    setState(() {
                      _selectedImage = photo;
                    });
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen for keyboard events
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    _isKeyboardVisible = bottomInset > 0;
    
    return Scaffold(
      backgroundColor: Color(0xFF102031),
      body: SafeArea(
        child: Column(
          children: [
            // App Bar
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                    tooltip: '返回',
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        '問題',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.info_outline, color: Colors.white),
                    onPressed: () {
                      // Show info dialog
                    },
                  ),
                ],
              ),
            ),
            
            // Chat area
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/question-sea.png'),
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                ),
                child: _messages.isEmpty
                    ? _buildEmptyState()
                    : _buildChatList(),
              ),
            ),
            
            // Subject, Chapter, and Tag selection bar
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: Colors.transparent,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Subject chip
                    Container(
                      margin: EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Color(0xFFE0A779),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.psychology, size: 16, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            _selectedSubject ?? '選擇科目',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    
                    // Chapter chip
                    Container(
                      margin: EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Color(0xFF80BBE7),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.book, size: 16, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            _selectedChapter ?? '選擇章節',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    
                    // Tag chip
                    if (_selectedTag != null)
                    Container(
                      decoration: BoxDecoration(
                        color: Color(0xFF9BBCE7),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Text(
                        _selectedTag!,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Input area
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // History button
                  IconButton(
                    icon: Icon(Icons.history, color: Colors.white),
                    onPressed: () {
                      // Show history
                    },
                  ),
                  
                  // Text input
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      margin: EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          // Camera button
                          IconButton(
                            icon: Icon(Icons.camera_alt, color: Color(0xFF102031)),
                            onPressed: _handleImageSelection,
                          ),
                          
                          // Text field
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              style: TextStyle(color: Colors.black),
                              decoration: InputDecoration(
                                hintText: "輸入您的問題",
                                hintStyle: TextStyle(color: Colors.grey),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 8,
                                ),
                              ),
                              maxLines: 5,
                              minLines: 1,
                            ),
                          ),
                          
                          // Selected image indicator
                          if (_selectedImage != null)
                          Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Icon(
                              Icons.image,
                              color: Color(0xFF1E3875),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Send button
                  Container(
                    decoration: BoxDecoration(
                      color: Color(0xFF80BBE7),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                      ),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Fox character
          Image.asset(
            'assets/images/question-corgi.png',
            height: 150,
          ),
          SizedBox(height: 20),
          Text(
            '輸入您的問題或拍照上傳',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      reverse: true,
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (_isLoading && index == 0) {
          return _buildTypingIndicator();
        }
        
        final messageIndex = _isLoading ? index - 1 : index;
        final message = _messages[_messages.length - 1 - messageIndex];
        
        return _buildMessageBubble(message);
      },
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(top: 16),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF1E3875),
              ),
            ),
            SizedBox(width: 8),
            Text('思考中...', style: TextStyle(color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Message message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 16,
          left: message.isUser ? 64 : 0,
          right: message.isUser ? 0 : 64,
        ),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: message.isUser ? Color(0xFF80BBE7) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subject and chapter tags if available
            if (!message.isUser && (message.subject != null || message.chapter != null))
            Wrap(
              spacing: 8,
              children: [
                if (message.subject != null)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(0xFFE0A779),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    message.subject!,
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                
                if (message.chapter != null)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(0xFF80BBE7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    message.chapter!,
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                
                ...message.tags.map((tag) => Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(0xFF9BBCE7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                )).toList(),
              ],
            ),
            
            if (!message.isUser && (message.subject != null || message.chapter != null))
            SizedBox(height: 8),
            
            // Image if available
            if (message.image != null)
            FutureBuilder<Uint8List>(
              future: message.image!.readAsBytes(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      snapshot.data!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  );
                }
                return Container(
                  height: 150,
                  width: double.infinity,
                  color: Colors.grey.shade300,
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              },
            ),
            
            if (message.image != null)
            SizedBox(height: 8),
            
            // Message text
            message.isUser
                ? Text(
                    message.text,
                    style: TextStyle(color: Colors.white),
                  )
                : _buildMarkdownText(message.text),
          ],
        ),
      ),
    );
  }

  Widget _buildMarkdownText(String text) {
    return Markdown(
      selectable: true,
      data: text,
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(color: Colors.black87),
        h1: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        h2: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        h3: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        code: TextStyle(
          backgroundColor: Colors.grey.shade200,
          color: Colors.black87,
          fontFamily: 'monospace',
        ),
        codeblockDecoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      builders: {
        'latex': LatexElementBuilder(
          textStyle: TextStyle(color: Colors.black87),
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