#!/usr/bin/env python3
"""
測試重構後的 API 結構
"""
import os
import sys

# 添加項目根目錄到 Python 路徑
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

try:
    print("🧪 測試重構後的 API 結構...")
    
    # 測試導入路由器
    print("✅ 測試導入路由器...")
    from app.routers import hearts, mistake_book, users, ai, quiz, friends, stats, notifications, admin
    print("  - hearts.py ✅")
    print("  - mistake_book.py ✅")
    print("  - users.py ✅")
    print("  - ai.py ✅")
    print("  - quiz.py ✅")
    print("  - friends.py ✅")
    print("  - stats.py ✅")
    print("  - notifications.py ✅")
    print("  - admin.py ✅")
    
    # 測試導入模型
    print("\n✅ 測試導入資料模型...")
    from app.models import (
        ChatRequest, HeartCheckRequest, MistakeBookRequest,
        QuestionRequest, FriendRequest, UserStatsRequest,
        PushNotificationRequest, StandardResponse
    )
    print("  - 資料模型導入成功 ✅")
    
    # 測試導入資料庫連接
    print("\n✅ 測試資料庫模組...")
    from app.database import get_db_connection
    print("  - 資料庫連接模組導入成功 ✅")
    
    # 測試主應用
    print("\n✅ 測試主應用...")
    from backend.app.main import app
    print("  - FastAPI 應用創建成功 ✅")
    
    # 檢查路由註冊
    routes = [route.path for route in app.routes]
    expected_prefixes = ["/hearts", "/mistake-book", "/users", "/ai", "/quiz", "/friends", "/stats", "/notifications", "/admin"]
    
    print("\n✅ 檢查路由註冊...")
    for prefix in expected_prefixes:
        found = any(route.startswith(prefix) for route in routes if hasattr(route, 'startswith'))
        if found:
            print(f"  - {prefix} 路由已註冊 ✅")
        else:
            print(f"  - {prefix} 路由未找到 ❌")
    
    print("\n🎉 重構測試完成！所有模組都能正確導入。")
    print("📝 API 文檔可在 http://localhost:8080/docs 查看")
    
except ImportError as e:
    print(f"❌ 導入錯誤: {e}")
    sys.exit(1)
except Exception as e:
    print(f"❌ 測試失敗: {e}")
    sys.exit(1)

print("\n📊 API 分類總結:")
print("  🤖 AI 相關: /ai/*")
print("  📚 錯題本: /mistake-book/*") 
print("  👤 用戶管理: /users/*")
print("  💖 愛心系統: /hearts/*")
print("  📝 題目測驗: /quiz/*")
print("  👥 好友系統: /friends/*")
print("  📈 統計分析: /stats/*")
print("  🔔 推播通知: /notifications/*")
print("  🔧 管理員: /admin/*")
print("\n🚀 啟動指令: python -m uvicorn app.main_new:app --reload")
