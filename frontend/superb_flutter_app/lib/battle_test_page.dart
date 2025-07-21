import 'package:flutter/material.dart';
import 'battle_prepare_page.dart';

class BattleTestPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('對戰系統測試'),
        backgroundColor: Color(0xFF319cb6),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '對戰系統測試',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0777B1),
              ),
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BattlePreparePage(
                      opponentId: 'test_opponent',
                      opponentName: '測試對手',
                      opponentPhotoUrl: null,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF319cb6),
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                '開始測試對戰',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: 16),
            Text(
              '測試功能包括：',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Column(
              children: [
                _buildFeatureItem('✅ 科目章節選擇'),
                _buildFeatureItem('✅ 隨機章節功能'),
                _buildFeatureItem('✅ 即時對戰界面'),
                _buildFeatureItem('✅ 計時答題系統'),
                _buildFeatureItem('✅ 分數統計顯示'),
                _buildFeatureItem('✅ 在線狀態指示'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Text(
        text,
        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
      ),
    );
  }
}
