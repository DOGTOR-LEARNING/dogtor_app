"""
愛心系統相關 API
"""
from fastapi import APIRouter, HTTPException
from datetime import datetime, timedelta, timezone
from models import HeartCheckRequest, HeartCheckResponse, ConsumeHeartRequest, ConsumeHeartResponse
from database import get_db_connection
import traceback


router = APIRouter(prefix="/hearts", tags=["Hearts"])

MAX_HEARTS = 5
RECOVER_DURATION = timedelta(hours=4)  # 4 小時恢復一顆


def calculate_current_hearts(last_updated, stored_hearts):
    """計算當前愛心數量"""
    print(f"計算當前心數: last_updated={last_updated}, stored_hearts={stored_hearts}")
    now = datetime.utcnow()
    
    # 獲取台灣時間（UTC+8）
    taiwan_timezone = timezone(timedelta(hours=8))
    now_tw = now.replace(tzinfo=timezone.utc).astimezone(taiwan_timezone)
    last_updated_tw = last_updated.replace(tzinfo=timezone.utc).astimezone(taiwan_timezone)
    
    # 檢查是否需要每日重置（台灣時間 12:00）
    today_noon = now_tw.replace(hour=12, minute=0, second=0, microsecond=0)
    yesterday_noon = today_noon - timedelta(days=1)
    
    # 如果上次更新在昨天中午之前，且現在過了今天中午，則重置為滿血
    if last_updated_tw < yesterday_noon and now_tw >= today_noon:
        return MAX_HEARTS, timedelta(0), 0
    
    # 如果今天已經過了中午，且上次更新在今天中午之前，則重置為滿血
    if now_tw >= today_noon and last_updated_tw < today_noon:
        return MAX_HEARTS, timedelta(0), 0
    
    # 正常的時間恢復邏輯
    elapsed = now - last_updated
    recovered = elapsed // RECOVER_DURATION
    new_hearts = min(MAX_HEARTS, stored_hearts + recovered)
    time_since_last = elapsed % RECOVER_DURATION
    return new_hearts, time_since_last, recovered


@router.post("/check_heart", response_model=HeartCheckResponse)
async def check_heart(request: HeartCheckRequest):
    """檢查用戶愛心狀態"""
    try:
        connection = get_db_connection()
        with connection.cursor() as cursor:
            # 檢查用戶愛心記錄
            cursor.execute(
                "SELECT hearts, last_heart_update FROM user_hearts WHERE user_id = %s", 
                (request.user_id,)
            )
            result = cursor.fetchone()
            
            if not result:
                # 新用戶，創建愛心記錄
                now = datetime.utcnow()
                cursor.execute(
                    "INSERT INTO user_heart (user_id, hearts, last_heart_update) VALUES (%s, %s, %s)",
                    (request.user_id, MAX_HEARTS, now)
                )
                connection.commit()
                return HeartCheckResponse(
                    success=True,
                    hearts=MAX_HEARTS,
                    next_heart_in=None
                )
            
            # 計算當前愛心數量
            stored_hearts = result['hearts']
            last_updated = result['last_heart_update']
            current_hearts, time_since_last, recovered = calculate_current_hearts(last_updated, stored_hearts)
            
            # 如果愛心有恢復，更新資料庫
            if recovered > 0:
                new_update_time = datetime.utcnow() - time_since_last
                cursor.execute(
                    "UPDATE user_heart SET hearts = %s, last_heart_update = %s WHERE user_id = %s",
                    (current_hearts, new_update_time, request.user_id)
                )
                connection.commit()
            
            # 計算下次愛心恢復時間
            next_heart_in = None
            if current_hearts < MAX_HEARTS:
                remaining_time = RECOVER_DURATION - time_since_last
                next_heart_in = str(remaining_time)
            
            return HeartCheckResponse(
                success=True,
                hearts=current_hearts,
                next_heart_in=next_heart_in
            )
            
    except Exception as e:
        print(f"檢查愛心失敗: {e}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"檢查愛心失敗: {str(e)}")
    finally:
        if 'connection' in locals():
            connection.close()


@router.post("/consume_heart", response_model=ConsumeHeartResponse)
async def consume_heart(request: ConsumeHeartRequest):
    """消耗愛心"""
    try:
        connection = get_db_connection()
        with connection.cursor() as cursor:
            # 先檢查當前愛心狀態
            check_result = await check_heart(HeartCheckRequest(user_id=request.user_id))
            
            if not check_result.success or check_result.hearts <= 0:
                raise HTTPException(status_code=400, detail="愛心不足")
            
            # 扣除一顆愛心
            new_hearts = check_result.hearts - 1
            now = datetime.utcnow()
            
            cursor.execute(
                "UPDATE user_heart SET hearts = %s, last_heart_update = %s WHERE user_id = %s",
                (new_hearts, now, request.user_id)
            )
            connection.commit()
            
            return ConsumeHeartResponse(
                success=True,
                hearts=new_hearts
            )
            
    except HTTPException:
        raise
    except Exception as e:
        print(f"消耗愛心失敗: {e}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"消耗愛心失敗: {str(e)}")
    finally:
        if 'connection' in locals():
            connection.close()
