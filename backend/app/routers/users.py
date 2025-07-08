"""
用戶相關 API
"""
from fastapi import APIRouter, HTTPException
from typing import Optional
from models import User, RegisterTokenRequest, StandardResponse
from database import get_db_connection
import traceback


router = APIRouter(prefix="/users", tags=["Users"])


async def initialize_user_knowledge_scores(user_id: str, connection):
    """初始化用戶知識點分數"""
    try:
        print(f"===== 開始初始化用戶 {user_id} 的知識點分數 =====")
        
        with connection.cursor() as cursor:
            # 檢查用戶是否存在
            cursor.execute("SELECT * FROM users WHERE user_id = %s", (user_id,))
            user_result = cursor.fetchone()
            if not user_result:
                print(f"錯誤: 找不到用戶 ID: {user_id}")
                return
            
            # 獲取所有知識點
            cursor.execute("SELECT COUNT(*) as count FROM knowledge_points")
            count_result = cursor.fetchone()
            total_knowledge_points = count_result['count']
            print(f"數據庫中共有 {total_knowledge_points} 個知識點")
            
            if total_knowledge_points == 0:
                print("警告: 知識點表為空，無法初始化用戶知識點分數")
                return
            
            sql = "SELECT id FROM knowledge_points"
            cursor.execute(sql)
            all_knowledge_points = cursor.fetchall()
            
            # 獲取用戶已有的知識點分數
            sql = "SELECT knowledge_id FROM user_knowledge_score WHERE user_id = %s"
            cursor.execute(sql, (user_id,))
            existing_scores = cursor.fetchall()
            existing_knowledge_ids = [score['knowledge_id'] for score in existing_scores]
            
            # 為缺少的知識點創建分數記錄
            inserted_count = 0
            error_count = 0
            for point in all_knowledge_points:
                knowledge_id = point['id']
                if knowledge_id not in existing_knowledge_ids:
                    try:
                        sql = """
                        INSERT INTO user_knowledge_score (user_id, knowledge_id, score)
                        VALUES (%s, %s, 0)
                        ON DUPLICATE KEY UPDATE score = VALUES(score)
                        """
                        cursor.execute(sql, (user_id, knowledge_id))
                        inserted_count += 1
                        
                        # 每插入10條記錄輸出一次進度
                        if inserted_count % 10 == 0:
                            print(f"已插入 {inserted_count} 條記錄...")
                    except Exception as insert_error:
                        error_count += 1
                        if error_count <= 5:  # 只顯示前5個錯誤
                            print(f"插入知識點 {knowledge_id} 時出錯: {str(insert_error)}")
                        elif error_count == 6:
                            print("更多錯誤被省略...")
            
            print(f"為用戶 {user_id} 新增了 {inserted_count} 個知識點分數記錄，失敗 {error_count} 個")
            
            connection.commit()
            print(f"===== 已成功初始化用戶 {user_id} 的知識點分數 =====")
    except Exception as e:
        print(f"初始化知識點分數時出錯: {str(e)}")
        print(traceback.format_exc())


@router.get("/check")
async def check_user(user_id: str):
    """檢查用戶是否存在"""
    connection = None
    try:
        print(f"檢查用戶 {user_id} 是否存在...")
        connection = get_db_connection()
        with connection.cursor() as cursor:
            # 檢查用戶是否存在
            sql = "SELECT * FROM users WHERE user_id = %s"
            cursor.execute(sql, (user_id,))
            result = cursor.fetchone()
            
            if result:
                print(f"用戶 {user_id} 存在，開始初始化知識點分數...")
                # 用戶存在，檢查並初始化知識點分數
                await initialize_user_knowledge_scores(user_id, connection)
                return {"exists": True, "user": result}
            else:
                print(f"用戶 {user_id} 不存在")
                return {"exists": False}
    except Exception as e:
        print(f"檢查用戶時出錯: {str(e)}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    finally:
        if connection:
            connection.close()


@router.put("/{user_id}")
async def update_user(user_id: str, user: User):
    """更新用戶信息"""
    try:
        connection = get_db_connection()
        with connection.cursor() as cursor:
            # 檢查用戶是否存在
            sql = "SELECT * FROM users WHERE user_id = %s"
            cursor.execute(sql, (user_id,))
            existing_user = cursor.fetchone()
            
            if not existing_user:
                raise HTTPException(status_code=404, detail="User not found")
            
            # 更新用戶信息，添加對nickname、year_grade和introduction的支持
            sql = """
            UPDATE users
            SET email = %s, name = %s, photo_url = %s, nickname = %s, year_grade = %s, introduction = %s
            WHERE user_id = %s
            """
            cursor.execute(sql, (
                user.email,
                user.name,
                user.photo_url,
                user.nickname,
                user.year_grade,
                user.introduction,
                user_id
            ))
            connection.commit()
            
            # 獲取更新後的用戶
            sql = "SELECT * FROM users WHERE user_id = %s"
            cursor.execute(sql, (user_id,))
            updated_user = cursor.fetchone()
            
            return {"message": "User updated successfully", "user": updated_user}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    finally:
        connection.close()


@router.post("/register-token", response_model=StandardResponse)
async def register_token(request: RegisterTokenRequest):
    """註冊推播 token"""
    try:
        connection = get_db_connection()
        with connection.cursor() as cursor:
            # 檢查是否已存在該用戶的 token
            cursor.execute(
                "SELECT id FROM user_tokens WHERE user_id = %s", 
                (request.user_id,)
            )
            existing = cursor.fetchone()
            
            if existing:
                # 更新現有的 token
                cursor.execute(
                    "UPDATE user_tokens SET token = %s, updated_at = NOW() WHERE user_id = %s",
                    (request.token, request.user_id)
                )
            else:
                # 插入新的 token
                cursor.execute(
                    "INSERT INTO user_tokens (user_id, token, created_at, updated_at) VALUES (%s, %s, NOW(), NOW())",
                    (request.user_id, request.token)
                )
            
            connection.commit()
            return StandardResponse(
                success=True,
                message="Token 註冊成功"
            )
    except Exception as e:
        print(f"註冊 token 失敗: {e}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"註冊 token 失敗: {str(e)}")
    finally:
        if 'connection' in locals():
            connection.close()
