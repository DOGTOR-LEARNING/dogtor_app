"""
重構後的主應用程式入口
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from dotenv import load_dotenv
from datetime import datetime
from database import get_db_connection
import os
import uvicorn

# 載入環境變數
load_dotenv()

# 導入路由模組
from routers import hearts, mistake_book, users, ai, quiz, friends, stats, notifications, admin, online_status, battle

# 創建 FastAPI 應用
app = FastAPI(
    title="Superb Learning Platform API",
    description="學習平台後端 API",
    version="2.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# 添加 CORS 中間件
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 建議在生產環境中指定具體來源
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 註冊路由
app.include_router(hearts.router)
app.include_router(mistake_book.router)
app.include_router(users.router)
app.include_router(ai.router)
app.include_router(quiz.router)
app.include_router(friends.router)
app.include_router(stats.router)
app.include_router(notifications.router)
app.include_router(admin.router)
app.include_router(online_status.router)  # 新增：在線狀態路由
app.include_router(battle.router)  # 新增：對戰模式路由

# Cron 任務端點（供 Google Cloud Scheduler 調用）
@app.post("/cron_push_heart_reminder")
async def cron_push_heart_reminder():
    """定時發送愛心恢復提醒（Cron 任務 - 根路徑）"""
    # 直接調用 notifications 路由中的功能
    from routers.notifications import cron_push_heart_reminder as notifications_cron
    return await notifications_cron()

@app.post("/cron_push_learning_reminder")
async def cron_push_learning_reminder():
    """定時發送學習提醒（Cron 任務 - 根路徑）"""
    # 直接調用 notifications 路由中的功能
    from routers.notifications import cron_push_learning_reminder as notifications_learning_cron
    return await notifications_learning_cron()

# 健康檢查端點
@app.get("/", tags=["Health"])
async def root():
    """健康檢查"""
    return {
        "message": "Superb Learning Platform API",
        "version": "2.0.0",
        "status": "healthy"
    }


@app.get("/health", tags=["Health"])
async def health_check():
    """詳細健康檢查"""
    try:
        # 測試資料庫連線
        connection = get_db_connection()
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
            result = cursor.fetchone()
        connection.close()
        db_status = "connected"
    except Exception as e:
        db_status = f"error: {str(e)}"
    
    return {
        "status": "healthy",
        "database": db_status,
        "ai_service": "available",
        "timestamp": datetime.now().isoformat()
    }


# 應用啟動事件
@app.on_event("startup")
async def startup_event():
    """應用啟動時的初始化"""
    print("🚀 Superb Learning Platform API 正在啟動...")
    print("✅ 應用啟動完成")


if __name__ == "__main__":
    # 從環境變數獲取端口，如果沒有則默認使用 8080
    port = int(os.getenv("PORT", 8080))
    
    # 啟動服務器，監聽所有網絡接口
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=port,
        reload=False  # 在生產環境中禁用重載
    )
