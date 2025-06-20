import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';


class OnboardingChat extends StatefulWidget {
  const OnboardingChat({super.key});

  @override
  State<OnboardingChat> createState() => _OnboardingChatState();
}

class _OnboardingChatState extends State<OnboardingChat> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<String, String> _userData = {};
  int _currentStep = 0;
  bool _isEditing = false;
  int? _editingIndex;

  final List<Map<String, dynamic>> _conversationSteps = [
    {
      'message': '嗨！我是 Dogtor 🐶 很高興認識你～',
      'isUser': false,
      'key': null,
    },
    {
      'message': '請問你叫什麼名字呢？',
      'isUser': false,
      'key': 'name',
    },
    {
      'message': '你好啊！你現在是幾年級呢？',
      'isUser': false,
      'key': 'learning',
    },
    {
      'message': '那你最近都在學些什麼呢？',
      'isUser': false,
      'key': 'learning',
    },
    {
      'message': '了解，那你有什麼興趣或嗜好嗎？',
      'isUser': false,
      'key': 'hobby',
    },
    {
      'message': '好的！那你在最後還有什麼想要補充或是修改的嗎？',
      'isUser': false,
      'key': null,
    },
    {
      'message': '好的！感謝你告訴我你的事 🐾 我們開始吧！',
      'isUser': false,
      'key': null,
    },
  ];

  List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _messages = [_conversationSteps[0]];
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSubmit(String text) {
    if (text.trim().isEmpty) return;

    setState(() {
      if (_isEditing && _editingIndex != null) {
        // Update existing answer
        _messages[_editingIndex!]['message'] = text;
        final key = _messages[_editingIndex!]['key'];
        if (key != null) {
          _userData[key] = text;
        }
        _isEditing = false;
        _editingIndex = null;
      } else {
        // Add new answer
        final currentKey = _conversationSteps[_currentStep]['key'];
        _messages.add({
          'message': text,
          'isUser': true,
          'key': currentKey,
        });
        if (currentKey != null) {
          _userData[currentKey] = text;
        }
        _currentStep++;
        if (_currentStep < _conversationSteps.length) {
          _messages.add(_conversationSteps[_currentStep]);
        }
      }
      _textController.clear();
    });
    _scrollToBottom();
  }

  void _startEditing(int index) {
    if (_messages[index]['isUser']) {
      setState(() {
        _isEditing = true;
        _editingIndex = index;
        _textController.text = _messages[index]['message'];
      });
    }
  }

  Widget _buildMessage(Map<String, dynamic> message, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message['isUser'])
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey[300],
                child: const Icon(Icons.pets, color: Colors.white),
              ),
            ),
          Flexible(
            fit: FlexFit.loose,
            child: GestureDetector(
              onTap: () => _startEditing(index),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: message['isUser'] ? Colors.blue[100] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  message['message'],
                  style: TextStyle(
                    color: message['isUser'] ? Colors.black87 : Colors.black87,
                  ),
                ),
              ),
            ),
          ),
          if (message['isUser'])
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              
            ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    final isDone = _currentStep + 2 >= _conversationSteps.length;
    if (isDone) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: 40,
                  maxHeight: 120,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  autofocus: true,
                  controller: _textController,
                  minLines: 1,
                  maxLines: 5,
                  style: const TextStyle(color: Color(0xFF1E3875), fontSize: 16),
                  decoration: InputDecoration(
                    hintText: _isEditing ? '編輯回答...' : '輸入你的回答...'
                        ,
                    hintStyle: TextStyle(
                      color: const Color(0xFF1E3875).withOpacity(0.6),
                      fontSize: 16,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  onSubmitted: _handleSubmit,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E3875),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: () => _handleSubmit(_textController.text),
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final answered = _messages.where((m) => m['isUser']).toList();
    final isDone = _currentStep + 2 >= _conversationSteps.length;
    const inputBarHeight = 84.0; // input bar + some gap
    const avatarQuestionBottomPadding = inputBarHeight + 24;

    return Scaffold(
      appBar: AppBar(
        title: const Text('歡迎使用'),
        backgroundColor: const Color(0xFF102031),
      ),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Stack(
          children: [
            // Main content: chat bubbles and input bar
            Column(
              children: [
                // Chat bubbles
                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: answered.map((msg) {
                          final originalIndex = _messages.indexOf(msg);
                          final isEditingBubble = _isEditing && _editingIndex == originalIndex;
                          return GestureDetector(
                            onTap: () => _startEditing(originalIndex),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: size.width * 0.11,
                                maxWidth: size.width * 0.9,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isEditingBubble
                                      ? const Color.fromARGB(255, 215, 235, 251)
                                      : const Color.fromARGB(255, 255, 255, 255),
                                  borderRadius: BorderRadius.circular(20),
                                  border: isEditingBubble
                                      ? Border.all(color:const Color.fromARGB(255, 234, 246, 255)!, width: 2)
                                      : null,
                                ),
                                child: Text(
                                  msg['message'],
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isEditingBubble
                                        ? Colors.black87
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      if (isDone)
                        Column(
                          children: [
                            const SizedBox(height: 12),
                            Text(
                              '🎉 完成囉！謝謝你的回答。',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color.fromARGB(255, 255, 255, 255),
                                foregroundColor: Colors.blue,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              icon: const Icon(Icons.arrow_forward),
                              label: const Text('進入首頁'),
                              onPressed: () {
                                Navigator.of(context).pushReplacementNamed('/home');
                              },
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                // Typing bar at the bottom
                _buildInputBar(),
              ],
            ),
            // Fixed avatar and question at center, above keyboard and input bar
            IgnorePointer(
              child: Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: EdgeInsets.only(bottom: avatarQuestionBottomPadding),
                  child: FractionallySizedBox(
                    widthFactor: 0.92,
                    child: Container(
                      // color: Colors.red.withOpacity(0.1), // debug
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TweenAnimationBuilder<Offset>(
                            tween: Tween(begin: const Offset(0, .3), end: Offset.zero),
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOut,
                            builder: (context, offset, child) {
                              return FractionalTranslation(
                                translation: offset,
                                child: child,
                              );
                            },
                            child: const CircleAvatar(
                              radius: 70,
                              backgroundImage: AssetImage('assets/images/question-corgi.png'),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: DefaultTextStyle(
                              style: const TextStyle(fontSize: 20, color: Colors.white),
                              child: AnimatedTextKit(
                                key: ValueKey<int>(_currentStep),
                                isRepeatingAnimation: false,
                                totalRepeatCount: 1,
                                animatedTexts: _currentStep == 0
                                  ? [
                                      TypewriterAnimatedText(
                                        _conversationSteps[_currentStep]['message'],
                                        speed: const Duration(milliseconds: 50),
                                      ),
                                      TypewriterAnimatedText(
                                        _conversationSteps[_currentStep + 1]['message'],
                                        speed: const Duration(milliseconds: 50),
                                      ),
                                    ]
                                  : [
                                      TypewriterAnimatedText(
                                        _conversationSteps[_currentStep + 1]['message'],
                                        speed: const Duration(milliseconds: 50),
                                      ),
                                    ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
} 