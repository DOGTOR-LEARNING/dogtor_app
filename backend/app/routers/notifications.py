"""
推播通知相關 API
"""
from fastapi import APIRouter, HTTPException, Body
from database import get_db_connection
from models import PushNotificationRequest, LearningReminderRequest, RegisterTokenRequest, StandardResponse
from typing import Dict, Any
import traceback
import firebase_admin
from firebase_admin import credentials, messaging
from datetime import datetime

router = APIRouter(prefix="/notifications", tags=["Notifications"])

# 初始化 Firebase Admin（使用同專案的預設憑證）
try:
    firebase_admin.get_app()
    print("✅ Firebase Admin 已經初始化過了")
except ValueError:
    # Firebase Admin 尚未初始化，使用 ApplicationDefault 憑證
    cred = credentials.ApplicationDefault()
    firebase_admin.initialize_app(cred)
    print("✅ Firebase Admin 初始化成功 (使用預設憑證)")


def send_push_notification(token: str, title: str, body: str) -> str:
    """發送推播通知"""
    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            token=token,
        )
        response = messaging.send(message)
        print(f"✅ 已送出推播：{token[:10]}... → {response}")
        return response
    except Exception as e:
        print(f"❌ 發送失敗：{e}")
        return "error"


@router.post("/register_token", response_model=StandardResponse)
async def register_token(request: RegisterTokenRequest):
    print("🔗 註冊推播 token")
    connection = get_db_connection()
    try:
        user_id = request.user_id
        firebase_token = request.firebase_token
        old_token = request.old_token
        device_info = request.device_info

        if not user_id or not firebase_token:
            return StandardResponse(success=False, message="缺少必要參數")

        with connection.cursor() as cursor:
            # 如果有傳 old_token，先試著用 old_token 來更新資料
            if old_token:
                update_sql = """
                    UPDATE user_tokens
                    SET firebase_token = %s, user_id = %s, device_info = %s, last_updated = %s
                    WHERE firebase_token = %s
                """
                affected = cursor.execute(update_sql, (
                    firebase_token, user_id, device_info, datetime.utcnow(), old_token
                ))
                if affected:
                    connection.commit()
                    print(f"🔁 已更新舊 token 為新 token：{firebase_token[:10]}...")
                    return StandardResponse(success=True, message="更新成功")
                else:
                    print("⚠️ 找不到舊 token，改為新增 token")

            # 如果沒舊 token 或找不到，就嘗試插入新 token
            insert_sql = """
                INSERT INTO user_tokens (user_id, firebase_token, device_info, last_updated)
                VALUES (%s, %s, %s, %s)
                ON DUPLICATE KEY UPDATE
                    user_id = VALUES(user_id),
                    device_info = VALUES(device_info),
                    last_updated = VALUES(last_updated)
            """
            cursor.execute(insert_sql, (user_id, firebase_token, device_info, datetime.utcnow()))
            connection.commit()
            print(f"✅ Token 註冊成功: {firebase_token[:10]}...")
            return {"success": True, "message": "Token 註冊成功"}
    except Exception as e:
        print(f"❌ Token 註冊時出錯: {str(e)}")
        return {"success": False, "message": f"Token 註冊時出錯: {str(e)}"}
    finally:
        connection.close()


