"""
題目與測驗相關 API
"""
from fastapi import APIRouter, HTTPException, Request
from typing import Optional, List
from models import QuestionRequest, QuestionResponse, RecordAnswerRequest, RecordAnswerResponse, CompleteLevelRequest, CompleteLevelResponse, StandardResponse
from database import get_db_connection
import json
import traceback
import random
from datetime import datetime


router = APIRouter(prefix="/quiz", tags=["Quiz & Questions"])


@router.get("/random_chapter")
async def get_random_chapter(subject: Optional[str] = None):
    """獲取隨機章節"""
    try:
        connection = get_db_connection()
        
        with connection.cursor() as cursor:
            if subject:
                # 根據科目獲取隨機章節
                cursor.execute("""
                    SELECT DISTINCT chapter_name, subject 
                    FROM chapter_list 
                    WHERE subject = %s 
                    ORDER BY RAND() 
                    LIMIT 1
                """, (subject,))
            else:
                # 獲取任意隨機章節
                cursor.execute("""
                    SELECT DISTINCT chapter_name, subject 
                    FROM chapter_list 
                    ORDER BY RAND() 
                    LIMIT 1
                """)
            
            result = cursor.fetchone()
            
            if result:
                return {
                    "success": True,
                    "chapter": result[0],
                    "subject": result[1]
                }
            else:
                return {
                    "success": False,
                    "message": "找不到可用的章節"
                }
                
    except Exception as e:
        print(f"獲取隨機章節錯誤: {e}")
        raise HTTPException(status_code=500, detail="獲取隨機章節失敗")
    finally:
        if connection:
            connection.close()


@router.get("/subjects")
async def get_available_subjects():
    """獲取可用的科目列表"""
    try:
        connection = get_db_connection()
        
        with connection.cursor() as cursor:
            cursor.execute("""
                SELECT DISTINCT subject 
                FROM chapter_list 
                ORDER BY subject
            """)
            
            results = cursor.fetchall()
            subjects = [row[0] for row in results]
            
            return {
                "success": True,
                "subjects": subjects
            }
                
    except Exception as e:
        print(f"獲取科目列表錯誤: {e}")
        raise HTTPException(status_code=500, detail="獲取科目列表失敗")
    finally:
        if connection:
            connection.close()


@router.get("/chapters/{subject}")
async def get_chapters_by_subject(subject: str):
    """根據科目獲取章節列表"""
    try:
        connection = get_db_connection()
        
        with connection.cursor() as cursor:
            cursor.execute("""
                SELECT DISTINCT chapter_name 
                FROM chapter_list 
                WHERE subject = %s 
                ORDER BY chapter_num
            """, (subject,))
            
            results = cursor.fetchall()
            chapters = [row[0] for row in results]
            
            return {
                "success": True,
                "chapters": chapters,
                "subject": subject
            }
                
    except Exception as e:
        print(f"獲取章節列表錯誤: {e}")
        raise HTTPException(status_code=500, detail="獲取章節列表失敗")
    finally:
        if connection:
            connection.close()


