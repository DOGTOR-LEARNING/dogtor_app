"""
好友系統相關 API
"""
from fastapi import APIRouter, HTTPException, Body
from ..database import get_db_connection
from ..models import FriendRequest, FriendResponse, SearchUsersRequest, StandardResponse
from typing import Dict, Any
import traceback

router = APIRouter(prefix="/friends", tags=["Friends"])


@router.get("/{user_id}", response_model=Dict[str, Any])
async def get_friends(user_id: str):
    """取得用戶的好友列表"""
    try:
        connection = get_db_connection()
        with connection.cursor() as cursor:
            sql = """
            SELECT f.id, f.friend_id, u.name, u.nickname, u.photo_url, f.created_at
            FROM friends f
            JOIN users u ON f.friend_id = u.user_id
            WHERE f.user_id = %s
            ORDER BY f.created_at DESC
            """
            cursor.execute(sql, (user_id,))
            friends = cursor.fetchall()
        
        return {"friends": friends}
    
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
            # 獲取收到的好友請求
            sql = """
            SELECT fr.id, fr.requester_id, u.name, u.nickname, u.photo_url, fr.created_at
            FROM friend_requests fr
            JOIN users u ON fr.requester_id = u.user_id
            WHERE fr.addressee_id = %s AND fr.status = 'pending'
            ORDER BY fr.created_at DESC
            """
            cursor.execute(sql, (user_id,))
            received_requests = cursor.fetchall()
            
            # 獲取發出的好友請求
            sql = """
            SELECT fr.id, fr.addressee_id, u.name, u.nickname, u.photo_url, fr.created_at, fr.status
            FROM friend_requests fr
            JOIN users u ON fr.addressee_id = u.user_id
            WHERE fr.requester_id = %s
            ORDER BY fr.created_at DESC
            """
            cursor.execute(sql, (user_id,))
            sent_requests = cursor.fetchall()
        
        return {
            "received_requests": received_requests,
            "sent_requests": sent_requests
        }
    
    except Exception as e:
        print(f"[get_friend_requests] Error: {e}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    finally:
        if 'connection' in locals():
            connection.close()


@router.post("/send_request", response_model=StandardResponse)
async def send_friend_request(request: FriendRequest):
    """發送好友請求"""
    try:
        connection = get_db_connection()
        with connection.cursor() as cursor:
            # 檢查是否已經是好友
            sql = """
            SELECT COUNT(*) as count FROM friends 
            WHERE (user_id = %s AND friend_id = %s) OR (user_id = %s AND friend_id = %s)
            """
            cursor.execute(sql, (request.requester_id, request.addressee_id, 
                                request.addressee_id, request.requester_id))
            result = cursor.fetchone()
            
            if result['count'] > 0:
                return StandardResponse(success=False, message="已經是好友了")
            
            # 檢查是否已經有待處理的請求
            sql = """
            SELECT COUNT(*) as count FROM friend_requests 
            WHERE requester_id = %s AND addressee_id = %s AND status = 'pending'
            """
            cursor.execute(sql, (request.requester_id, request.addressee_id))
            result = cursor.fetchone()
            
            if result['count'] > 0:
                return StandardResponse(success=False, message="已經發送過好友請求了")
            
            # 插入好友請求
            sql = """
            INSERT INTO friend_requests (requester_id, addressee_id, status, created_at)
            VALUES (%s, %s, 'pending', NOW())
            """
            cursor.execute(sql, (request.requester_id, request.addressee_id))
            connection.commit()
            
            return StandardResponse(success=True, message="好友請求已發送")
    
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
        with connection.cursor() as cursor:
            if response.status == "accepted":
                # 更新請求狀態
                sql = "UPDATE friend_requests SET status = 'accepted' WHERE id = %s"
                cursor.execute(sql, (response.request_id,))
                
                # 獲取請求詳情
                sql = "SELECT requester_id, addressee_id FROM friend_requests WHERE id = %s"
                cursor.execute(sql, (response.request_id,))
                request_info = cursor.fetchone()
                
                if request_info:
                    # 雙向添加好友關係
                    sql = """
                    INSERT INTO friends (user_id, friend_id, created_at)
                    VALUES (%s, %s, NOW()), (%s, %s, NOW())
                    """
                    cursor.execute(sql, (
                        request_info['requester_id'], request_info['addressee_id'],
                        request_info['addressee_id'], request_info['requester_id']
                    ))
                
                connection.commit()
                return StandardResponse(success=True, message="已接受好友請求")
            
            elif response.status in ["rejected", "blocked"]:
                sql = "UPDATE friend_requests SET status = %s WHERE id = %s"
                cursor.execute(sql, (response.status, response.request_id))
                connection.commit()
                return StandardResponse(success=True, message=f"已{response.status}好友請求")
            
            else:
                return StandardResponse(success=False, message="無效的回應狀態")
    
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
            sql = "DELETE FROM friend_requests WHERE id = %s"
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
            SELECT user_id, name, nickname, photo_url, year_grade
            FROM users 
            WHERE (name LIKE %s OR nickname LIKE %s OR user_id LIKE %s)
            AND user_id != %s
            LIMIT 20
            """
            search_pattern = f"%{request.search_term}%"
            cursor.execute(sql, (search_pattern, search_pattern, search_pattern, request.current_user_id))
            users = cursor.fetchall()
            
            # 檢查好友狀態
            for user in users:
                # 檢查是否已經是好友
                sql = """
                SELECT COUNT(*) as count FROM friends 
                WHERE (user_id = %s AND friend_id = %s) OR (user_id = %s AND friend_id = %s)
                """
                cursor.execute(sql, (request.current_user_id, user['user_id'], 
                                   user['user_id'], request.current_user_id))
                friend_result = cursor.fetchone()
                user['is_friend'] = friend_result['count'] > 0
                
                # 檢查是否有待處理的請求
                sql = """
                SELECT COUNT(*) as count FROM friend_requests 
                WHERE ((requester_id = %s AND addressee_id = %s) OR (requester_id = %s AND addressee_id = %s))
                AND status = 'pending'
                """
                cursor.execute(sql, (request.current_user_id, user['user_id'], 
                                   user['user_id'], request.current_user_id))
                request_result = cursor.fetchone()
                user['has_pending_request'] = request_result['count'] > 0
        
        return {"users": users}
    
    except Exception as e:
        print(f"[search_users] Error: {e}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    finally:
        if 'connection' in locals():
            connection.close()
