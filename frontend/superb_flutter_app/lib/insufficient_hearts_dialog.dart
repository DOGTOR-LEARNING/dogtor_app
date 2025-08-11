import 'package:flutter/material.dart';
import 'dart:async';

class InsufficientHeartsDialog {
  static void show(BuildContext context, Duration? remainingTime) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _InsufficientHeartsDialogWidget(
        remainingTime: remainingTime,
      ),
    );
  }
}

class _InsufficientHeartsDialogWidget extends StatefulWidget {
  final Duration? remainingTime;

  const _InsufficientHeartsDialogWidget({
    Key? key,
    this.remainingTime,
  }) : super(key: key);

  @override
  _InsufficientHeartsDialogWidgetState createState() =>
      _InsufficientHeartsDialogWidgetState();
}

class _InsufficientHeartsDialogWidgetState
    extends State<_InsufficientHeartsDialogWidget>
    with SingleTickerProviderStateMixin {
  Duration? _remainingTime;
  Timer? _countdownTimer;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _remainingTime = widget.remainingTime;

    // 初始化動畫
    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // 啟動動畫
    _animationController.forward();

    // 開始倒數計時
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    if (_remainingTime == null || _remainingTime!.inSeconds <= 0) return;

    _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_remainingTime != null && _remainingTime!.inSeconds > 0) {
        setState(() {
          _remainingTime = Duration(seconds: _remainingTime!.inSeconds - 1);
        });
      } else {
        timer.cancel();
        // 倒數結束，自動關閉對話框
        Navigator.of(context).pop();
      }
    });
  }

  String _formatTime() {
    if (_remainingTime == null) return '計算中...';

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
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF1E5B8C), // 深藍色
                      Color(0xFF2A7AB8), // 較淺的藍色
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 15,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 愛心圖示和標題
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.favorite_border,
                            color: Colors.red.shade300,
                            size: 32,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          '生命不足',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 20),

                    // 當前生命顯示
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '當前生命：',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                            ),
                          ),
                          SizedBox(width: 8),
                          Row(
                            children: List.generate(
                              5,
                              (index) => Icon(
                                Icons.favorite_border,
                                color: Colors.red.shade300,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 16),

                    // 提示文字
                    Text(
                      '你需要生命來進行關卡挑戰\n生命每4小時恢復1顆\n每日12點會重置為滿血',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                        height: 1.4,
                      ),
                    ),

                    SizedBox(height: 20),

                    // 倒數計時
                    if (_remainingTime != null)
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Color(0xFFf59b03).withOpacity(0.9), // 橙色背景
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFFf59b03).withOpacity(0.3),
                              spreadRadius: 1,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.access_time,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  '下顆生命恢復時間',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              _formatTime(),
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),

                    SizedBox(height: 24),

                    // 關閉按鈕
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Color(0xFF1E5B8C),
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          '我知道了',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
