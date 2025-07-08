from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List
import pymysql
import pandas as pd
from sklearn.preprocessing import LabelEncoder
import numpy as np

router = APIRouter()

class LearningCurveRequest(BaseModel):
    user_id: str

@router.post("/predict_learning_curve")
async def predict_learning_curve(data: LearningCurveRequest):
    user_id = data.user_id

    try:
        connection = get_db_connection()
        with connection.cursor() as cursor:
            cursor.execute("""
                SELECT uqs.user_id, uqs.question_id, q.knowledge_id,
                       uqs.total_attempts, uqs.correct_attempts,
                       uqs.last_attempted_at,
                       IF(uqs.correct_attempts > 0, 1, 0) AS is_correct
                FROM user_question_stats uqs
                JOIN questions q ON uqs.question_id = q.id
                WHERE uqs.user_id = %s
            """, (user_id,))
            rows = cursor.fetchall()

        if not rows:
            raise HTTPException(status_code=404, detail="No data found for this user.")

        df = pd.DataFrame(rows)
        df["accuracy_so_far"] = df["correct_attempts"] / df["total_attempts"]
        df["first_time"] = (df["total_attempts"] == 1).astype(int)

        df = df.sort_values(["user_id", "last_attempted_at"])
        df["time_gap"] = df.groupby("user_id")["last_attempted_at"].diff().dt.total_seconds()
        df["time_gap"] = df["time_gap"].fillna(0)

        le_user = LabelEncoder()
        le_knowledge = LabelEncoder()
        df["user_encoded"] = le_user.fit_transform(df["user_id"])
        df["knowledge_encoded"] = le_knowledge.fit_transform(df["knowledge_id"])

        # 建立錯誤序列列表（只針對單一知識點做 clustering）
        error_vectors = df.groupby("user_id")["is_correct"].apply(lambda x: 1 - x.values).tolist()

        # 執行簡化版 EM 演算法（Single-task Mixture Model）
        def B(p, o):
            return p if o == 1 else (1 - p)

        def em_algorithm(error_vectors, K=3, T=10, max_iter=10, alpha=1.0, beta=1.0):
            q_jt = np.random.uniform(0.2, 0.8, size=(K, T))
            p_j = np.ones(K) / K

            for _ in range(max_iter):
                z_sj = np.zeros((len(error_vectors), K))
                for s, v_s in enumerate(error_vectors):
                    v_s = v_s[:T] + [0] * max(0, T - len(v_s))
                    L_sj = np.array([
                        p_j[j] * np.prod([B(q_jt[j][t], v_s[t]) for t in range(T)])
                        for j in range(K)
                    ])
                    z_sj[s] = L_sj / np.sum(L_sj)

                for j in range(K):
                    for t in range(T):
                        numerator = alpha - 1 + sum(z_sj[s][j] * error_vectors[s][t] if t < len(error_vectors[s]) else 0 for s in range(len(error_vectors)))
                        denominator = alpha + beta - 2 + sum(z_sj[s][j] for s in range(len(error_vectors)))
                        q_jt[j][t] = numerator / denominator

                p_j = np.mean(z_sj, axis=0)

            return q_jt.tolist(), p_j.tolist()

        q_jt, p_j = em_algorithm(error_vectors)

        return {
            "success": True,
            "learning_curve_data": {
                "components": q_jt,
                "weights": p_j
            }
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal error: {str(e)}")
    finally:
        if connection:
            connection.close()

def get_db_connection():
    return pymysql.connect(
        host='localhost',
        user='your_db_user',
        password='your_db_password',
        db='dogtor',
        charset='utf8mb4',
        use_unicode=True,
        cursorclass=pymysql.cursors.DictCursor
    )
