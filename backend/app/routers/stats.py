"""
統計分析相關 API
"""
from fastapi import APIRouter, HTTPException, Body
from ..database import get_db_connection
from ..models import UserStatsRequest, MonthlyProgressRequest, SubjectAbilitiesRequest, LearningDaysResponse, StandardResponse
from typing import Dict, Any, List
import traceback
from datetime import datetime, timedelta

router = APIRouter(prefix="/stats", tags=["Statistics"])


@router.get("/weekly/{user_id}", response_model=Dict[str, Any])
async def get_weekly_stats(user_id: str):
    """取得用戶本週統計"""
    try:
        connection = get_db_connection()
        with connection.cursor() as cursor:
            # 計算本週範圍
            today = datetime.now()
            start_of_week = today - timedelta(days=today.weekday())
            end_of_week = start_of_week + timedelta(days=6)
            
            # 獲取本週答題統計
            sql = """
            SELECT 
                COUNT(*) as total_questions,
                SUM(CASE WHEN is_correct = 1 THEN 1 ELSE 0 END) as correct_answers,
                COUNT(DISTINCT subject) as subjects_practiced,
                COUNT(DISTINCT DATE(answered_at)) as active_days
            FROM user_answers 
            WHERE user_id = %s 
            AND answered_at BETWEEN %s AND %s
            """
            cursor.execute(sql, (user_id, start_of_week.strftime('%Y-%m-%d'), 
                                end_of_week.strftime('%Y-%m-%d')))
            weekly_stats = cursor.fetchone()
            
            # 計算正確率
            accuracy = 0
            if weekly_stats['total_questions'] > 0:
                accuracy = (weekly_stats['correct_answers'] / weekly_stats['total_questions']) * 100
            
            # 獲取每日統計
            sql = """
            SELECT 
                DATE(answered_at) as date,
                COUNT(*) as questions_count,
                SUM(CASE WHEN is_correct = 1 THEN 1 ELSE 0 END) as correct_count
            FROM user_answers 
            WHERE user_id = %s 
            AND answered_at BETWEEN %s AND %s
            GROUP BY DATE(answered_at)
            ORDER BY date
            """
            cursor.execute(sql, (user_id, start_of_week.strftime('%Y-%m-%d'), 
                                end_of_week.strftime('%Y-%m-%d')))
            daily_stats = cursor.fetchall()
            
            return {
                "weekly_summary": {
                    "total_questions": weekly_stats['total_questions'],
                    "correct_answers": weekly_stats['correct_answers'], 
                    "accuracy": round(accuracy, 2),
                    "subjects_practiced": weekly_stats['subjects_practiced'],
                    "active_days": weekly_stats['active_days']
                },
                "daily_breakdown": daily_stats
            }
    
    except Exception as e:
        print(f"[get_weekly_stats] Error: {e}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    finally:
        if 'connection' in locals():
            connection.close()


@router.get("/learning_suggestions/{user_id}", response_model=Dict[str, Any])
async def get_learning_suggestions(user_id: str):
    """取得學習建議"""
    try:
        connection = get_db_connection()
        with connection.cursor() as cursor:
            # 分析用戶弱點
            sql = """
            SELECT 
                subject,
                chapter,
                knowledge_point,
                COUNT(*) as total_attempts,
                SUM(CASE WHEN is_correct = 1 THEN 1 ELSE 0 END) as correct_attempts,
                (SUM(CASE WHEN is_correct = 1 THEN 1 ELSE 0 END) / COUNT(*)) * 100 as accuracy
            FROM user_answers 
            WHERE user_id = %s 
            AND answered_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
            GROUP BY subject, chapter, knowledge_point
            HAVING total_attempts >= 3 AND accuracy < 70
            ORDER BY accuracy ASC, total_attempts DESC
            LIMIT 5
            """
            cursor.execute(sql, (user_id,))
            weak_areas = cursor.fetchall()
            
            # 推薦練習內容
            suggestions = []
            for area in weak_areas:
                suggestions.append({
                    "type": "practice_more",
                    "subject": area['subject'],
                    "chapter": area['chapter'],
                    "knowledge_point": area['knowledge_point'],
                    "reason": f"正確率僅 {area['accuracy']:.1f}%，建議加強練習",
                    "priority": "high" if area['accuracy'] < 50 else "medium"
                })
            
            # 獲取最近學習趨勢
            sql = """
            SELECT DATE(answered_at) as date, COUNT(*) as question_count
            FROM user_answers 
            WHERE user_id = %s 
            AND answered_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
            GROUP BY DATE(answered_at)
            ORDER BY date DESC
            """
            cursor.execute(sql, (user_id,))
            recent_activity = cursor.fetchall()
            
            # 分析學習習慣
            if len(recent_activity) < 3:
                suggestions.append({
                    "type": "increase_frequency",
                    "reason": "最近學習頻率較低，建議保持每日練習",
                    "priority": "medium"
                })
            
            return {
                "weak_areas": weak_areas,
                "suggestions": suggestions,
                "recent_activity": recent_activity
            }
    
    except Exception as e:
        print(f"[get_learning_suggestions] Error: {e}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    finally:
        if 'connection' in locals():
            connection.close()


@router.post("/user_stats", response_model=Dict[str, Any])
async def get_user_stats(request: UserStatsRequest):
    """取得用戶統計數據"""
    try:
        connection = get_db_connection()
        with connection.cursor() as cursor:
            # 根據時間範圍計算統計
            time_filter = ""
            if request.time_range == "week":
                time_filter = "AND answered_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)"
            elif request.time_range == "month":
                time_filter = "AND answered_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)"
            elif request.time_range == "year":
                time_filter = "AND answered_at >= DATE_SUB(NOW(), INTERVAL 365 DAY)"
            
            # 總體統計
            sql = f"""
            SELECT 
                COUNT(*) as total_questions,
                SUM(CASE WHEN is_correct = 1 THEN 1 ELSE 0 END) as correct_answers,
                COUNT(DISTINCT subject) as subjects_count,
                COUNT(DISTINCT chapter) as chapters_count,
                COUNT(DISTINCT DATE(answered_at)) as study_days
            FROM user_answers 
            WHERE user_id = %s {time_filter}
            """
            cursor.execute(sql, (request.user_id,))
            overall_stats = cursor.fetchone()
            
            # 各科目統計
            sql = f"""
            SELECT 
                subject,
                COUNT(*) as total_questions,
                SUM(CASE WHEN is_correct = 1 THEN 1 ELSE 0 END) as correct_answers,
                ROUND((SUM(CASE WHEN is_correct = 1 THEN 1 ELSE 0 END) / COUNT(*)) * 100, 2) as accuracy
            FROM user_answers 
            WHERE user_id = %s {time_filter}
            GROUP BY subject
            ORDER BY total_questions DESC
            """
            cursor.execute(sql, (request.user_id,))
            subject_stats = cursor.fetchall()
            
            # 計算總正確率
            accuracy = 0
            if overall_stats['total_questions'] > 0:
                accuracy = (overall_stats['correct_answers'] / overall_stats['total_questions']) * 100
            
            return {
                "overall": {
                    **overall_stats,
                    "accuracy": round(accuracy, 2)
                },
                "by_subject": subject_stats,
                "time_range": request.time_range
            }
    
    except Exception as e:
        print(f"[get_user_stats] Error: {e}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    finally:
        if 'connection' in locals():
            connection.close()


@router.get("/learning_days/{user_id}", response_model=LearningDaysResponse)
async def get_learning_days(user_id: str):
    """取得學習天數統計"""
    try:
        connection = get_db_connection()
        with connection.cursor() as cursor:
            # 計算總學習天數
            sql = """
            SELECT COUNT(DISTINCT DATE(answered_at)) as learning_days
            FROM user_answers 
            WHERE user_id = %s
            """
            cursor.execute(sql, (user_id,))
            result = cursor.fetchone()
            learning_days = result['learning_days'] if result else 0
            
            # 計算連續學習天數
            sql = """
            SELECT DISTINCT DATE(answered_at) as study_date
            FROM user_answers 
            WHERE user_id = %s
            ORDER BY study_date DESC
            """
            cursor.execute(sql, (user_id,))
            study_dates = cursor.fetchall()
            
            streak_days = 0
            if study_dates:
                current_date = datetime.now().date()
                for i, record in enumerate(study_dates):
                    expected_date = current_date - timedelta(days=i)
                    if record['study_date'] == expected_date:
                        streak_days += 1
                    else:
                        break
            
            return LearningDaysResponse(
                learning_days=learning_days,
                streak_days=streak_days
            )
    
    except Exception as e:
        print(f"[get_learning_days] Error: {e}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    finally:
        if 'connection' in locals():
            connection.close()


@router.post("/monthly_progress", response_model=Dict[str, Any])
async def get_monthly_subject_progress(request: MonthlyProgressRequest):
    """取得月度科目進度"""
    try:
        connection = get_db_connection()
        with connection.cursor() as cursor:
            # 計算指定月份的範圍
            start_date = f"{request.year}-{request.month:02d}-01"
            if request.month == 12:
                end_date = f"{request.year + 1}-01-01"
            else:
                end_date = f"{request.year}-{request.month + 1:02d}-01"
            
            sql = """
            SELECT 
                subject,
                COUNT(*) as questions_answered,
                SUM(CASE WHEN is_correct = 1 THEN 1 ELSE 0 END) as correct_answers,
                ROUND((SUM(CASE WHEN is_correct = 1 THEN 1 ELSE 0 END) / COUNT(*)) * 100, 2) as accuracy,
                COUNT(DISTINCT chapter) as chapters_practiced
            FROM user_answers 
            WHERE user_id = %s 
            AND answered_at >= %s 
            AND answered_at < %s
            GROUP BY subject
            ORDER BY questions_answered DESC
            """
            cursor.execute(sql, (request.user_id, start_date, end_date))
            monthly_progress = cursor.fetchall()
            
            return {
                "year": request.year,
                "month": request.month,
                "progress": monthly_progress
            }
    
    except Exception as e:
        print(f"[get_monthly_subject_progress] Error: {e}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    finally:
        if 'connection' in locals():
            connection.close()


@router.post("/subject_abilities", response_model=Dict[str, Any])
async def get_subject_abilities(request: SubjectAbilitiesRequest):
    """取得各科目能力分析"""
    try:
        connection = get_db_connection()
        with connection.cursor() as cursor:
            sql = """
            SELECT 
                subject,
                chapter,
                AVG(CASE WHEN is_correct = 1 THEN 100 ELSE 0 END) as avg_score,
                COUNT(*) as total_attempts,
                SUM(CASE WHEN is_correct = 1 THEN 1 ELSE 0 END) as correct_attempts,
                MAX(answered_at) as last_practiced
            FROM user_answers 
            WHERE user_id = %s 
            GROUP BY subject, chapter
            ORDER BY subject, avg_score DESC
            """
            cursor.execute(sql, (request.user_id,))
            chapter_abilities = cursor.fetchall()
            
            # 按科目分組
            subject_abilities = {}
            for record in chapter_abilities:
                subject = record['subject']
                if subject not in subject_abilities:
                    subject_abilities[subject] = {
                        'chapters': [],
                        'overall_score': 0,
                        'total_questions': 0,
                        'total_correct': 0
                    }
                
                subject_abilities[subject]['chapters'].append({
                    'chapter': record['chapter'],
                    'score': round(record['avg_score'], 1),
                    'attempts': record['total_attempts'],
                    'correct': record['correct_attempts'],
                    'last_practiced': record['last_practiced'].strftime('%Y-%m-%d') if record['last_practiced'] else None
                })
                
                subject_abilities[subject]['total_questions'] += record['total_attempts']
                subject_abilities[subject]['total_correct'] += record['correct_attempts']
            
            # 計算各科目總體分數
            for subject in subject_abilities:
                data = subject_abilities[subject]
                if data['total_questions'] > 0:
                    data['overall_score'] = round((data['total_correct'] / data['total_questions']) * 100, 1)
            
            return {"abilities": subject_abilities}
    
    except Exception as e:
        print(f"[get_subject_abilities] Error: {e}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    finally:
        if 'connection' in locals():
            connection.close()
