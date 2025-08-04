"""
題目與測驗相關 API
"""
from fastapi import APIRouter, HTTPException, Request
from typing import Optional, List, Dict
from models import QuestionRequest, QuestionResponse, RecordAnswerRequest, RecordAnswerResponse, CompleteLevelRequest, CompleteLevelResponse, StandardResponse, UserLevelStarsRequest, UserLevelStarsResponse
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
                
                # 將知識點字符串拆分為列表
                knowledge_point_list = []
                if request.knowledge_points:
                    # 檢查是否為章節總複習
                    if request.knowledge_points.strip() == "章節所有知識點":
                        print("檢測到章節總複習，從章節所有知識點中選題")
                        
                        # 獲取該章節的所有知識點
                        if request.chapter:
                            cursor.execute("""
                            SELECT DISTINCT kp.point_name, kp.id
                            FROM knowledge_points kp
                            JOIN chapter_list cl ON kp.chapter_id = cl.id
                            WHERE cl.chapter_name = %s
                            """, (request.chapter,))
                        else:
                            # 如果沒有提供章節名稱，嘗試從 level_id 獲取
                            if request.level_id:
                                # 首先嘗試從 level_info 表獲取關卡對應的章節 ID
                                cursor.execute("""
                                SELECT chapter_id FROM level_info WHERE id = %s
                                """, (request.level_id,))
                                level_result = cursor.fetchone()
                                
                                if level_result:
                                    # 使用章節 ID 獲取所有知識點
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
                        # 嘗試使用頓號（、）分隔
                        if '、' in request.knowledge_points:
                            knowledge_point_list = [kp.strip() for kp in request.knowledge_points.split('、')]
                        # 嘗試使用逗號（,）分隔
                        elif ',' in request.knowledge_points:
                            knowledge_point_list = [kp.strip() for kp in request.knowledge_points.split(',')]
                        # 如果只有一個知識點
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

                # 如果仍然沒有找到知識點，嘗試使用 level_id 查找
                if not knowledge_ids and request.level_id:
                    cursor.execute("""
                    SELECT kp.id
                    FROM knowledge_points kp
                    JOIN level_knowledge_mapping lkm ON kp.id = lkm.knowledge_id
                    WHERE lkm.level_id = %s
                    """, (request.level_id,))
                    results = cursor.fetchall()
                    for r in results:
                        knowledge_ids.append(r['id'])

                print(f"知識點列表: {knowledge_point_list}")
                print(f"找到的知識點 ID: {knowledge_ids}")
                
                # 如果沒有找到任何知識點 ID，返回錯誤
                if not knowledge_ids:
                    return QuestionResponse(
                        success=False,
                        message="找不到匹配的知識點"
                    )
                
                # 如果有用戶ID，獲取用戶對這些知識點的掌握程度
                knowledge_scores = {}
                total_score = 0
                if request.user_id:
                    for knowledge_id in knowledge_ids:
                        cursor.execute("""
                        SELECT score FROM user_knowledge_score 
                        WHERE user_id = %s AND knowledge_id = %s
                        """, (request.user_id, knowledge_id))
                        result = cursor.fetchone()
                        # 如果沒有分數記錄，默認為5分（中等掌握程度）
                        score = result['score'] if result else 5
                        knowledge_scores[knowledge_id] = score
                        total_score += score

                # 計算每個知識點應該分配的題目數量
                total_questions = 10  # 總共要獲取10題
                questions_per_knowledge = {}

                if request.user_id and knowledge_scores:
                    # 計算每個知識點的反向權重（分數越低，權重越高）
                    inverse_weights = {}
                    total_inverse_weight = 0
                    
                    for knowledge_id in knowledge_ids:
                        # 獲取知識點分數，如果沒有記錄則默認為5
                        score = knowledge_scores.get(knowledge_id, 5)
                        # 使用反向分數作為權重（10-score），確保最小為1
                        inverse_weight = max(10 - score, 1)
                        inverse_weights[knowledge_id] = inverse_weight
                        total_inverse_weight += inverse_weight
                    
                    # 根據反向權重分配題目數量
                    remaining_questions = total_questions
                    for knowledge_id, inverse_weight in inverse_weights.items():
                        # 計算應分配的題目數量（至少1題）
                        question_count = max(1, int(round((inverse_weight / total_inverse_weight) * total_questions)))
                        # 確保不超過剩餘題目數
                        question_count = min(question_count, remaining_questions)
                        questions_per_knowledge[knowledge_id] = question_count
                        remaining_questions -= question_count
                    
                    # 如果還有剩餘題目，分配給分數最低的知識點
                    if remaining_questions > 0:
                        lowest_score_id = min(knowledge_scores.items(), key=lambda x: x[1])[0]
                        questions_per_knowledge[lowest_score_id] += remaining_questions
                else:
                    # 如果沒有用戶ID或分數記錄，平均分配題目
                    base_count = total_questions // len(knowledge_ids) if knowledge_ids else 0
                    remainder = total_questions % len(knowledge_ids) if knowledge_ids else 0
                    
                    for i, knowledge_id in enumerate(knowledge_ids):
                        questions_per_knowledge[knowledge_id] = base_count + (1 if i < remainder else 0)
                
                # 打印分配結果
                print(f"知識點分數: {knowledge_scores}")
                print(f"題目分配: {questions_per_knowledge}")
                
                # 構建查詢條件
                conditions = []
                params = []
                
                if request.chapter:
                    conditions.append("cl.chapter_name = %s")
                    params.append(request.chapter)
                
                if request.section:
                    conditions.append("kp.section_name = %s")
                    params.append(request.section)
                
                # 獲取所有題目
                all_questions = []
                
                # 為每個知識點獲取指定數量的題目
                for knowledge_id, question_count in questions_per_knowledge.items():
                    if question_count <= 0:
                        continue
                        
                    # 構建查詢
                    knowledge_conditions = conditions.copy()
                    knowledge_params = params.copy()
                    
                    knowledge_conditions.append("q.knowledge_id = %s")
                    knowledge_params.append(knowledge_id)
                    
                    # 組合 WHERE 子句
                    where_clause = " AND ".join(knowledge_conditions) if knowledge_conditions else "1=1"
                    
                    # 查詢題目，排除有錯誤訊息的題目
                    sql = f"""
                    SELECT q.id, q.knowledge_id, q.question_text, q.option_1, q.option_2, q.option_3, q.option_4, q.correct_answer, q.explanation, kp.point_name as knowledge_point
                    FROM questions q
                    JOIN knowledge_points kp ON q.knowledge_id = kp.id
                    JOIN chapter_list cl ON kp.chapter_id = cl.id
                    WHERE {where_clause} AND (q.Error_message IS NULL OR q.Error_message = '')
                    ORDER BY RAND()
                    LIMIT {question_count}
                    """
                    
                    print(f"執行的 SQL: {sql}")
                    print(f"SQL 參數: {knowledge_params}")
                    
                    cursor.execute(sql, knowledge_params)
                    knowledge_questions = cursor.fetchall()
                    all_questions.extend(knowledge_questions)
                
                # 如果獲取的題目不足10題，從所有相關知識點中隨機補充
                if len(all_questions) < total_questions:
                    remaining_count = total_questions - len(all_questions)
                    
                    # 已獲取的題目ID列表
                    existing_ids = [q['id'] for q in all_questions]
                    id_placeholders = ', '.join(['%s'] * len(existing_ids)) if existing_ids else '0'
                    
                    # 構建知識點條件
                    kp_placeholders = ', '.join(['%s'] * len(knowledge_ids)) if knowledge_ids else '0'
                    
                    # 查詢補充題目
                    supplement_sql = f"""
                    SELECT q.id, q.knowledge_id, q.question_text, q.option_1, q.option_2, q.option_3, q.option_4, q.correct_answer, q.explanation, kp.point_name as knowledge_point
                    FROM questions q
                    JOIN knowledge_points kp ON q.knowledge_id = kp.id
                    JOIN chapter_list cl ON kp.chapter_id = cl.id
                    WHERE q.knowledge_id IN ({kp_placeholders})
                    AND q.id NOT IN ({id_placeholders})
                    AND (q.Error_message IS NULL OR q.Error_message = '')
                    ORDER BY RAND()
                    LIMIT {remaining_count}
                    """
                    
                    supplement_params = knowledge_ids + existing_ids
                    
                    print(f"執行補充 SQL: {supplement_sql}")
                    print(f"補充 SQL 參數: {supplement_params}")
                    
                    cursor.execute(supplement_sql, supplement_params)
                    supplement_questions = cursor.fetchall()
                    all_questions.extend(supplement_questions)
                
                # 將結果轉換為 JSON 格式
                result = []
                for q in all_questions:
                    # 直接使用查詢中獲取的知識點名稱
                    knowledge_point = q['knowledge_point'] if q['knowledge_point'] else ""
                    
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
                        "knowledge_point": knowledge_point,  # 添加知識點信息
                        "knowledge_id": q["knowledge_id"]  # 添加知識點ID
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
        
        if not request.user_id or not request.question_id:
            return RecordAnswerResponse(success=False, message="缺少必要參數")
        
        # 連接到資料庫
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
                    
                    print(f"更新現有記錄: id={record_id}, total_attempts={total_attempts}, correct_attempts={correct_attempts}")
                    
                    cursor.execute(
                        "UPDATE user_question_stats SET total_attempts = %s, correct_attempts = %s, last_attempted_at = %s WHERE id = %s",
                        (total_attempts, correct_attempts, current_time, record_id)
                    )
                else:
                    # 創建新記錄
                    print(f"創建新記錄: user_id={request.user_id}, question_id={request.question_id}, is_correct={request.is_correct}")
                    
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
        print(f"收到關卡完成請求: user_id={request.user_id}, level_id={request.level_id}, stars={request.stars}, ai_comment={request.ai_comment}")
        
        if not request.user_id or not request.level_id:
            print(f"缺少必要參數: user_id={request.user_id}, level_id={request.level_id}")
            return CompleteLevelResponse(success=False, message="缺少必要參數")
        
        connection = get_db_connection()
        connection.charset = 'utf8mb4'
        
        try:
            with connection.cursor() as cursor:
                # 設置連接的字符集
                cursor.execute("SET NAMES utf8mb4")
                cursor.execute("SET CHARACTER SET utf8mb4")
                cursor.execute("SET character_set_connection=utf8mb4")
                
                current_time = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                
                # 每次都創建新記錄，不檢查是否已存在
                insert_sql = """
                INSERT INTO user_level (user_id, level_id, stars, ai_comment, answered_at) 
                VALUES (%s, %s, %s, %s, %s)
                """
                cursor.execute(insert_sql, (request.user_id, request.level_id, request.stars, request.ai_comment, current_time))
                
                connection.commit()
                
                # 更新知識點分數
                # 從 level_info 表中獲取關卡對應的 chapter_id
                cursor.execute("""
                SELECT chapter_id FROM level_info WHERE id = %s
                """, (request.level_id,))
                level_result = cursor.fetchone()
                
                if not level_result:
                    return CompleteLevelResponse(success=True, message="關卡完成記錄已新增，但無法更新知識點分數")
                
                chapter_id = level_result['chapter_id']
                
                # 獲取該章節的所有知識點
                cursor.execute("""
                SELECT id, point_name FROM knowledge_points WHERE chapter_id = %s
                """, (chapter_id,))
                knowledge_points = cursor.fetchall()
                
                if not knowledge_points:
                    return CompleteLevelResponse(success=True, message="關卡完成記錄已新增，但該章節沒有知識點")
                
                knowledge_ids = [kp['id'] for kp in knowledge_points]
                
                # 更新這些知識點的分數
                updated_count = 0
                for knowledge_id in knowledge_ids:
                    # 獲取與該知識點相關的所有題目
                    cursor.execute("""
                    SELECT id 
                    FROM questions 
                    WHERE knowledge_id = %s
                    """, (knowledge_id,))
                    
                    questions = cursor.fetchall()
                    question_ids = [q['id'] for q in questions]
                    
                    if not question_ids:
                        continue
                    
                    # 獲取用戶對這些題目的答題記錄
                    placeholders = ', '.join(['%s'] * len(question_ids))
                    query = f"""
                    SELECT 
                        SUM(total_attempts) as total_attempts,
                        SUM(correct_attempts) as correct_attempts
                    FROM user_question_stats 
                    WHERE user_id = %s AND question_id IN ({placeholders})
                    """
                    
                    params = [request.user_id] + question_ids
                    cursor.execute(query, params)
                    stats = cursor.fetchone()
                    
                    # 計算分數
                    total_attempts = stats['total_attempts'] if stats and stats['total_attempts'] else 0
                    correct_attempts = stats['correct_attempts'] if stats and stats['correct_attempts'] else 0
                    
                    # 分數計算公式
                    if total_attempts == 0:
                        score = 0  # 沒有嘗試過，分數為 0
                    else:
                        # 使用正確率作為基礎分數
                        accuracy = correct_attempts / total_attempts
                        
                        # 根據嘗試次數給予額外加權（熟練度）
                        experience_factor = min(1, total_attempts / 10)  # 最多嘗試 10 次達到滿分加權
                        
                        # 最終分數 = 正確率 * 10 * 經驗係數
                        score = accuracy * 10 * experience_factor
                    
                    # 限制分數在 0-10 範圍內
                    score = min(max(score, 0), 10)
                    
                    # 更新知識點分數
                    cursor.execute("""
                    INSERT INTO user_knowledge_score (user_id, knowledge_id, score)
                    VALUES (%s, %s, %s)
                    ON DUPLICATE KEY UPDATE score = VALUES(score)
                    """, (request.user_id, knowledge_id, score))
                    
                    updated_count += 1
                
                connection.commit()
                
                return CompleteLevelResponse(success=True, message="關卡完成記錄已新增")
        
        finally:
            connection.close()
    
    except Exception as e:
        print(f"記錄關卡完成時出錯: {str(e)}")
        print(traceback.format_exc())
        return CompleteLevelResponse(
            success=False,
            message=f"記錄關卡完成時出錯: {str(e)}"
        )


