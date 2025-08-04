"""
統計分析相關 API
"""
from fastapi import APIRouter, HTTPException, Body
from database import get_db_connection
from models import UserStatsRequest, MonthlyProgressRequest, SubjectAbilitiesRequest, LearningDaysResponse, StandardResponse
from typing import Dict, Any, List
import traceback
from datetime import datetime, timedelta

router = APIRouter(prefix="/stats", tags=["Statistics"])


@router.get("/weekly/{user_id}", response_model=Dict[str, Any])
async def get_weekly_stats(user_id: str):
    """取得用戶本週統計 - 基於關卡完成記錄"""
    try:
        connection = get_db_connection()
        with connection.cursor() as cursor:
            # 計算本週範圍
            today = datetime.now()
            start_of_week = today - timedelta(days=today.weekday())
            end_of_week = start_of_week + timedelta(days=6)
            
            # 獲取本週關卡完成統計
            sql = """
            SELECT 
                COUNT(*) as total_levels,
                AVG(stars) as avg_stars,
                COUNT(DISTINCT DATE(answered_at)) as active_days
            FROM user_level 
            WHERE user_id = %s 
            AND answered_at BETWEEN %s AND %s
            """
            cursor.execute(sql, (user_id, start_of_week.strftime('%Y-%m-%d'), 
                                end_of_week.strftime('%Y-%m-%d')))
            weekly_stats = cursor.fetchone()
            
            # 獲取每日關卡完成統計 (過去7天)
            sql = """
            SELECT 
                DATE(answered_at) as date,
                COUNT(*) as levels
            FROM user_level 
            WHERE user_id = %s 
            AND answered_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
            GROUP BY DATE(answered_at)
            ORDER BY date DESC
            """
            cursor.execute(sql, (user_id,))
            daily_stats = cursor.fetchall()
            
            # 計算連續學習天數
            sql = """
            SELECT COUNT(DISTINCT DATE(answered_at)) as streak
            FROM user_level 
            WHERE user_id = %s 
            AND answered_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
            """
            cursor.execute(sql, (user_id,))
            streak_result = cursor.fetchone()
            
            return {
                "success": True,
                "weekly_stats": {
                    "this_week": daily_stats,
                    "last_week": []  # 暫時不計算上週數據
                },
                "streak": streak_result['streak'] if streak_result else 0,
                "total_levels": weekly_stats['total_levels'] if weekly_stats else 0,
                "avg_stars": round(weekly_stats['avg_stars'], 2) if weekly_stats and weekly_stats['avg_stars'] else 0,
                "active_days": weekly_stats['active_days'] if weekly_stats else 0
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
    """取得學習建議 - 基於知識點分數"""
    try:
        connection = get_db_connection()
        with connection.cursor() as cursor:
            # 獲取用戶弱點知識點 (分數低於5分的)
            sql = """
            SELECT 
                uks.score,
                kp.point_name,
                kp.section_name,
                cl.subject,
                cl.chapter_name
            FROM user_knowledge_score uks
            JOIN knowledge_points kp ON uks.knowledge_id = kp.id
            JOIN chapter_list cl ON kp.chapter_id = cl.id
            WHERE uks.user_id = %s 
            AND uks.score < 5 
            AND uks.score > 0
            ORDER BY uks.score ASC
            LIMIT 10
            """
            cursor.execute(sql, (user_id,))
            weak_points = cursor.fetchall()
            
            # 生成學習建議
            suggestions = []
            if weak_points:
                for point in weak_points[:3]:
                    suggestions.append({
                        "type": "improve_knowledge",
                        "subject": point['subject'],
                        "chapter": point['chapter_name'],
                        "knowledge_point": point['point_name'],
                        "reason": f"知識點分數較低 ({point['score']:.1f}/10)，建議加強練習",
                        "priority": "high" if point['score'] < 3 else "medium"
                    })
            
            # 檢查最近學習活動
            sql = """
            SELECT COUNT(DISTINCT DATE(answered_at)) as recent_days
            FROM user_level 
            WHERE user_id = %s 
            AND answered_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
            """
            cursor.execute(sql, (user_id,))
            recent_activity = cursor.fetchone()
            
            if recent_activity and recent_activity['recent_days'] < 3:
                suggestions.append({
                    "type": "increase_frequency",
                    "reason": "最近學習頻率較低，建議保持每日練習",
                    "priority": "medium"
                })
            
            return {
                "success": True,
                "weak_points": weak_points,
                "suggestions": suggestions,
                "recommended_chapters": []  # 可以根據需要添加推薦章節邏輯
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
    """取得用戶統計數據 - 基於關卡完成記錄"""
    try:
        connection = get_db_connection()
        with connection.cursor() as cursor:
            user_id = request.user_id
            
            # 獲取總關卡完成數和平均星數
            sql = """
            SELECT 
                COUNT(*) as total_levels,
                AVG(stars) as avg_stars,
                COUNT(CASE WHEN DATE(answered_at) = CURDATE() THEN 1 END) as today_levels
            FROM user_level 
            WHERE user_id = %s
            """
            cursor.execute(sql, (user_id,))
            basic_stats = cursor.fetchone()
            
            # 獲取各科目完成關卡數
            sql = """
            SELECT 
                cl.subject,
                COUNT(*) as level_count
            FROM user_level ul
            JOIN level_info li ON ul.level_id = li.id
            JOIN chapter_list cl ON li.chapter_id = cl.id
            WHERE ul.user_id = %s
            GROUP BY cl.subject
            ORDER BY level_count DESC
            """
            cursor.execute(sql, (user_id,))
            subject_levels = cursor.fetchall()
            
            # 獲取今日各科目完成關卡數
            sql = """
            SELECT 
                cl.subject,
                COUNT(*) as level_count
            FROM user_level ul
            JOIN level_info li ON ul.level_id = li.id
            JOIN chapter_list cl ON li.chapter_id = cl.id
            WHERE ul.user_id = %s
            AND DATE(ul.answered_at) = CURDATE()
            GROUP BY cl.subject
            ORDER BY level_count DESC
            """
            cursor.execute(sql, (user_id,))
            today_subject_levels = cursor.fetchall()
            
            # 獲取最近完成的關卡
            sql = """
            SELECT 
                cl.subject,
                cl.chapter_name,
                ul.stars,
                ul.answered_at
            FROM user_level ul
            JOIN level_info li ON ul.level_id = li.id
            JOIN chapter_list cl ON li.chapter_id = cl.id
            WHERE ul.user_id = %s
            ORDER BY ul.answered_at DESC
            LIMIT 10
            """
            cursor.execute(sql, (user_id,))
            recent_levels = cursor.fetchall()
            
            # 計算整體準確率 (基於平均星數)
            accuracy = 0
            if basic_stats and basic_stats['avg_stars']:
                accuracy = round((basic_stats['avg_stars'] / 3) * 100, 1)
            
            return {
                "success": True,
                "stats": {
                    "total_levels": basic_stats['total_levels'] if basic_stats else 0,
                    "today_levels": basic_stats['today_levels'] if basic_stats else 0,
                    "accuracy": accuracy,
                    "avg_stars": round(basic_stats['avg_stars'], 2) if basic_stats and basic_stats['avg_stars'] else 0,
                    "subject_levels": subject_levels,
                    "today_subject_levels": today_subject_levels,
                    "recent_levels": recent_levels
                }
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
    """取得學習天數統計 - 基於關卡完成記錄"""
    try:
        connection = get_db_connection()
        with connection.cursor() as cursor:
            # 獲取當前連續學習天數
            sql = """
            SELECT 
                COUNT(DISTINCT DATE(answered_at)) as current_streak
            FROM user_level 
            WHERE user_id = %s 
            AND answered_at >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
            """
            cursor.execute(sql, (user_id,))
            current_result = cursor.fetchone()
            
            # 獲取總學習天數
            sql = """
            SELECT 
                COUNT(DISTINCT DATE(answered_at)) as total_days
            FROM user_level 
            WHERE user_id = %s
            """
            cursor.execute(sql, (user_id,))
            total_result = cursor.fetchone()
            
            current_streak = current_result['current_streak'] if current_result else 0
            total_streak = total_result['total_days'] if total_result else 0
            
            return LearningDaysResponse(
                success=True,
                current_streak=current_streak,
                total_streak=total_streak,
                message="學習天數統計獲取成功"
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
    """取得本月科目進度 - 基於關卡完成記錄"""
    try:
        connection = get_db_connection()
        with connection.cursor() as cursor:
            user_id = request.user_id
            
            # 獲取本月各科目完成關卡數
            sql = """
            SELECT 
                cl.subject,
                COUNT(*) as level_count,
                AVG(ul.stars) as avg_stars
            FROM user_level ul
            JOIN level_info li ON ul.level_id = li.id
            JOIN chapter_list cl ON li.chapter_id = cl.id
            WHERE ul.user_id = %s
            AND YEAR(ul.answered_at) = YEAR(CURDATE())
            AND MONTH(ul.answered_at) = MONTH(CURDATE())
            GROUP BY cl.subject
            ORDER BY level_count DESC
            """
            cursor.execute(sql, (user_id,))
            monthly_subjects = cursor.fetchall()
            
            # 獲取月份資訊
            now = datetime.now()
            month_info = {
                "year": now.year,
                "month": now.month,
                "month_name": now.strftime("%B")
            }
            
            return {
                "success": True,
                "monthly_subjects": monthly_subjects,
                "month_info": month_info
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
    """取得科目能力統計 - 基於知識點分數"""
    try:
        connection = get_db_connection()
        with connection.cursor() as cursor:
            user_id = request.user_id
            
            # 獲取各科目的知識點平均分數
            sql = """
            SELECT 
                cl.subject,
                COUNT(uks.knowledge_id) as total_knowledge_points,
                AVG(uks.score) as ability_score,
                COUNT(CASE WHEN uks.score >= 7 THEN 1 END) as good_points,
                COUNT(CASE WHEN uks.score < 5 THEN 1 END) as weak_points
            FROM user_knowledge_score uks
            JOIN knowledge_points kp ON uks.knowledge_id = kp.id
            JOIN chapter_list cl ON kp.chapter_id = cl.id
            WHERE uks.user_id = %s
            AND uks.score > 0
            GROUP BY cl.subject
            ORDER BY ability_score DESC
            """
            cursor.execute(sql, (user_id,))
            subject_abilities = cursor.fetchall()
            
            # 轉換格式以符合前端期望
            formatted_abilities = []
            for ability in subject_abilities:
                formatted_abilities.append({
                    "subject": ability['subject'],
                    "total_attempts": ability['total_knowledge_points'],
                    "correct_attempts": ability['good_points'],
                    "ability_score": round(ability['ability_score'], 1) if ability['ability_score'] else 0
                })
            
            return {
                "success": True,
                "subject_abilities": formatted_abilities
            }
            
    except Exception as e:
        print(f"[get_subject_abilities] Error: {e}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    
    finally:
        if 'connection' in locals():
            connection.close()


# 知識點分數相關 API (這個 API 在其他地方被使用)
@router.get("/get_knowledge_scores/{user_id}", response_model=Dict[str, Any])
async def get_knowledge_scores(user_id: str):
    """取得用戶知識點分數"""
    try:
        connection = get_db_connection()
        with connection.cursor() as cursor:
            sql = """
            SELECT 
                uks.score,
                kp.point_name,
                kp.section_name,
                cl.subject,
                cl.chapter_name
            FROM user_knowledge_score uks
            JOIN knowledge_points kp ON uks.knowledge_id = kp.id
            JOIN chapter_list cl ON kp.chapter_id = cl.id
            WHERE uks.user_id = %s
            AND uks.score > 0
            ORDER BY uks.score ASC
            """
            cursor.execute(sql, (user_id,))
            scores = cursor.fetchall()
            
            return {
                "success": True,
                "scores": scores
            }
            
    except Exception as e:
        print(f"[get_knowledge_scores] Error: {e}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    
    finally:
        if 'connection' in locals():
            connection.close()
