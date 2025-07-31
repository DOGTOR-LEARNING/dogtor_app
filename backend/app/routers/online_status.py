"""
在線狀態管理路由
"""
from fastapi import APIRouter, HTTPException
from models import (
    UserOnlineStatusRequest, 
    UpdateOnlineStatusRequest,
    StandardResponse
)
# from database import get_db_connection
from datetime import datetime, timedelta
import pymysql
import os
from typing import Dict, List

router = APIRouter(prefix="/online", tags=["在線狀態"])

# 內存中存儲在線狀態（生產環境建議使用 Redis）
online_users: Dict[str, datetime] = {}

# 這個是本地開發環境的連接方式
def get_db_connection():
    """獲取資料庫連接"""
    return pymysql.connect(
        host=os.getenv('DB_HOST', '127.0.0.1'),
        port=int(os.getenv('DB_PORT', '5433')),
        database=os.getenv('DB_NAME', 'dogtor'),
        user=os.getenv('DB_USER', 'dogtor-dev'),
        password=os.getenv('DB_PASSWORD', 'Superb222'),
        charset='utf8mb4'
    )

@router.post("/update_status", response_model=StandardResponse)
async def update_online_status(request: UpdateOnlineStatusRequest):
    """更新用戶在線狀態"""
    try:
        # 更新資料庫中的 last_online 時間
        conn = get_db_connection()
        cursor = conn.cursor()
        
        if request.is_online:
            # 用戶上線，記錄時間戳和更新資料庫
            online_users[request.user_id] = datetime.now()
            
            cursor.execute("""
                UPDATE users SET last_online = NOW() WHERE user_id = %s
            """, (request.user_id,))
            
            # 也更新 user_online_status 表
            cursor.execute("""
                INSERT INTO user_online_status (user_id, is_online, last_heartbeat) 
                VALUES (%s, TRUE, NOW())
                ON DUPLICATE KEY UPDATE 
                is_online = TRUE, last_heartbeat = NOW()
            """, (request.user_id,))
        else:
            # 用戶下線，移除記錄
            online_users.pop(request.user_id, None)
            
            cursor.execute("""
                INSERT INTO user_online_status (user_id, is_online, last_heartbeat) 
                VALUES (%s, FALSE, NOW())
                ON DUPLICATE KEY UPDATE 
                is_online = FALSE, last_heartbeat = NOW()
            """, (request.user_id,))
        
        conn.commit()
        cursor.close()
        conn.close()
        
        return StandardResponse(
            success=True,
            message="在線狀態更新成功",
            data={"user_id": request.user_id, "is_online": request.is_online}
        )
    except Exception as e:
        print(f"更新在線狀態錯誤: {e}")
        raise HTTPException(status_code=500, detail="更新在線狀態失敗")

@router.get("/status/{user_id}")
async def get_user_online_status(user_id: str):
    """獲取單個用戶的在線狀態"""
    try:
        # 檢查用戶是否在線（5分鐘內活躍）
        if user_id in online_users:
            last_active = online_users[user_id]
            if datetime.now() - last_active < timedelta(minutes=5):
                return {"is_online": True, "last_active": last_active.isoformat()}
            else:
                # 超過5分鐘，視為離線
                online_users.pop(user_id, None)
        
        return {"is_online": False, "last_active": None}
    except Exception as e:
        print(f"獲取在線狀態錯誤: {e}")
        raise HTTPException(status_code=500, detail="獲取在線狀態失敗")

@router.post("/batch_status")
async def get_batch_online_status(user_ids: List[str]):
    """批量獲取多個用戶的在線狀態"""
    try:
        result = {}
        current_time = datetime.now()
        
        for user_id in user_ids:
            if user_id in online_users:
                last_active = online_users[user_id]
                if current_time - last_active < timedelta(minutes=5):
                    result[user_id] = {"is_online": True, "last_active": last_active.isoformat()}
                else:
                    # 超過5分鐘，視為離線
                    online_users.pop(user_id, None)
                    result[user_id] = {"is_online": False, "last_active": None}
            else:
                result[user_id] = {"is_online": False, "last_active": None}
        
        return {"success": True, "users_status": result}
    except Exception as e:
        print(f"批量獲取在線狀態錯誤: {e}")
        raise HTTPException(status_code=500, detail="批量獲取在線狀態失敗")

@router.get("/heartbeat/{user_id}")
async def heartbeat(user_id: str):
    """心跳接口，用於保持在線狀態"""
    try:
        online_users[user_id] = datetime.now()
        return {"success": True, "message": "心跳更新成功"}
    except Exception as e:
        print(f"心跳更新錯誤: {e}")
        raise HTTPException(status_code=500, detail="心跳更新失敗")