@router.post("/report_error", response_model=StandardResponse)
async def report_question_error(request: Request):
    """回報題目錯誤"""
    try:
        data = await request.json()
        question_id = data.get("question_id")
        error_message = data.get("error_message")
        
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


@router.post("/user_level_stars", response_model=UserLevelStarsResponse)
async def get_user_level_stars(request: UserLevelStarsRequest):
    """獲取用戶關卡星星數"""
    try:
        print(f"收到獲取用戶星星數請求: user_id={request.user_id}, subject={request.subject}")
        
        if not request.user_id:
            print(f"錯誤: 缺少用戶 ID")
            return UserLevelStarsResponse(success=False, message="缺少用戶 ID")
        
        connection = get_db_connection()
        connection.charset = 'utf8mb4'
        
        try:
            with connection.cursor() as cursor:
                # 設置連接的字符集
                cursor.execute("SET NAMES utf8mb4")
                cursor.execute("SET CHARACTER SET utf8mb4")
                cursor.execute("SET character_set_connection=utf8mb4")
                
                # 構建查詢條件
                query = """
                SELECT ul.level_id, MAX(ul.stars) as stars
                FROM user_level ul
                """
                
                params = [request.user_id]
                
                # 如果提供了科目，則加入科目過濾條件
                if request.subject:
                    print(f"科目: {request.subject}")
                    query += """
                    JOIN level_info li ON ul.level_id = li.id
                    JOIN chapter_list cl ON li.chapter_id = cl.id
                    WHERE ul.user_id = %s AND cl.subject = %s
                    """
                    params.append(request.subject)
                else:
                    query += "WHERE ul.user_id = %s"
                
                query += " GROUP BY ul.level_id"
                
                print(f"執行查詢: {query}")
                print(f"參數: {params}")
                
                cursor.execute(query, params)
                results = cursor.fetchall()
                
                # 將結果轉換為字典格式
                level_stars = {}
                for row in results:
                    level_stars[str(row['level_id'])] = row['stars']
                
                print(f"找到用戶 {request.user_id} 的星星數記錄: {len(level_stars)} 個關卡")
                
                return UserLevelStarsResponse(
                    success=True,
                    level_stars=level_stars
                )
        
        finally:
            connection.close()
            print(f"資料庫連接已關閉")
    
    except Exception as e:
        print(f"獲取用戶星星數時出錯: {str(e)}")
        print(traceback.format_exc())
        return UserLevelStarsResponse(success=False, message=f"獲取用戶星星數時出錯: {str(e)}")
