"""
錯題本相關 API
"""
from fastapi import APIRouter, HTTPException, Body
from typing import Optional
from models import MistakeBookRequest, MistakeBookResponse, StandardResponse
from database import get_db_connection
import traceback


router = APIRouter(prefix="/mistake-book", tags=["Mistake Book"])


@router.post("/", response_model=MistakeBookResponse)
async def add_mistake_book(request: MistakeBookRequest):
    """新增錯題"""
    try:
        connection = get_db_connection()
        with connection.cursor() as cursor:
            sql = """
            INSERT INTO mistake_book (
                user_id, summary, subject, chapter, difficulty, tag, description, answer, note, created_at, question_image_base64, answer_image_base64
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """
            cursor.execute(sql, (
                request.user_id,
                request.summary,
                request.subject,
                request.chapter,
                request.difficulty,
                request.tag,
                request.description,
                request.answer,
                request.note,
                request.created_at,
                request.question_image_base64 or '',
                request.answer_image_base64 or '',
            ))
            connection.commit()
            # 回傳新插入的 id
            q_id = cursor.lastrowid
        return MistakeBookResponse(status="success", q_id=q_id)
    except Exception as e:
        print(f"[add_mistake_book] Error: {e}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    finally:
        if 'connection' in locals():
            connection.close()


@router.get("/")
async def get_mistake_book(user_id: Optional[str] = None):
    """取得錯題列表"""
    try:
        connection = get_db_connection()
        with connection.cursor() as cursor:
            if user_id:
                sql = "SELECT * FROM mistake_book WHERE user_id = %s ORDER BY created_at DESC"
                cursor.execute(sql, (user_id,))
            else:
                sql = "SELECT * FROM mistake_book ORDER BY created_at DESC"
                cursor.execute(sql)
            results = cursor.fetchall()
        
        # 將 bytes 轉成 str（如果有圖片）
        for r in results:
            if 'question_image_base64' in r and isinstance(r['question_image_base64'], bytes):
                r['question_image_base64'] = r['question_image_base64'].decode('utf-8')
            if 'answer_image_base64' in r and isinstance(r['answer_image_base64'], bytes):
                r['answer_image_base64'] = r['answer_image_base64'].decode('utf-8')
        
        return results
    except Exception as e:
        print(f"[get_mistake_book] Error: {e}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    finally:
        if 'connection' in locals():
            connection.close()


@router.delete("/{q_id}", response_model=StandardResponse)
async def delete_mistake_book(q_id: int):
    """刪除錯題"""
    try:
        connection = get_db_connection()
        with connection.cursor() as cursor:
            sql = "DELETE FROM mistake_book WHERE id = %s"
            cursor.execute(sql, (q_id,))
            connection.commit()
            return StandardResponse(
                success=True,
                message=f"已刪除錯題 ID: {q_id}"
            )
    except Exception as e:
        print(f"[delete_mistake_book] Error: {e}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    finally:
        if 'connection' in locals():
            connection.close()
