"""
管理員功能相關 API
"""
from fastapi import APIRouter, HTTPException, UploadFile, File, Form, Body
from database import get_db_connection
from models import ImportKnowledgePointsRequest, StandardResponse
from typing import Dict, Any
import traceback
import csv
import io

router = APIRouter(prefix="/admin", tags=["Admin"])


@router.post("/import-knowledge-points", response_model=Dict[str, Any])
async def import_knowledge_points(
    subject: str = Form(...),
    file: UploadFile = File(...)
):
    """
    導入知識點和章節 CSV 文件
    """
    print(f"開始導入知識點和章節... 科目: {subject}")
    
    if not file.filename.endswith('.csv'):
        raise HTTPException(status_code=400, detail="只接受 CSV 文件")
    
    try:
        # 讀取上傳的文件內容
        contents = await file.read()
        csv_file = io.StringIO(contents.decode('utf-8'))
        csv_reader = csv.reader(csv_file)
        
        # 跳過標題行（如果有）
        next(csv_reader, None)
        
        connection = get_db_connection()
        imported_knowledge_count = 0
        imported_chapter_count = 0
        
        with connection.cursor() as cursor:
            for row in csv_reader:
                if len(row) < 3:  # 假設 CSV 格式：章節,小節,知識點
                    continue
                
                chapter = row[0].strip()
                section = row[1].strip()
                knowledge_point = row[2].strip()
                
                if not chapter or not section or not knowledge_point:
                    continue
                
                try:
                    # 檢查並插入章節
                    sql = """
                    SELECT id FROM chapters 
                    WHERE subject = %s AND chapter_name = %s
                    """
                    cursor.execute(sql, (subject, chapter))
                    chapter_result = cursor.fetchone()
                    
                    if not chapter_result:
                        sql = """
                        INSERT INTO chapters (subject, chapter_name, created_at)
                        VALUES (%s, %s, NOW())
                        """
                        cursor.execute(sql, (subject, chapter))
                        chapter_id = cursor.lastrowid
                        imported_chapter_count += 1
                        print(f"新增章節: {subject} - {chapter}")
                    else:
                        chapter_id = chapter_result['id']
                    
                    # 檢查並插入知識點
                    sql = """
                    SELECT COUNT(*) as count FROM knowledge_points 
                    WHERE subject = %s AND chapter_name = %s AND section_name = %s AND point_name = %s
                    """
                    cursor.execute(sql, (subject, chapter, section, knowledge_point))
                    kp_result = cursor.fetchone()
                    
                    if kp_result['count'] == 0:
                        sql = """
                        INSERT INTO knowledge_points 
                        (subject, chapter_name, section_name, point_name, chapter_id, created_at)
                        VALUES (%s, %s, %s, %s, %s, NOW())
                        """
                        cursor.execute(sql, (subject, chapter, section, knowledge_point, chapter_id))
                        imported_knowledge_count += 1
                        print(f"新增知識點: {subject} - {chapter} - {section} - {knowledge_point}")
                    else:
                        print(f"知識點已存在: {subject} - {chapter} - {section} - {knowledge_point}")
                
                except Exception as row_error:
                    print(f"處理行資料時出錯: {row}, 錯誤: {row_error}")
                    continue
        
        connection.commit()
        
        return {
            "success": True,
            "message": f"成功導入 {imported_chapter_count} 個章節和 {imported_knowledge_count} 個知識點",
            "chapters_imported": imported_chapter_count,
            "knowledge_points_imported": imported_knowledge_count
        }
    
    except Exception as e:
        print(f"處理 CSV 文件時出錯: {e}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"導入失敗: {str(e)}")
    finally:
        if 'connection' in locals():
            connection.close()


@router.get("/subjects_and_chapters", response_model=Dict[str, Any])
async def get_subjects_and_chapters():
    """取得所有科目和章節列表"""
    try:
        connection = get_db_connection()
        with connection.cursor() as cursor:
            # 獲取所有科目和章節
            sql = """
            SELECT DISTINCT subject, chapter_name
            FROM chapters
            ORDER BY subject, chapter_name
            """
            cursor.execute(sql)
            results = cursor.fetchall()
            
            # 按科目分組
            subjects_data = {}
            for record in results:
                subject = record['subject']
                chapter = record['chapter_name']
                
                if subject not in subjects_data:
                    subjects_data[subject] = []
                
                subjects_data[subject].append(chapter)
            
            # 獲取知識點統計
            sql = """
            SELECT subject, COUNT(*) as knowledge_points_count
            FROM knowledge_points
            GROUP BY subject
            """
            cursor.execute(sql)
            kp_stats = cursor.fetchall()
            
            # 添加統計資訊
            for stat in kp_stats:
                subject = stat['subject']
                if subject in subjects_data:
                    subjects_data[subject] = {
                        'chapters': subjects_data[subject],
                        'knowledge_points_count': stat['knowledge_points_count']
                    }
            
            return {"subjects": subjects_data}
    
    except Exception as e:
        print(f"[get_subjects_and_chapters] Error: {e}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    finally:
        if 'connection' in locals():
            connection.close()


@router.post("/create_tables", response_model=StandardResponse)
async def create_required_tables():
    """創建必要的資料表（僅在開發環境使用）"""
    try:
        connection = get_db_connection()
        with connection.cursor() as cursor:
            # 創建聊天歷史表
            sql = """
            CREATE TABLE IF NOT EXISTS chat_history (
                id INT AUTO_INCREMENT PRIMARY KEY,
                user_id VARCHAR(255) NOT NULL,
                user_message TEXT,
                ai_response TEXT,
                image_base64 LONGTEXT,
                subject VARCHAR(100),
                chapter VARCHAR(100),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                INDEX idx_user_id (user_id),
                INDEX idx_created_at (created_at)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            """
            cursor.execute(sql)
            
            # 創建提醒歷史表
            sql = """
            CREATE TABLE IF NOT EXISTS reminder_history (
                id INT AUTO_INCREMENT PRIMARY KEY,
                user_id VARCHAR(255) NOT NULL,
                subject VARCHAR(100),
                chapter VARCHAR(100),
                difficulty_level VARCHAR(50),
                sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                success_count INT DEFAULT 0,
                INDEX idx_user_id (user_id),
                INDEX idx_sent_at (sent_at)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            """
            cursor.execute(sql)
            
            # 創建用戶 token 表
            sql = """
            CREATE TABLE IF NOT EXISTS user_tokens (
                id INT AUTO_INCREMENT PRIMARY KEY,
                user_id VARCHAR(255) NOT NULL,
                token TEXT NOT NULL,
                is_active BOOLEAN DEFAULT TRUE,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                INDEX idx_user_id (user_id),
                INDEX idx_is_active (is_active)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            """
            cursor.execute(sql)
            
            connection.commit()
            return StandardResponse(success=True, message="資料表創建成功")
    
    except Exception as e:
        print(f"[create_tables] Error: {e}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    finally:
        if 'connection' in locals():
            connection.close()


@router.get("/system_stats", response_model=Dict[str, Any])
async def get_system_stats():
    """取得系統統計資訊"""
    try:
        connection = get_db_connection()
        with connection.cursor() as cursor:
            stats = {}
            
            # 用戶統計
            sql = "SELECT COUNT(*) as total_users FROM users"
            cursor.execute(sql)
            stats['total_users'] = cursor.fetchone()['total_users']
            
            # 題目統計
            sql = "SELECT COUNT(*) as total_questions FROM questions"
            cursor.execute(sql)
            stats['total_questions'] = cursor.fetchone()['total_questions']
            
            # 答題統計
            sql = "SELECT COUNT(*) as total_answers FROM user_answers"
            cursor.execute(sql)
            stats['total_answers'] = cursor.fetchone()['total_answers']
            
            # 科目統計
            sql = "SELECT COUNT(DISTINCT subject) as total_subjects FROM chapters"
            cursor.execute(sql)
            stats['total_subjects'] = cursor.fetchone()['total_subjects']
            
            # 知識點統計
            sql = "SELECT COUNT(*) as total_knowledge_points FROM knowledge_points"
            cursor.execute(sql)
            stats['total_knowledge_points'] = cursor.fetchone()['total_knowledge_points']
            
            # 今日活躍用戶
            sql = """
            SELECT COUNT(DISTINCT user_id) as active_today 
            FROM user_answers 
            WHERE DATE(answered_at) = CURDATE()
            """
            cursor.execute(sql)
            stats['active_today'] = cursor.fetchone()['active_today']
            
            # 本週活躍用戶
            sql = """
            SELECT COUNT(DISTINCT user_id) as active_week 
            FROM user_answers 
            WHERE answered_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
            """
            cursor.execute(sql)
            stats['active_week'] = cursor.fetchone()['active_week']
            
            return {"stats": stats}
    
    except Exception as e:
        print(f"[get_system_stats] Error: {e}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    finally:
        if 'connection' in locals():
            connection.close()


@router.post("/cleanup_inactive_tokens", response_model=StandardResponse)
async def cleanup_inactive_tokens():
    """清理不活躍的推播 token"""
    try:
        connection = get_db_connection()
        with connection.cursor() as cursor:
            # 刪除 30 天內未更新的不活躍 token
            sql = """
            DELETE FROM user_tokens 
            WHERE is_active = 0 
            AND updated_at < DATE_SUB(NOW(), INTERVAL 30 DAY)
            """
            cursor.execute(sql)
            deleted_count = cursor.rowcount
            connection.commit()
            
            return StandardResponse(
                success=True,
                message=f"已清理 {deleted_count} 個不活躍的 token"
            )
    
    except Exception as e:
        print(f"[cleanup_inactive_tokens] Error: {e}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    finally:
        if 'connection' in locals():
            connection.close()
