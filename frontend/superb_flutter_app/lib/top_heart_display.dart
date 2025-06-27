import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class TopHeartDisplay extends StatefulWidget {
  final VoidCallback? onTap;
  final Function(Duration?)? onInsufficientHearts; // 當心數不足時的回調，傳遞剩餘時間
  
  const TopHeartDisplay({
    Key? key,
    this.onTap,
    this.onInsufficientHearts,
  }) : super(key: key);

  @override
  _TopHeartDisplayState createState() => _TopHeartDisplayState();
}

class _TopHeartDisplayState extends State<TopHeartDisplay> 
    with TickerProviderStateMixin {
  int _hearts = 0;
  bool _isLoading = false;
  String? _nextHeartTime;
  Timer? _updateTimer;
  Timer? _countdownTimer;
  
  // 倒數相關變數
  Duration? _remainingTime;
  
  // 動畫控制器
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _heartChangeController;
  late Animation<double> _heartChangeAnimation;

  @override
  void initState() {
    super.initState();
    
    // 初始化動畫
    _pulseController = AnimationController(
      duration: Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(
      begin: 0.9,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _heartChangeController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    
    _heartChangeAnimation = Tween<double>(
      begin: 1.0,
      end: 1.4,
    ).animate(CurvedAnimation(
      parent: _heartChangeController,
      curve: Curves.elasticOut,
    ));
    
    _loadHearts();
    _startUpdateTimer();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _countdownTimer?.cancel();
    _pulseController.dispose();
    _heartChangeController.dispose();
    super.dispose();
  }

  void _startUpdateTimer() {
    // 每30秒檢查一次心數更新
    _updateTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      _loadHearts();
    });
  }

  void _startCountdownTimer() {
    if (_remainingTime == null || _remainingTime!.inSeconds <= 0) return;
    
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_remainingTime != null && _remainingTime!.inSeconds > 0) {
        setState(() {
          _remainingTime = Duration(seconds: _remainingTime!.inSeconds - 1);
        });
      } else {
        timer.cancel();
        // 倒數結束，重新載入心數
        _loadHearts();
      }
    });
  }

  Future<void> _loadHearts() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      if (userId == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final response = await http.post(
        Uri.parse('https://superb-backend-1041765261654.asia-east1.run.app/check_heart'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          final newHearts = data['hearts'] as int;
          final nextHeartIn = data['next_heart_in'] as String?;
          
          // 如果心數增加了，播放動畫
          if (newHearts > _hearts && _hearts > 0) {
            _heartChangeController.forward().then((_) {
              _heartChangeController.reverse();
            });
          }
          
          setState(() {
            _hearts = newHearts;
            _nextHeartTime = nextHeartIn;
            _isLoading = false;
          });
          
          // 解析倒數時間
          if (nextHeartIn != null && nextHeartIn.isNotEmpty) {
            _parseAndStartCountdown(nextHeartIn);
          } else {
            _remainingTime = null;
            _countdownTimer?.cancel();
          }
        }
      }
    } catch (e) {
      print("載入心數失敗: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _parseAndStartCountdown(String timeString) {
    try {
      // 解析類似 "1:30:45.123456" 的時間格式
      final parts = timeString.split(':');
      if (parts.length >= 3) {
        final hours = int.tryParse(parts[0]) ?? 0;
        final minutes = int.tryParse(parts[1]) ?? 0;
        final seconds = int.tryParse(parts[2].split('.')[0]) ?? 0;
        
        _remainingTime = Duration(
          hours: hours,
          minutes: minutes,
          seconds: seconds,
        );
        
        _startCountdownTimer();
      }
    } catch (e) {
      print("解析倒數時間失敗: $e");
      _remainingTime = null;
    }
  }

  // 檢查是否有足夠的心數
  bool get hasEnoughHearts => _hearts > 0;
  
  // 獲取剩餘時間用於顯示
  Duration? get remainingTime => _remainingTime;

  void _handleTap() {
    if (widget.onTap != null) {
      widget.onTap!();
    }
    
    // 如果心數不足，觸發回調並傳遞剩餘時間
    if (!hasEnoughHearts && widget.onInsufficientHearts != null) {
      widget.onInsufficientHearts!(_remainingTime);
    } else {
      _loadHearts(); // 手動刷新
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              spreadRadius: 1,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: AnimatedBuilder(
          animation: _heartChangeAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _heartChangeAnimation.value,
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _hearts < 5 ? _pulseAnimation.value : 1.0,
                    child: _buildHeartsDisplay(),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeartsDisplay() {
    if (_isLoading) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
            ),
          ),
          SizedBox(width: 4),
          ...List.generate(4, (index) => Icon(
            Icons.favorite_border,
            color: Colors.grey.shade300,
            size: 16,
          )),
        ],
      );
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < _hearts) {
          return Icon(
            Icons.favorite,
            color: Colors.red,
            size: 18,
          );
        } else {
          return Icon(
            Icons.favorite_border,
            color: Colors.grey.shade300,
            size: 18,
          );
        }
      }),
    );
  }
} 