@router.post("/send_test_push", response_model=StandardResponse)
async def send_test_push(request: dict = Body(...)):
    """發送測試推播"""
    try:
        user_id = request.get('user_id')
        title = request.get('title', '測試推播')
        body = request.get('body', '這是一個測試推播')
        
        connection = get_db_connection()
        with connection.cursor() as cursor:
            # 獲取用戶的活躍 token
            sql = "SELECT firebase_token FROM user_tokens WHERE user_id = %s"
            cursor.execute(sql, (user_id,))
            tokens = cursor.fetchall()
            
            if not tokens:
                return StandardResponse(success=False, message="找不到用戶的推播 token")
            
            success_count = 0
            for token_record in tokens:
                token = token_record['firebase_token']
                result = send_push_notification(token, title, body)
                if result != "error":
                    success_count += 1
            
            return StandardResponse(
                success=success_count > 0,
                message=f"成功發送 {success_count}/{len(tokens)} 個推播"
            )
    
    except Exception as e:
        print(f"[send_test_push] Error: {e}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    finally:
        if 'connection' in locals():
            connection.close()


@router.post("/send_learning_reminder", response_model=StandardResponse)
async def send_learning_reminder(request: LearningReminderRequest):
    """發送學習提醒"""
    try:
        connection = get_db_connection()
        with connection.cursor() as cursor:
            # 獲取用戶的活躍 token
            sql = "SELECT token FROM user_tokens WHERE user_id = %s"
            cursor.execute(sql, (request.user_id,))
            tokens = cursor.fetchall()
            
            if not tokens:
                return StandardResponse(success=False, message="找不到用戶的推播 token")
            
            # 自定義推播內容
            title = "🎓 學習提醒"
            body = f"該複習 {request.subject} - {request.chapter} 了！保持學習動力 💪"
            
            if request.difficulty_level == "高":
                body += " 這個章節比較有挑戰性，加油！"
            
            success_count = 0
            for token_record in tokens:
                token = token_record['token']
                result = send_push_notification(token, title, body)
                if result != "error":
                    success_count += 1
            
            # 記錄提醒歷史
            sql = """
            INSERT INTO reminder_history (user_id, subject, chapter, difficulty_level, sent_at, success_count)
            VALUES (%s, %s, %s, %s, NOW(), %s)
            """
            cursor.execute(sql, (request.user_id, request.subject, request.chapter, 
                                request.difficulty_level, success_count))
            connection.commit()
            
            return StandardResponse(
                success=success_count > 0,
                message=f"學習提醒已發送給 {success_count} 個設備"
            )
    
    except Exception as e:
        print(f"[send_learning_reminder] Error: {e}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    finally:
        if 'connection' in locals():
            connection.close()

@router.post("/cron_push_heart_reminder", response_model=StandardResponse)
async def cron_push_heart_reminder():
    """定時發送愛心恢復提醒（Cron 任務）"""
    try:
        connection = get_db_connection()
        with connection.cursor() as cursor:
            # 查找愛心不滿且有 token 的用戶
            sql = """
            SELECT ut.firebase_token
                FROM user_tokens ut
                JOIN user_heart uh ON ut.user_id = uh.user_id
                WHERE uh.hearts = 5
            """
            cursor.execute(sql)
            full_heart_tokens = [row["firebase_token"] for row in cursor.fetchall()]
            
            total_sent = 0

            for token in full_heart_tokens:

                title = "體力已回滿！"
                body = "快來 Dogtor 答題吧 ⚔️"
                
                result = send_push_notification(token, title, body)
                '''
                if result != "error":
                    total_sent += 1
                    
                    # 記錄提醒歷史
                    sql = """
                    INSERT INTO reminder_history (user_id, subject, chapter, difficulty_level, sent_at, success_count)
                    VALUES (%s, 'heart_reminder', '', '', NOW(), 1)
                    """
                    cursor.execute(sql, (user_id,))
                '''
            
            connection.commit()
            return StandardResponse(
                success=True,
                message=f"體力回復提醒已發送給 {total_sent} 位用戶"
            )
    
    except Exception as e:
        print(f"[cron_push_heart_reminder] Error: {e}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    finally:
        if 'connection' in locals():
            connection.close()

@router.post("/validate_tokens", response_model=Dict[str, Any])
async def validate_tokens():
    """驗證並清理無效的推播 token"""
    try:
        connection = get_db_connection()
        with connection.cursor() as cursor:
            # 獲取所有活躍 token
            sql = "SELECT id, token FROM user_tokens WHERE is_active = 1"
            cursor.execute(sql)
            tokens = cursor.fetchall()
            
            invalid_count = 0
            for token_record in tokens:
                token_id = token_record['id']
                token = token_record['token']
                
                try:
                    # 嘗試發送測試消息來驗證 token
                    message = messaging.Message(
                        data={"test": "true"},
                        token=token,
                    )
                    messaging.send(message, dry_run=True)  # 只驗證不實際發送
                except Exception as e:
                    # Token 無效，標記為不活躍
                    if "not-registered" in str(e) or "invalid-registration-token" in str(e):
                        sql = "UPDATE user_tokens SET is_active = 0 WHERE id = %s"
                        cursor.execute(sql, (token_id,))
                        invalid_count += 1
            
            connection.commit()
            return {
                "total_tokens": len(tokens),
                "invalid_tokens": invalid_count,
                "valid_tokens": len(tokens) - invalid_count
            }
    
    except Exception as e:
        print(f"[validate_tokens] Error: {e}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    finally:
        if 'connection' in locals():
            connection.close()


@router.post("/debug_push_notification", response_model=Dict[str, Any])
async def debug_push_notification(request: dict = Body(...)):
    """調試推播通知"""
    try:
        token = request.get('token')
        title = request.get('title', '測試通知')
        body = request.get('body', '這是一個調試通知')
        
        if not token:
            raise HTTPException(status_code=400, detail="Token is required")
        
        result = send_push_notification(token, title, body)
        
        return {
            "success": result != "error",
            "result": result,
            "message": "推播發送成功" if result != "error" else "推播發送失敗"
        }
    
    except Exception as e:
        print(f"[debug_push_notification] Error: {e}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Error: {str(e)}")


# 修改處理每日使用量通知的 API
@app.get("/notify-daily-report")
async def notify_daily_report():
    try:
        print("開始執行每日報告功能...")
        import smtplib
        from email.mime.text import MIMEText
        from datetime import datetime, timedelta, timezone
        
        # 獲取環境變數
        GMAIL_ADDRESS = os.getenv("GMAIL_ADDRESS")
        APP_PASSWORD = os.getenv("APP_PASSWORD")
        RECEIVERS = os.getenv("RECEIVERS", "").split(",") if os.getenv("RECEIVERS") else []
        
        print(f"環境變數檢查: GMAIL_ADDRESS={'已設置' if GMAIL_ADDRESS else '未設置'}")
        print(f"環境變數檢查: APP_PASSWORD={'已設置' if APP_PASSWORD else '未設置'}")
        print(f"環境變數檢查: RECEIVERS={RECEIVERS}")
        
        # 發送郵件
        def send_email(subject, body):
            print(f"準備發送郵件: 主題={subject}, 收件人={RECEIVERS}")
            if not GMAIL_ADDRESS or not APP_PASSWORD or not RECEIVERS:
                print("警告: 郵件發送信息不完整，無法發送郵件")
                return False
                
            try:
                msg = MIMEText(body, "plain", "utf-8")
                msg["Subject"] = subject
                msg["From"] = GMAIL_ADDRESS
                msg["To"] = ", ".join(RECEIVERS)
                
                print("連接到 SMTP 服務器...")
                with smtplib.SMTP_SSL("smtp.gmail.com", 465) as server:
                    print("登錄 SMTP 服務器...")
                    server.login(GMAIL_ADDRESS, APP_PASSWORD)
                    print("發送郵件...")
                    server.sendmail(GMAIL_ADDRESS, RECEIVERS, msg.as_string())
                    print("郵件發送成功")
                return True
            except Exception as e:
                print(f"發送郵件時出錯: {e}")
                import traceback
                print(traceback.format_exc())
                return False
        
        # 獲取當日關卡數據
        print("開始獲取當日關卡數據...")
        
        # 設置時區為台北時間
        taipei_tz = timezone(timedelta(hours=8))
        now = datetime.now(taipei_tz)
        
        # 計算昨天的日期（台北時間）
        today = now.date()
        yesterday = today - timedelta(days=1)
        yesterday_start = datetime.combine(yesterday, datetime.min.time(), tzinfo=taipei_tz)
        yesterday_end = datetime.combine(yesterday, datetime.max.time(), tzinfo=taipei_tz)
        
        yesterday_start_str = yesterday_start.strftime('%Y-%m-%d %H:%M:%S')
        yesterday_end_str = yesterday_end.strftime('%Y-%m-%d %H:%M:%S')
        
        print(f"當前時間（台北）: {now.strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"查詢日期範圍: {yesterday_start_str} 至 {yesterday_end_str}")
        
        # 連接到資料庫
        connection = get_db_connection()
        connection.charset = 'utf8mb4'
        
        try:
            with connection.cursor() as cursor:
                # 設置連接的字符集
                cursor.execute("SET NAMES utf8mb4")
                cursor.execute("SET CHARACTER SET utf8mb4")
                cursor.execute("SET character_set_connection=utf8mb4")
                
                # 獲取昨天完成的關卡數量
                cursor.execute("""
                SELECT COUNT(*) as total_levels, COUNT(DISTINCT user_id) as total_users
                FROM user_level
                WHERE answered_at BETWEEN %s AND %s
                """, (yesterday_start_str, yesterday_end_str))
                
                level_stats = cursor.fetchone()
                total_levels = level_stats['total_levels'] if level_stats else 0
                total_users = level_stats['total_users'] if level_stats else 0
                
                # 獲取昨天的答題數量
                cursor.execute("""
                SELECT COUNT(*) as total_answers, COUNT(DISTINCT user_id) as answer_users
                FROM user_question_stats
                WHERE last_attempted_at BETWEEN %s AND %s
                """, (yesterday_start_str, yesterday_end_str))
                
                # 獲取昨天活躍的前5名用戶
                cursor.execute("""
                SELECT user_id, COUNT(*) as level_count
                FROM user_level
                WHERE answered_at BETWEEN %s AND %s
                GROUP BY user_id
                ORDER BY level_count DESC
                LIMIT 5
                """, (yesterday_start_str, yesterday_end_str))
                
                top_users = cursor.fetchall()
                
                # 獲取用戶名稱
                top_user_details = []
                for user in top_users:
                    cursor.execute("SELECT name FROM users WHERE user_id = %s", (user['user_id'],))
                    user_info = cursor.fetchone()
                    user_name = user_info['name'] if user_info and user_info['name'] else user['user_id']
                    top_user_details.append({
                        "name": user_name,
                        "level_count": user['level_count']
                    })
        
        finally:
            connection.close()
        
        # 構建郵件內容
        today_str = today.strftime("%Y-%m-%d")
        yesterday_str = yesterday.strftime("%Y-%m-%d")
        subject = f"【Dogtor 每日系統報告】{today_str}"
        
        print("構建郵件內容...")
        body = f"""Dogtor 每日使用報告 ({yesterday_str})：

【使用統計】
昨日完成關卡數：{total_levels} 個
昨日活躍用戶數：{total_users} 人
"""

        if top_user_details:
            body += "\n【昨日最活躍用戶】\n"
            for i, user in enumerate(top_user_details, 1):
                body += f"{i}. {user['name']} - 完成 {user['level_count']} 個關卡\n"
        
        body += """
祝您有美好的一天！

（本報告由系統自動生成，請勿直接回覆）
"""
        
        print("郵件內容構建完成，開始發送...")
        email_sent = send_email(subject, body)
        
        if email_sent:
            return {"status": "success", "message": "每日報告已發送"}
        else:
            return {"status": "warning", "message": "每日報告生成成功，但郵件發送失敗"}
            
    except Exception as e:
        print(f"發送每日報告時出錯: {e}")
        import traceback
        print(traceback.format_exc())
        return {"status": "error", "message": f"發送每日報告時出錯: {str(e)}"}

@router.post("/cron_push_learning_reminder", response_model=StandardResponse)
async def cron_push_learning_reminder():
    """定時發送學習提醒（Cron 任務）"""
    try:
        connection = get_db_connection()
        with connection.cursor() as cursor:
            # 查找超過 24 小時沒有學習的用戶
            sql = """
                SELECT ut.user_id, ut.firebase_token, u.name
                FROM user_tokens ut
                INNER JOIN users u ON ut.user_id = u.user_id
                LEFT JOIN (
                    SELECT user_id, MAX(answered_at) as last_answered
                    FROM user_level
                    WHERE answered_at >= NOW() - INTERVAL 24 HOUR
                    GROUP BY user_id
                ) recent_activity ON ut.user_id = recent_activity.user_id
                WHERE recent_activity.user_id IS NULL
                  AND ut.firebase_token IS NOT NULL
            """
            cursor.execute(sql)
            inactive_users = cursor.fetchall()
            
            total_sent = 0
            for record in inactive_users:
                user_id = record['user_id']
                token = record['token']
                name = record['name'] or "同學"

                # 檢查 12 小時內是否已發送過學習提醒，避免重複推播
                cursor.execute("""
                    SELECT COUNT(*) as cnt
                    FROM reminder_history
                    WHERE user_id = %s
                      AND message = %s
                      AND sent_at >= NOW() - INTERVAL 12 HOUR
                """, (user_id, "daily_learning_reminder"))
                
                if cursor.fetchone()['cnt'] > 0:
                    continue  # 跳過已發送過的用戶
                
                title = "📚 該學習囉！"
                body = f"{name}，今天還沒有學習呢！保持每日學習習慣很重要哦～"
                
                result = send_push_notification(token, title, body)
                '''
                if result != "error":
                    total_sent += 1
                    
                    # 記錄提醒歷史
                    sql = """
                    INSERT INTO reminder_history (user_id, subject, chapter, difficulty_level, sent_at, success_count)
                    VALUES (%s, 'daily_reminder', '', '', NOW(), 1)
                    """
                    cursor.execute(sql, (user_id,))
                '''
            connection.commit()
            return StandardResponse(
                success=True,
                message=f"學習提醒已發送給 {total_sent} 位用戶"
            )
    
    except Exception as e:
        print(f"[cron_push_learning_reminder] Error: {e}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    finally:
        if 'connection' in locals():
            connection.close()