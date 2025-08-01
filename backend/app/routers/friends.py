"""
好友系統相關 API
"""
from fastapi import APIRouter, HTTPException, Body
from database import get_db_connection
from models import FriendRequest, FriendResponse, SearchUsersRequest, StandardResponse
from typing import Dict, Any
import traceback
import pymysql

# 好友系統相關 API
router = APIRouter(prefix="/friends", tags=["Friends"])


@router.get("/{user_id}", response_model=Dict[str, Any])
async def get_friends(user_id: str):
    """取得用戶的好友列表"""
    try:
        connection = get_db_connection()
        cursor = connection.cursor(pymysql.cursors.DictCursor)
        
        # 獲取好友列表（包括雙向的好友關係）- 使用簡化查詢測試
        query = """
        SELECT DISTINCT u.user_id, u.name, u.nickname, u.photo_url, u.year_grade, u.introduction
        FROM users u
        JOIN friendships f ON (
            (f.requester_id = %s AND f.addressee_id = u.user_id) OR
            (f.addressee_id = %s AND f.requester_id = u.user_id)
        )
        WHERE f.status = 'accepted'
        ORDER BY u.name
        """
        cursor.execute(query, (user_id, user_id))
        friends = cursor.fetchall()
        
        return {
            "status": "success",
            "friends": friends
        }
    
    except Exception as e:
        print(f"[get_friends] Error: {e}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    finally:
        if 'connection' in locals():
            connection.close()

@router.get("/requests/{user_id}", response_model=Dict[str, Any])
async def get_friend_requests(user_id: str):
    """取得用戶的好友請求列表"""
    try:
        connection = get_db_connection()
        with connection.cursor() as cursor:
            query = """
                SELECT 
                    f.id as request_id,
                    u.user_id as requester_id,
                    u.name as requester_name,
                    u.photo_url as requester_photo,
                    u.year_grade as requester_grade,
                    u.introduction as requester_intro
                FROM friendships f
                INNER JOIN users u ON f.requester_id = u.user_id
                WHERE f.addressee_id = %s AND f.status = 'pending'
                ORDER BY f.created_at DESC
                """
            cursor.execute(query, (user_id,))
            requests = cursor.fetchall()
            
        return {
            "status": "success",
            "requests": requests
        }
        
    except Exception as e:
        print(f"獲取好友請求時出錯: {str(e)}")
        return {
            "status": "error",
            "message": "無法獲取好友請求"
        }
    finally:
        if 'connection' in locals():
            connection.close()


@router.post("/send_request", response_model=StandardResponse)
async def send_friend_request(request: FriendRequest):
    """發送好友請求"""
    try:
        connection = get_db_connection()
        cursor = connection.cursor(pymysql.cursors.DictCursor)
        
        # 檢查是否已存在好友關係
        check_query = """
        SELECT id, status FROM friendships 
        WHERE (requester_id = %s AND addressee_id = %s) 
        OR (requester_id = %s AND addressee_id = %s)
        """
        cursor.execute(check_query, (
            request.requester_id, 
            request.addressee_id, 
            request.addressee_id, 
            request.requester_id
        ))
        existing = cursor.fetchone()
        
        if existing:
            status = existing['status']
            if status == 'accepted':
                return {"status": "error", "message": "已經是好友了"}
            elif status == 'blocked':
                return {"status": "error", "message": "無法發送好友請求"}
            elif status == 'pending':
                return {"status": "error", "message": "好友請求已存在，等待對方回應"}
            else:
                # 如果是被拒絕狀態，可以重新發送請求
                update_query = """
                UPDATE friendships 
                SET status = 'pending', 
                    updated_at = CURRENT_TIMESTAMP
                WHERE id = %s
                """
                cursor.execute(update_query, (existing['id'],))
                connection.commit()
                return {"status": "success", "message": "好友請求已重新發送"}
        
        # 創建新的好友請求
        insert_query = """
        INSERT INTO friendships (requester_id, addressee_id, status)
        VALUES (%s, %s, 'pending')
        """
        cursor.execute(insert_query, (request.requester_id, request.addressee_id))
        connection.commit()
        
        return {"status": "success", "message": "好友請求已發送"}
    
    except Exception as e:
        print(f"[send_friend_request] Error: {e}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    finally:
        if 'connection' in locals():
            connection.close()


@router.post("/respond_request", response_model=StandardResponse)
async def respond_friend_request(response: FriendResponse):
    """回應好友請求"""
    try:
        connection = get_db_connection()
        cursor = connection.cursor(pymysql.cursors.DictCursor)
        
        # 更新好友請求狀態
        update_query = """
        UPDATE friendships 
        SET status = %s,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = %s
        """
        cursor.execute(update_query, (response.status, response.request_id))
        connection.commit()
        
        return {
            "status": "success",
            "message": "好友請求已更新"
        }
        
    
    except Exception as e:
        print(f"[respond_friend_request] Error: {e}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    finally:
        if 'connection' in locals():
            connection.close()


@router.post("/cancel_request", response_model=StandardResponse)
async def cancel_friend_request(request: dict = Body(...)):
    """取消好友請求"""
    try:
        connection = get_db_connection()
        with connection.cursor() as cursor:
            sql = "DELETE FROM friendships WHERE id = %s"
            cursor.execute(sql, (request['request_id'],))
            connection.commit()
            
            return StandardResponse(success=True, message="已取消好友請求")
    
    except Exception as e:
        print(f"[cancel_friend_request] Error: {e}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    finally:
        if 'connection' in locals():
            connection.close()


@router.post("/search", response_model=Dict[str, Any])
async def search_users(request: SearchUsersRequest):
    """搜尋用戶"""
    try:
        connection = get_db_connection()
        with connection.cursor() as cursor:
            sql = """
            SELECT user_id, name, nickname, photo_url, year_grade, introduction
            FROM users 
            WHERE (name LIKE %s OR nickname LIKE %s OR user_id LIKE %s)
            AND user_id != %s
            LIMIT 20
            """
            search_pattern = f"%{request.query}%"
            cursor.execute(sql, (search_pattern, search_pattern, search_pattern, request.current_user_id))
            users = cursor.fetchall()
            
            # 檢查每個用戶的好友狀態
            for user in users:
                # 檢查是否已經是好友
                friend_sql = """
                SELECT COUNT(*) as count FROM friendships 
                WHERE ((requester_id = %s AND addressee_id = %s) OR (requester_id = %s AND addressee_id = %s))
                AND status = 'accepted'
                """
                cursor.execute(friend_sql, (request.current_user_id, user['user_id'], 
                                         user['user_id'], request.current_user_id))
                friend_result = cursor.fetchone()
                user['is_friend'] = friend_result['count'] > 0
                
                # 檢查是否有待處理的請求
                pending_sql = """
                SELECT id, requester_id, status FROM friendships 
                WHERE ((requester_id = %s AND addressee_id = %s) OR (requester_id = %s AND addressee_id = %s))
                AND status = 'pending'
                """
                cursor.execute(pending_sql, (request.current_user_id, user['user_id'], 
                                           user['user_id'], request.current_user_id))
                pending_result = cursor.fetchone()
                
                if pending_result:
                    user['friend_status'] = 'pending'
                    user['request_id'] = pending_result['id']
                    # 檢查是當前用戶發送的請求還是接收的請求
                    user['is_requester'] = pending_result['requester_id'] == request.current_user_id
                elif user['is_friend']:
                    user['friend_status'] = 'accepted'
                else:
                    user['friend_status'] = 'none'
        
        return {
            "status": "success", 
            "users": users
        }
    
    except Exception as e:
        print(f"[search_users] Error: {e}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    finally:
        if 'connection' in locals():
            connection.close()
