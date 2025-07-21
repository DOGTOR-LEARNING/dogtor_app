"""
對戰模式路由
"""
from fastapi import APIRouter, HTTPException
from app.models import (
    StartBattleRequest, 
    BattleResponse,
    BattleQuestionRequest,
    BattleAnswerRequest,
    BattleResultRequest,
    BattleResultResponse,
    StandardResponse
)
from datetime import datetime
import pymysql
import os
import json
import random
import uuid
from typing import Dict, List, Any

router = APIRouter(prefix="/battle", tags=["對戰模式"])

# 內存中存儲對戰房間（生產環境建議使用 Redis）
battle_rooms: Dict[str, Dict[str, Any]] = {}

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

def get_random_chapter(subject: str):
    """隨機選擇章節"""
    chapters_by_subject = {
        "數學": ["一次函數", "二次函數", "三角函數", "指數對數", "數列級數"],
        "物理": ["力學", "熱力學", "光學", "電磁學", "原子物理"],
        "化學": ["原子結構", "化學鍵", "反應動力學", "有機化學", "無機化學"],
        "生物": ["細胞生物學", "遺傳學", "生態學", "演化論", "分子生物學"]
    }
    
    available_chapters = chapters_by_subject.get(subject, ["基礎概念"])
    return random.choice(available_chapters)

@router.post("/start", response_model=BattleResponse)
async def start_battle(request: StartBattleRequest):
    """發起對戰"""
    try:
        # 生成對戰 ID
        battle_id = str(uuid.uuid4())
        
        # 如果章節為空或是"隨機"，則隨機選擇
        chapter = request.chapter
        if not chapter or chapter == "隨機":
            chapter = get_random_chapter(request.subject)
        
        # 創建對戰房間
        battle_rooms[battle_id] = {
            "battle_id": battle_id,
            "challenger_id": request.challenger_id,
            "opponent_id": request.opponent_id,
            "chapter": chapter,
            "subject": request.subject,
            "status": "waiting_for_opponent",  # waiting_for_opponent, active, finished
            "created_at": datetime.now().isoformat(),
            "questions": [],
            "current_question": 0,
            "challenger_score": 0,
            "opponent_score": 0,
            "challenger_answers": {},
            "opponent_answers": {},
            "start_time": None
        }
        
        # 獲取該章節的題目
        questions = await get_battle_questions(request.subject, chapter)
        battle_rooms[battle_id]["questions"] = questions
        
        return BattleResponse(
            success=True,
            battle_id=battle_id,
            message=f"對戰房間已建立，章節：{chapter}"
        )
        
    except Exception as e:
        print(f"發起對戰錯誤: {e}")
        raise HTTPException(status_code=500, detail="發起對戰失敗")