@router.post("/questions", response_model=QuestionResponse)
async def get_questions_by_level(request: QuestionRequest):
    """根據關卡獲取題目"""
    try:
        print(f"接收到的請求參數: chapter={request.chapter}, section={request.section}, knowledge_points={request.knowledge_points}, user_id={request.user_id}, level_id={request.level_id}")
        
        # 檢查參數
        if not request.section and not request.knowledge_points:
            return QuestionResponse(
                success=False,
                message="必須提供 section 或 knowledge_points"
            )
        
        connection = get_db_connection()
        connection.charset = 'utf8mb4'
        
        try:
            with connection.cursor() as cursor:
                # 設置連接的字符集
                cursor.execute("SET NAMES utf8mb4")
                cursor.execute("SET CHARACTER SET utf8mb4")
                cursor.execute("SET character_set_connection=utf8mb4")
                
                # 處理知識點
                knowledge_point_list = []
                if request.knowledge_points:
                    if request.knowledge_points.strip() == "章節所有知識點":
                        print("檢測到章節總複習，從章節所有知識點中選題")
                        
                        if request.chapter:
                            cursor.execute("""
                            SELECT DISTINCT kp.point_name, kp.id
                            FROM knowledge_points kp
                            JOIN chapter_list cl ON kp.chapter_id = cl.id
                            WHERE cl.chapter_name = %s
                            """, (request.chapter,))
                        else:
                            if request.level_id:
                                cursor.execute("""
                                SELECT chapter_id FROM level_info WHERE id = %s
                                """, (request.level_id,))
                                level_result = cursor.fetchone()
                                
                                if level_result:
                                    cursor.execute("""
                                    SELECT DISTINCT point_name, id
                                    FROM knowledge_points 
                                    WHERE chapter_id = %s
                                    """, (level_result['chapter_id'],))
                                else:
                                    return QuestionResponse(
                                        success=False,
                                        message=f"找不到關卡 ID {request.level_id} 對應的章節"
                                    )
                            else:
                                return QuestionResponse(
                                    success=False,
                                    message="章節總複習需要提供章節名稱或關卡ID"
                                )
                        
                        chapter_knowledge_points = cursor.fetchall()
                        if not chapter_knowledge_points:
                            return QuestionResponse(
                                success=False,
                                message="找不到該章節的知識點"
                            )
                        
                        knowledge_point_list = [kp['point_name'] for kp in chapter_knowledge_points]
                        print(f"章節總複習包含 {len(knowledge_point_list)} 個知識點: {knowledge_point_list}")
                    else:
                        # 一般情況：將知識點字符串拆分
                        if '、' in request.knowledge_points:
                            knowledge_point_list = [kp.strip() for kp in request.knowledge_points.split('、')]
                        elif ',' in request.knowledge_points:
                            knowledge_point_list = [kp.strip() for kp in request.knowledge_points.split(',')]
                        else:
                            knowledge_point_list = [request.knowledge_points.strip()]

                # 獲取知識點的ID
                knowledge_ids = []
                for kp in knowledge_point_list:
                    cursor.execute("SELECT id FROM knowledge_points WHERE point_name = %s", (kp,))
                    result = cursor.fetchone()
                    if result:
                        knowledge_ids.append(result['id'])
                    else:
                        # 嘗試模糊匹配
                        cursor.execute("SELECT id FROM knowledge_points WHERE point_name LIKE %s", (f"%{kp}%",))
                        results = cursor.fetchall()
                        for r in results:
                            if r['id'] not in knowledge_ids:
                                knowledge_ids.append(r['id'])

                if not knowledge_ids:
                    return QuestionResponse(
                        success=False,
                        message="找不到匹配的知識點"
                    )

                print(f"找到的知識點 ID: {knowledge_ids}")
                
                # 獲取題目（簡化版，獲取所有相關題目）
                all_questions = []
                for knowledge_id in knowledge_ids:
                    sql = """
                    SELECT q.id, q.knowledge_id, q.question_text, q.option_1, q.option_2, q.option_3, q.option_4, q.correct_answer, q.explanation, kp.point_name as knowledge_point
                    FROM questions q
                    JOIN knowledge_points kp ON q.knowledge_id = kp.id
                    WHERE q.knowledge_id = %s AND (q.Error_message IS NULL OR q.Error_message = '')
                    ORDER BY RAND()
                    LIMIT 3
                    """
                    
                    cursor.execute(sql, (knowledge_id,))
                    knowledge_questions = cursor.fetchall()
                    all_questions.extend(knowledge_questions)
                
                # 限制總題目數為10題
                if len(all_questions) > 10:
                    all_questions = all_questions[:10]
                
                # 將結果轉換為標準格式
                result = []
                for q in all_questions:
                    result.append({
                        "id": q["id"],
                        "question_text": q["question_text"],
                        "options": [
                            q["option_1"],
                            q["option_2"],
                            q["option_3"],
                            q["option_4"]
                        ],
                        "correct_answer": int(q["correct_answer"]) - 1,  # 轉換為 0-based 索引
                        "explanation": q["explanation"] or "",
                        "knowledge_point": q["knowledge_point"],
                        "knowledge_id": q["knowledge_id"]
                    })
                
                return QuestionResponse(
                    success=True,
                    questions=result
                )
        
        finally:
            connection.close()
    
    except Exception as e:
        print(f"Error: {str(e)}")
        print(traceback.format_exc())
        return QuestionResponse(
            success=False,
            message=f"獲取題目時出錯: {str(e)}"
        )


