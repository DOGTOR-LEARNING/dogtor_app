import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class HeartDisplayWidget extends StatefulWidget {
  final VoidCallback? onTap;
  final double size;
  final bool showCountdown;

  const HeartDisplayWidget({
    super.key,
    this.onTap,
    this.size = 40.0,
    this.showCountdown = true,
  });

  @override
  _HeartDisplayWidgetState createState() => _HeartDisplayWidgetState();
}

class _HeartDisplayWidgetState extends State<HeartDisplayWidget>
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
      duration: Duration(milliseconds: 1500),
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
      duration: Duration(milliseconds: 500),
      vsync: this,
    );

    _heartChangeAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
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
        Uri.parse(
            'https://superb-backend-1041765261654.asia-east1.run.app/hearts/check_heart'),
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

  String _formatCountdown() {
    if (_remainingTime == null) return '';

    final hours = _remainingTime!.inHours;
    final minutes = _remainingTime!.inMinutes % 60;
    final seconds = _remainingTime!.inSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (widget.onTap != null) {
          widget.onTap!();
        }
        _loadHearts(); // 手動刷新
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.red.shade100,
              Colors.red.shade50,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 心數顯示
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isLoading)
                  SizedBox(
                    width: widget.size * 0.6,
                    height: widget.size * 0.6,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                    ),
                  )
                else
                  AnimatedBuilder(
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
                SizedBox(width: 8),
                Text(
                  '$_hearts',
                  style: TextStyle(
                    fontSize: widget.size * 0.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),

            // 倒數計時顯示
            if (widget.showCountdown && _remainingTime != null && _hearts < 5)
              Padding(
                padding: EdgeInsets.only(top: 4),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: Colors.blue.shade700,
                      ),
                      SizedBox(width: 4),
                      Text(
                        _formatCountdown(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeartsDisplay() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < _hearts) {
          return Icon(
            Icons.favorite,
            color: Colors.red,
            size: widget.size * 0.6,
          );
        } else {
          return Icon(
            Icons.favorite_border,
            color: Colors.grey.shade400,
            size: widget.size * 0.6,
          );
        }
      }),
    );
  }
}
