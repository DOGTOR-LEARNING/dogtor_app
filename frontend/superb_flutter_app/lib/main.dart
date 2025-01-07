import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_markdown_latex/flutter_markdown_latex.dart';
import 'package:markdown/markdown.dart' as md;

void main() {
  runApp(MyApp());
}

// MyApp: 應用程序的根組件
// 負責設置應用的整體主題、顏色方案和字體樣式
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI 問問題',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Color(0xFF0B1026), // 深邃的宇宙背景色
        colorScheme: ColorScheme.dark(
          primary: Color(0xFF4A90E2),    // 明亮的藍色
          secondary: Color(0xFF7B88FF),   // 紫羅蘭色
          surface: Color(0xFF1B2137),     // 稍淺的背景色，用於卡片
        ),
        textTheme: TextTheme(
          displayLarge: TextStyle(fontSize: 40, fontFamily: 'Heavy', fontWeight: FontWeight.bold, color: Colors.white),
          displayMedium: TextStyle(fontSize: 32, fontFamily: 'Medium', fontWeight: FontWeight.w600, color: Colors.white),
          bodyLarge: TextStyle(fontSize: 20, fontFamily: 'Normal', fontWeight: FontWeight.normal, color: Colors.white70),
          bodyMedium: TextStyle(fontSize: 16, fontFamily: 'Normal', fontWeight: FontWeight.normal, color: Colors.white70),
        ),
      ),
      home: ChatPage(),
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

  // sendMessage: 處理發送消息的核心方法
  // 將用戶輸入發送到後端 API 並處理回應
  void sendMessage() async {
    try {
      final response = await http.post(
        Uri.parse("http://127.0.0.1:8000/chat"), // 替換成後端的實際位址
        headers: {"Content-Type": "application/json; charset=UTF-8"},
        body: jsonEncode({"user_message": _controller.text}),
      );

      final responseData = jsonDecode(utf8.decode(response.bodyBytes)); // 解碼並解析 JSON
      // print("Received Response: ${responseData["response"]}");

      setState(() {
        _response = responseData["response"] ?? "No response"; // 提取 response 值
      });
    } catch (e) {
      setState(() {
        _response = "Error: $e"; // 捕捉錯誤，顯示在 UI 上
      });
      print("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("AI 問問題", style: Theme.of(context).textTheme.displayMedium,),), // 使用主題設置字體
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              style: TextStyle(color: Colors.white), // 輸入文字顏色
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Color(0xFF4A90E2), width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Color(0xFF7B88FF), width: 2),
                ),
                labelText: "輸入訊息",
                labelStyle: TextStyle(color: Color(0xFF4A90E2)),
                fillColor: Color(0xFF1B2137),
                filled: true,
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: sendMessage,
              child: Text("Send"),
            ),
            SizedBox(height: 16),
            Expanded(
              child: _buildResponse(_response),
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