@router.post("/record_answer", response_model=RecordAnswerResponse)
async def record_answer(request: RecordAnswerRequest):
    """記錄用戶答題情況"""
    try:
        print(f"收到記錄答題請求: user_id={request.user_id}, question_id={request.question_id}, is_correct={request.is_correct}")
        
        connection = get_db_connection()
        connection.charset = 'utf8mb4'
        
        try:
            with connection.cursor() as cursor:
                # 設置連接的字符集
                cursor.execute("SET NAMES utf8mb4")
                cursor.execute("SET CHARACTER SET utf8mb4")
                cursor.execute("SET character_set_connection=utf8mb4")
                
                # 檢查記錄是否存在
                cursor.execute(
                    "SELECT id, total_attempts, correct_attempts FROM user_question_stats WHERE user_id = %s AND question_id = %s",
                    (request.user_id, request.question_id)
                )
                record = cursor.fetchone()
                
                current_time = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                
                if record:
                    # 更新現有記錄
                    record_id = record['id']
                    total_attempts = record['total_attempts'] + 1
                    correct_attempts = record['correct_attempts'] + (1 if request.is_correct else 0)
                    
                    cursor.execute(
                        "UPDATE user_question_stats SET total_attempts = %s, correct_attempts = %s, last_attempted_at = %s WHERE id = %s",
                        (total_attempts, correct_attempts, current_time, record_id)
                    )
                else:
                    # 創建新記錄
                    cursor.execute(
                        "INSERT INTO user_question_stats (user_id, question_id, total_attempts, correct_attempts, last_attempted_at) VALUES (%s, %s, %s, %s, %s)",
                        (request.user_id, request.question_id, 1, 1 if request.is_correct else 0, current_time)
                    )
                
                connection.commit()
                print(f"成功記錄答題情況")
                return RecordAnswerResponse(
                    success=True,
                    message="答題記錄已保存"
                )
                
        except Exception as e:
            connection.rollback()
            print(f"資料庫錯誤: {str(e)}")
            return RecordAnswerResponse(
                success=False,
                message=f"資料庫錯誤: {str(e)}"
            )
        finally:
            connection.close()
            
    except Exception as e:
        print(f"處理答題記錄時出錯: {str(e)}")
        print(traceback.format_exc())
        return RecordAnswerResponse(
            success=False,
            message=f"處理錯誤: {str(e)}"
        )


@router.post("/complete_level", response_model=CompleteLevelResponse)
async def complete_level(request: CompleteLevelRequest):
    """記錄關卡完成情況"""
    try:
        print(f"收到關卡完成請求: user_id={request.user_id}, level_id={request.level_id}, stars={request.stars}")
        
        connection = get_db_connection()
        connection.charset = 'utf8mb4'
        
        try:
            with connection.cursor() as cursor:
                # 設置連接的字符集
                cursor.execute("SET NAMES utf8mb4")
                cursor.execute("SET CHARACTER SET utf8mb4")
                cursor.execute("SET character_set_connection=utf8mb4")
                
                current_time = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                
                # 創建新記錄
                insert_sql = """
                INSERT INTO user_level (user_id, level_id, stars, ai_comment, answered_at) 
                VALUES (%s, %s, %s, %s, %s)
                """
                cursor.execute(insert_sql, (request.user_id, request.level_id, request.stars, request.ai_comment, current_time))
                
                connection.commit()
                
                return CompleteLevelResponse(
                    success=True,
                    message="關卡完成記錄已新增"
                )
        
        finally:
            connection.close()
    
    except Exception as e:
        print(f"記錄關卡完成時出錯: {str(e)}")
        print(traceback.format_exc())
        return CompleteLevelResponse(
            success=False,
            message=f"記錄關卡完成時出錯: {str(e)}"
        )


@router.post("/report-error", response_model=StandardResponse)
async def report_question_error(question_id: int, error_message: str):
    """回報題目錯誤"""
    try:
        if not question_id or not error_message:
            return StandardResponse(
                success=False,
                message="缺少必要參數"
            )
        
        connection = get_db_connection()
        connection.charset = 'utf8mb4'
        
        try:
            with connection.cursor() as cursor:
                # 設置連接的字符集
                cursor.execute("SET NAMES utf8mb4")
                cursor.execute("SET CHARACTER SET utf8mb4")
                cursor.execute("SET character_set_connection=utf8mb4")
                
                # 更新題目的錯誤訊息
                sql = """
                UPDATE questions 
                SET Error_message = %s 
                WHERE id = %s
                """
                cursor.execute(sql, (error_message, question_id))
                connection.commit()
                
                return StandardResponse(
                    success=True,
                    message="回報成功"
                )
        
        finally:
            connection.close()
    
    except Exception as e:
        print(f"Error: {str(e)}")
        print(traceback.format_exc())
        return StandardResponse(
            success=False,
            message=f"回報題目錯誤時出錯: {str(e)}"
        )