async def get_battle_questions(subject: str, chapter: str, limit: int = 5):
    """獲取對戰題目"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor(pymysql.cursors.DictCursor)
        
        # 從資料庫隨機選擇5道題目
        query = """
        SELECT id, question_text as question, options, correct_answer, explanation
        FROM questions 
        WHERE (chapter LIKE %s OR subject LIKE %s) 
        AND options IS NOT NULL
        ORDER BY RAND()
        LIMIT %s
        """
        
        cursor.execute(query, (f"%{chapter}%", f"%{subject}%", limit))
        questions = cursor.fetchall()
        
        # 處理選項格式
        for question in questions:
            if isinstance(question['options'], str):
                try:
                    question['options'] = json.loads(question['options'])
                except:
                    # 如果 JSON 解析失敗，嘗試從舊的 option_1-4 欄位構建
                    cursor.execute("""
                        SELECT option_1, option_2, option_3, option_4 
                        FROM questions WHERE id = %s
                    """, (question['id'],))
                    old_options = cursor.fetchone()
                    if old_options:
                        question['options'] = [
                            old_options['option_1'] or '',
                            old_options['option_2'] or '',
                            old_options['option_3'] or '',
                            old_options['option_4'] or ''
                        ]
                    else:
                        question['options'] = ['選項A', '選項B', '選項C', '選項D']
        
        cursor.close()
        conn.close()
        
        return questions
        
    except Exception as e:
        print(f"獲取對戰題目錯誤: {e}")
        return []

@router.get("/room/{battle_id}")
async def get_battle_room(battle_id: str):
    """獲取對戰房間信息"""
    try:
        if battle_id not in battle_rooms:
            raise HTTPException(status_code=404, detail="對戰房間不存在")
        
        room = battle_rooms[battle_id].copy()
        # 不返回完整的答案，只返回必要信息
        room.pop("challenger_answers", None)
        room.pop("opponent_answers", None)
        
        return {"success": True, "room": room}
        
    except Exception as e:
        print(f"獲取對戰房間錯誤: {e}")
        raise HTTPException(status_code=500, detail="獲取對戰房間失敗")

@router.post("/join/{battle_id}")
async def join_battle(battle_id: str, user_id: str):
    """加入對戰"""
    try:
        if battle_id not in battle_rooms:
            raise HTTPException(status_code=404, detail="對戰房間不存在")
        
        room = battle_rooms[battle_id]
        
        if room["opponent_id"] != user_id:
            raise HTTPException(status_code=403, detail="無權加入此對戰")
        
        # 更新房間狀態
        room["status"] = "active"
        room["start_time"] = datetime.now().isoformat()
        
        return {"success": True, "message": "成功加入對戰"}
        
    except Exception as e:
        print(f"加入對戰錯誤: {e}")
        raise HTTPException(status_code=500, detail="加入對戰失敗")

@router.get("/question/{battle_id}")
async def get_current_question(battle_id: str):
    """獲取當前題目"""
    try:
        if battle_id not in battle_rooms:
            raise HTTPException(status_code=404, detail="對戰房間不存在")
        
        room = battle_rooms[battle_id]
        current_idx = room["current_question"]
        
        if current_idx >= len(room["questions"]):
            return {"success": False, "message": "所有題目已完成"}
        
        question = room["questions"][current_idx].copy()
        # 移除正確答案，不發送給前端
        question.pop("correct_answer", None)
        question.pop("explanation", None)
        
        return {
            "success": True,
            "question": question,
            "question_number": current_idx + 1,
            "total_questions": len(room["questions"])
        }
        
    except Exception as e:
        print(f"獲取題目錯誤: {e}")
        raise HTTPException(status_code=500, detail="獲取題目失敗")

@router.post("/answer", response_model=StandardResponse)
async def submit_battle_answer(request: BattleAnswerRequest):
    """提交對戰答案"""
    try:
        if request.battle_id not in battle_rooms:
            raise HTTPException(status_code=404, detail="對戰房間不存在")
        
        room = battle_rooms[request.battle_id]
        current_idx = room["current_question"]
        
        if current_idx >= len(room["questions"]):
            raise HTTPException(status_code=400, detail="所有題目已完成")
        
        current_question = room["questions"][current_idx]
        correct_answer = current_question["correct_answer"]
        
        # 判斷答案是否正確
        is_correct = str(request.answer) == str(correct_answer)
        
        # 計算分數（越快答對分數越高）
        base_score = 100 if is_correct else 0
        time_bonus = max(0, 100 - int(request.answer_time * 10))  # 時間獎勵
        total_score = base_score + time_bonus if is_correct else 0
        
        # 記錄答案
        answer_data = {
            "question_id": request.question_id,
            "answer": request.answer,
            "is_correct": is_correct,
            "answer_time": request.answer_time,
            "score": total_score
        }
        
        if request.user_id == room["challenger_id"]:
            room["challenger_answers"][current_idx] = answer_data
            room["challenger_score"] += total_score
        elif request.user_id == room["opponent_id"]:
            room["opponent_answers"][current_idx] = answer_data
            room["opponent_score"] += total_score
        else:
            raise HTTPException(status_code=403, detail="無權參與此對戰")
        
        # 檢查是否兩人都已答題
        challenger_answered = current_idx in room["challenger_answers"]
        opponent_answered = current_idx in room["opponent_answers"]
        
        if challenger_answered and opponent_answered:
            # 兩人都答完，進入下一題
            room["current_question"] += 1
        
        return StandardResponse(
            success=True,
            message="答案提交成功",
            data={
                "is_correct": is_correct,
                "score": total_score,
                "next_question": room["current_question"] < len(room["questions"])
            }
        )
        
    except Exception as e:
        print(f"提交答案錯誤: {e}")
        raise HTTPException(status_code=500, detail="提交答案失敗")

@router.get("/result/{battle_id}", response_model=BattleResultResponse)
async def get_battle_result(battle_id: str):
    """獲取對戰結果"""
    try:
        if battle_id not in battle_rooms:
            raise HTTPException(status_code=404, detail="對戰房間不存在")
        
        room = battle_rooms[battle_id]
        
        # 標記對戰結束
        room["status"] = "finished"
        room["end_time"] = datetime.now().isoformat()
        
        # 計算獲勝者
        challenger_score = room["challenger_score"]
        opponent_score = room["opponent_score"]
        
        winner_id = None
        if challenger_score > opponent_score:
            winner_id = room["challenger_id"]
        elif opponent_score > challenger_score:
            winner_id = room["opponent_id"]
        # 平分則無獲勝者
        
        # 生成對戰摘要
        battle_summary = {
            "total_questions": len(room["questions"]),
            "challenger_correct": sum(1 for ans in room["challenger_answers"].values() if ans["is_correct"]),
            "opponent_correct": sum(1 for ans in room["opponent_answers"].values() if ans["is_correct"]),
            "battle_duration": 0,  # 可以根據需要計算
            "chapter": room["chapter"],
            "subject": room["subject"]
        }
        
        # 將結果保存到資料庫
        await save_battle_result(room)
        
        return BattleResultResponse(
            success=True,
            challenger_score=challenger_score,
            opponent_score=opponent_score,
            winner_id=winner_id,
            battle_summary=battle_summary
        )
        
    except Exception as e:
        print(f"獲取對戰結果錯誤: {e}")
        raise HTTPException(status_code=500, detail="獲取對戰結果失敗")

async def save_battle_result(room: Dict[str, Any]):
    """保存對戰結果到資料庫"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # 插入對戰記錄
        insert_query = """
        INSERT INTO battle_history 
        (battle_id, challenger_id, opponent_id, chapter, subject, 
         challenger_score, opponent_score, winner_id, battle_data, created_at)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """
        
        winner_id = None
        if room["challenger_score"] > room["opponent_score"]:
            winner_id = room["challenger_id"]
        elif room["opponent_score"] > room["challenger_score"]:
            winner_id = room["opponent_id"]
        
        cursor.execute(insert_query, (
            room["battle_id"],
            room["challenger_id"],
            room["opponent_id"],
            room["chapter"],
            room["subject"],
            room["challenger_score"],
            room["opponent_score"],
            winner_id,
            json.dumps(room, default=str),
            datetime.now()
        ))
        
        # 保存詳細答題記錄
        for idx, (challenger_ans, opponent_ans) in enumerate(zip(
            room.get("challenger_answers", {}).values(),
            room.get("opponent_answers", {}).values()
        )):
            # 保存挑戰者答題記錄
            cursor.execute("""
                INSERT INTO battle_answers 
                (battle_id, user_id, question_id, question_order, user_answer, 
                 correct_answer, is_correct, answer_time, score)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            """, (
                room["battle_id"], room["challenger_id"], challenger_ans["question_id"],
                idx + 1, challenger_ans["answer"], challenger_ans.get("correct_answer", ""),
                challenger_ans["is_correct"], challenger_ans["answer_time"], challenger_ans["score"]
            ))
            
            # 保存對手答題記錄
            cursor.execute("""
                INSERT INTO battle_answers 
                (battle_id, user_id, question_id, question_order, user_answer, 
                 correct_answer, is_correct, answer_time, score)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            """, (
                room["battle_id"], room["opponent_id"], opponent_ans["question_id"],
                idx + 1, opponent_ans["answer"], opponent_ans.get("correct_answer", ""),
                opponent_ans["is_correct"], opponent_ans["answer_time"], opponent_ans["score"]
            ))
        
        conn.commit()
        cursor.close()
        conn.close()
        
    except Exception as e:
        print(f"保存對戰結果錯誤: {e}")

@router.delete("/room/{battle_id}")
async def cleanup_battle_room(battle_id: str):
    """清理對戰房間"""
    try:
        if battle_id in battle_rooms:
            del battle_rooms[battle_id]
        
        return {"success": True, "message": "對戰房間已清理"}
        
    except Exception as e:
        print(f"清理對戰房間錯誤: {e}")
        raise HTTPException(status_code=500, detail="清理對戰房間失敗")
