from fastapi import FastAPI, UploadFile, File, HTTPException, Request, Form
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from openai import OpenAI
from fastapi.middleware.cors import CORSMiddleware
import base64
import csv
import os
from dotenv import load_dotenv
from datetime import datetime
import pymysql
import pymysql.cursors
from typing import Optional
from pydantic import BaseModel
import io
from email.mime.text import MIMEText
from datetime import datetime, timedelta
from pytz import timezone
from firebase_push import send_push_notification
import json
# 添加新的 imports
import torch
import torch.nn as nn
from google.cloud import storage
import tempfile
import pickle
import re
import vertexai
from vertexai.generative_models import GenerativeModel, Part

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 允許所有來源（建議在開發環境使用，生產環境應指定來源）
    allow_credentials=True,
    allow_methods=["*"],  # 允許所有方法（GET, POST, PUT, DELETE）
    allow_headers=["*"],  # 允許所有標頭
)

# Serve files in the "Qpics" directory as static files (local 端的 image server)
app.mount("/static", StaticFiles(directory="Qpics"), name="static")

# 加載 .env 文件
load_dotenv()

# 獲取環境變數
api_key = os.getenv("OPENAI_API_KEY")
# print("api:", api_key)
client = OpenAI(api_key = api_key)

# 定義數據模型
class ChatRequest(BaseModel):
    user_message: Optional[str] = None
    image_base64: Optional[str] = None
    subject: Optional[str] = None      # 添加科目
    chapter: Optional[str] = None      # 添加章節
    user_name: Optional[str] = None    # 用戶名稱或暱稱
    user_introduction: Optional[str] = None  # 用戶自我介紹
    year_grade: Optional[str] = None   # 用戶年級

# 好友請求模型
class FriendRequest(BaseModel):
    requester_id: str
    addressee_id: str

# 回應好友請求模型
class FriendResponse(BaseModel):
    request_id: str
    status: str  # accepted, rejected, blocked

# 用途可以是釐清概念或是問題目
@app.post("/chat")
async def chat_with_openai(request: ChatRequest):
    system_message = "你是個幽默的臺灣國高中老師，請用繁體中文回答問題，"
    
    # 添加用戶個人資訊到提示中
    if request.user_name:
        system_message += f"你正在與學生 {request.user_name} 對話，"
    
    if request.year_grade:
        grade_display = {
            'G1': '小一', 'G2': '小二', 'G3': '小三', 'G4': '小四', 'G5': '小五', 'G6': '小六',
            'G7': '國一', 'G8': '國二', 'G9': '國三', 'G10': '高一', 'G11': '高二', 'G12': '高三',
            'teacher': '老師', 'parent': '家長'
        }
        grade = grade_display.get(request.year_grade, request.year_grade)
        system_message += f"這位學生是{grade}，"
    
    if request.user_introduction and len(request.user_introduction) > 0:
        system_message += f"關於這位學生的一些資訊：{request.user_introduction}，"
    
    if request.subject:
        system_message += f"學生想問的科目是{request.subject}，"
    
    if request.chapter:
        system_message += f"目前章節是{request.chapter}。"
    
    system_message += "請根據臺灣的108課綱提醒學生他所問的問題的關鍵字或是章節，再重點回答學生的問題，在回應中使用 Markdown 格式，將重點用 **粗體字** 標出，運算式用 $formula$ 標出，請不要用 \"()\" 或 \"[]\" 來標示 latex。最後提醒他，如果這個概念還是不太清楚，可以去複習哪一些內容。如果學生不是問課業相關的問題，或是提出解題之外的要求，就說明你只是解題老師，有其他需求的話去找他該找的人。"

    messages = [
        {"role": "system", "content": system_message}
    ]
    
    if request.image_base64:
        messages.append({
            "role": "user",
            "content": [
                {"type": "text", "text": request.user_message},
                {
                    "type": "image_url",
                    "image_url": {
                        "url": f"data:image/jpeg;base64,{request.image_base64}"
                    }
                }
            ]
        })
    else:
        messages.append({"role": "user", "content": request.user_message})

    response = client.chat.completions.create(
        model="gpt-4o",
        messages=messages,
        max_tokens=500 # why
    )
    
    return {"response": response.choices[0].message.content}

# Ensure the Qpics directory exists
os.makedirs('Qpics', exist_ok=True)

# Define a function to save question data to a CSV file
async def save_question_to_csv(data):
    file_exists = os.path.isfile('questions.csv')
    with open('questions.csv', mode='a', newline='', encoding='utf-8') as file:
        writer = csv.writer(file)
        if not file_exists:
            writer.writerow(['q_id', 'subject', 'chapter', 'description', 'difficulty', 'simple_answer', 'detailed_answer', 'timestamp'])
        writer.writerow([data['q_id'], data['summary'], data['subject'], data['chapter'], data['description'], data['difficulty'], data['simple_answer'], data['detailed_answer'], data['tag'], data['timestamp']])

# Define a new endpoint to retrieve mistakes
@app.get("/mistake_book")
async def get_mistakes():
    mistakes = []
    if os.path.exists('questions.csv'):
        print("hi from mistake book")
        with open('questions.csv', mode='r', newline='', encoding='utf-8') as file:
            reader = csv.DictReader(file)
            for row in reader:
                mistakes.append(row)
        print(mistakes)
    return mistakes

# Modify the submit_question endpoint to use the new q_id logic
@app.post("/submit_question")
async def submit_question(request: dict):
    system_message = "請你用十個字以內的話總結這個題目的重點，回傳十字總結"

    messages = [
        {"role": "system", "content": system_message}
    ]

    if request.image_base64:
        messages.append({
            "role": "user",
            "content": [
                {"type": "text", "text": request.user_message},
                {
                    "type": "image_url",
                    "image_url": {
                        "url": f"data:image/jpeg;base64,{request.image_base64}"
                    }
                }
            ]
        })
    else:
        messages.append({"role": "user", "content": request.user_message})

    response = client.chat.completions.create(
        model="gpt-4o",
        messages=messages,
        max_tokens=1000 # why
    )
    
    q_id = await get_next_q_id()
    summary = request.get('summary', '')
    subject = request.get('subject')
    chapter = request.get('chapter', '')
    description = request.get('description')
    difficulty = request.get('difficulty')
    simple_answer = request.get('simple_answer', '')
    detailed_answer = request.get('detailed_answer', '')
    tag = request.get('tag', '') #給自己的小提醒
    timestamp = datetime.now().isoformat()

    # Save image if provided
    image_base64 = request.get('image_base64')
    if image_base64:
        image_data = base64.b64decode(image_base64)
        with open(f'Qpics/{q_id}.jpg', 'wb') as image_file:
            image_file.write(image_data)

    return {"status": "success", "message": "Question submitted successfully."}

# 串 GPT 統整問題摘要
# 回傳摘要、科目
@app.post("/summarize")
async def chat_with_openai(request: ChatRequest):
    #system_message = "請你分辨輸入圖片的科目類型（國文、數學、英文、社會、自然），並且用十個字以內的話總結這個題目的重點。回傳csv格式為：科目,十字總結"
    system_message = "請你用十個字以內的話總結這個題目的重點，回傳十字總結"

    messages = [
        {"role": "system", "content": system_message}
    ]

    if request.image_base64:
        messages.append({
            "role": "user",
            "content": [
                {"type": "text", "text": request.user_message},
                {
                    "type": "image_url",
                    "image_url": {
                        "url": f"data:image/jpeg;base64,{request.image_base64}"
                    }
                }
            ]
        })
    else:
        messages.append({"role": "user", "content": request.user_message})

    response = client.chat.completions.create(
        model="gpt-4o",
        messages=messages,
        max_tokens=1000 # why
    )
    
    return {"response": response.choices[0].message.content}

############### SQL

# 連接到 Google Cloud SQL
def get_db_connection():
    # 檢測運行環境
    if os.getenv('K_SERVICE'):  # 在 Cloud Run 中運行
        # 使用 Unix socket 連接到 Cloud SQL
        instance_connection_name = os.getenv('INSTANCE_CONNECTION_NAME')
        return pymysql.connect(
            unix_socket=f'/cloudsql/{instance_connection_name}',
            user=os.getenv('DB_USER'),
            password=os.getenv('DB_PASSWORD'),
            db=os.getenv('DB_NAME'),
            charset='utf8mb4',
            use_unicode=True,
            init_command='SET NAMES utf8mb4',
            cursorclass=pymysql.cursors.DictCursor
        )
    else:  # 本地開發環境
        # 使用 TCP 連接到資料庫
        return pymysql.connect(
            host='localhost',  # 本地開發時使用的主機
            user=os.getenv('DB_USER'),
            password=os.getenv('DB_PASSWORD'),
            db=os.getenv('DB_NAME'),
            charset='utf8mb4',
            use_unicode=True,
            init_command='SET NAMES utf8mb4',
            cursorclass=pymysql.cursors.DictCursor
        )

# 用戶模型.
class User(BaseModel):
    user_id: str
    email: Optional[str] = None
    name: Optional[str] = None
    photo_url: Optional[str] = None
    created_at: Optional[str] = None
    nickname: Optional[str] = None
    year_grade: Optional[str] = None
    introduction: Optional[str] = None

# 檢查用戶是否存在
@app.get("/users/check")
async def check_user(user_id: str):
    connection = None
    try:
        print(f"檢查用戶 {user_id} 是否存在...")
        connection = get_db_connection()
        with connection.cursor() as cursor:
            # 檢查用戶是否存在
            sql = "SELECT * FROM users WHERE user_id = %s"
            cursor.execute(sql, (user_id,))
            result = cursor.fetchone()
            
            if result:
                print(f"用戶 {user_id} 存在，開始初始化知識點分數...")
                # 用戶存在，檢查並初始化知識點分數
                await initialize_user_knowledge_scores(user_id, connection)
                return {"exists": True, "user": result}
            else:
                print(f"用戶 {user_id} 不存在")
                return {"exists": False}
    except Exception as e:
        print(f"檢查用戶時出錯: {str(e)}")
        import traceback
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    finally:
        if connection:
            connection.close()

# 初始化用戶知識點分數
async def initialize_user_knowledge_scores(user_id: str, connection):
    try:
        print(f"===== 開始初始化用戶 {user_id} 的知識點分數 =====")
        
        with connection.cursor() as cursor:
            # 檢查用戶是否存在
            cursor.execute("SELECT * FROM users WHERE user_id = %s", (user_id,))
            user_result = cursor.fetchone()
            if not user_result:
                print(f"錯誤: 找不到用戶 ID: {user_id}")
                return
            # print(f"找到用戶: {user_result['name']} (ID: {user_result['user_id']})")
            
            # 檢查 user_knowledge_score 表結構
            try:
                cursor.execute("DESCRIBE user_knowledge_score")
                table_structure = cursor.fetchall()
            except Exception as e:
                print(f"無法獲取表結構: {str(e)}")
            
            # 獲取所有知識點
            cursor.execute("SELECT COUNT(*) as count FROM knowledge_points")
            count_result = cursor.fetchone()
            total_knowledge_points = count_result['count']
            print(f"數據庫中共有 {total_knowledge_points} 個知識點")
            
            if total_knowledge_points == 0:
                print("警告: 知識點表為空，無法初始化用戶知識點分數")
                return
            
            sql = "SELECT id, section_name, point_name FROM knowledge_points LIMIT 5"
            cursor.execute(sql)
            sample_points = cursor.fetchall()
            # print(f"知識點示例:")
            # for point in sample_points:
            #     print(f"  - ID: {point['id']}, 小節: {point['section_name']}, 知識點: {point['point_name']}")
            
            sql = "SELECT id FROM knowledge_points"
            cursor.execute(sql)
            all_knowledge_points = cursor.fetchall()
            # print(f"獲取到 {len(all_knowledge_points)} 個知識點")
            
            # 獲取用戶已有的知識點分數
            sql = "SELECT COUNT(*) as count FROM user_knowledge_score WHERE user_id = %s"
            cursor.execute(sql, (user_id,))
            count_result = cursor.fetchone()
            existing_count = count_result['count']
            # print(f"用戶已有 {existing_count} 個知識點分數記錄")
            
            if existing_count > 0:
                # 顯示一些現有記錄作為示例
                sql = "SELECT * FROM user_knowledge_score WHERE user_id = %s LIMIT 3"
                cursor.execute(sql, (user_id,))
                sample_scores = cursor.fetchall()
                # print(f"用戶現有知識點分數示例:")
                # for score in sample_scores:
                #     print(f"  - ID: {score['id']}, 知識點ID: {score['knowledge_id']}, 分數: {score['score']}")
            
            sql = "SELECT knowledge_id FROM user_knowledge_score WHERE user_id = %s"
            cursor.execute(sql, (user_id,))
            existing_scores = cursor.fetchall()
            existing_knowledge_ids = [score['knowledge_id'] for score in existing_scores]
            
            # 為缺少的知識點創建分數記錄
            inserted_count = 0
            error_count = 0
            for point in all_knowledge_points:
                knowledge_id = point['id']
                if knowledge_id not in existing_knowledge_ids:
                    try:
                        sql = """
                        INSERT INTO user_knowledge_score (user_id, knowledge_id, score)
                        VALUES (%s, %s, 0)
                        ON DUPLICATE KEY UPDATE score = VALUES(score)
                        """
                        cursor.execute(sql, (user_id, knowledge_id))
                        inserted_count += 1
                        
                        # 每插入10條記錄輸出一次進度
                        if inserted_count % 10 == 0:
                            print(f"已插入 {inserted_count} 條記錄...")
                    except Exception as insert_error:
                        error_count += 1
                        if error_count <= 5:  # 只顯示前5個錯誤
                            print(f"插入知識點 {knowledge_id} 時出錯: {str(insert_error)}")
                        elif error_count == 6:
                            print("更多錯誤被省略...")
            
            print(f"為用戶 {user_id} 新增了 {inserted_count} 個知識點分數記錄，失敗 {error_count} 個")
            
            if error_count > 0:
                # 嘗試插入一條測試記錄，以診斷問題
                try:
                    print("嘗試插入測試記錄...")
                    # 獲取一個不在現有記錄中的知識點ID
                    test_knowledge_id = None
                    for point in all_knowledge_points:
                        if point['id'] not in existing_knowledge_ids:
                            test_knowledge_id = point['id']
                            break
                    
                    if test_knowledge_id:
                        # print(f"測試知識點ID: {test_knowledge_id}")
                        sql = """
                        INSERT INTO user_knowledge_score (user_id, knowledge_id, score)
                        VALUES (%s, %s, 0)
                        ON DUPLICATE KEY UPDATE score = VALUES(score)
                        """
                        cursor.execute(sql, (user_id, test_knowledge_id))
                        print("測試記錄插入成功!")
                except Exception as test_error:
                    print(f"測試記錄插入失敗: {str(test_error)}")
                    print(f"SQL: INSERT INTO user_knowledge_score (user_id, knowledge_id, score) VALUES ('{user_id}', {test_knowledge_id}, 0)")
            
            # 再次檢查用戶知識點分數記錄數量
            sql = "SELECT COUNT(*) as count FROM user_knowledge_score WHERE user_id = %s"
            cursor.execute(sql, (user_id,))
            count_result = cursor.fetchone()
            final_count = count_result['count']
            print(f"初始化後，用戶共有 {final_count} 個知識點分數記錄")
            
            connection.commit()
            print(f"===== 已成功初始化用戶 {user_id} 的知識點分數 =====")
    except Exception as e:
        print(f"初始化知識點分數時出錯: {str(e)}")
        import traceback
        print(traceback.format_exc())
        # 不拋出異常，讓登錄過程繼續

# 更新用戶信息
@app.put("/users/{user_id}")
async def update_user(user_id: str, user: User):
    try:
        connection = get_db_connection()
        with connection.cursor() as cursor:
            # 檢查用戶是否存在
            sql = "SELECT * FROM users WHERE user_id = %s"
            cursor.execute(sql, (user_id,))
            existing_user = cursor.fetchone()
            
            if not existing_user:
                raise HTTPException(status_code=404, detail="User not found")
            
            # 更新用戶信息，添加對nickname、year_grade和introduction的支持
            sql = """
            UPDATE users
            SET email = %s, name = %s, photo_url = %s, nickname = %s, year_grade = %s, introduction = %s
            WHERE user_id = %s
            """
            cursor.execute(sql, (
                user.email,
                user.name,
                user.photo_url,
                user.nickname,
                user.year_grade,
                user.introduction,
                user_id
            ))
            connection.commit()
            
            # 獲取更新後的用戶
            sql = "SELECT * FROM users WHERE user_id = %s"
            cursor.execute(sql, (user_id,))
            updated_user = cursor.fetchone()
            
            return {"message": "User updated successfully", "user": updated_user}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    finally:
        connection.close()

@app.post("/admin/import-knowledge-points")
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
    
    # 讀取上傳的文件內容
    contents = await file.read()
    csv_file = io.StringIO(contents.decode('utf-8'))
    csv_reader = csv.reader(csv_file)
    
    # 跳過標題行（如果有）
    next(csv_reader, None)
    
    connection = None
    imported_knowledge_count = 0
    imported_chapter_count = 0
    
    try:
        connection = get_db_connection()
        
        for row in csv_reader:
            print(f"處理行: {row}")
            if len(row) < 8:
                print(f"跳過無效行: {row}")
                continue
            
            year_grade = int(row[1].strip())
            book = row[2].strip()
            chapter_num = int(row[3].strip())
            chapter_name = row[4].strip()
            section_num = int(row[5].strip())
            section_name = row[6].strip()
            knowledge_points_str = row[7].strip()
            
            with connection.cursor() as cursor:
                # 先檢查並插入章節
                sql_check_chapter = """
                SELECT id FROM chapter_list 
                WHERE subject = %s AND year_grade = %s AND book = %s AND chapter_num = %s
                """
                cursor.execute(sql_check_chapter, (subject, year_grade, book, chapter_num))
                result = cursor.fetchone()
                
                if not result:
                    # 插入新章節
                    sql_insert_chapter = """
                    INSERT INTO chapter_list 
                    (subject, year_grade, book, chapter_num, chapter_name)
                    VALUES (%s, %s, %s, %s, %s)
                    """
                    cursor.execute(sql_insert_chapter, (subject, year_grade, book, chapter_num, chapter_name))
                    chapter_id = cursor.lastrowid
                    imported_chapter_count += 1
                    print(f"已插入新章節: {chapter_name} (ID: {chapter_id})")
                else:
                    chapter_id = result['id']
                    print(f"找到現有章節 ID: {chapter_id} 對應章節: {chapter_name}")
                
                # 分割知識點
                knowledge_points = [kp.strip() for kp in knowledge_points_str.split('、')]
                
                # 插入每個知識點
                for point_name in knowledge_points:
                    if not point_name:
                        continue
                    
                    try:
                        sql_insert_knowledge = """
                        INSERT INTO knowledge_points 
                        (section_num, section_name, point_name, chapter_id)
                        VALUES (%s, %s, %s, %s)
                        """
                        cursor.execute(sql_insert_knowledge, (section_num, section_name, point_name, chapter_id))
                        imported_knowledge_count += 1
                        print(f"已插入知識點: {point_name}")
                    except pymysql.err.IntegrityError as e:
                        if "Duplicate entry" in str(e):
                            print(f"知識點已存在，跳過: {point_name}")
                        else:
                            print(f"插入知識點時出錯: {e}")
                            continue
            
            # 提交事務
            connection.commit()
            print(f"已完成行: {row}")
    
    except Exception as e:
        print(f"處理 CSV 文件時出錯: {e}")
        import traceback
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"導入失敗: {str(e)}")
    finally:
        if connection:
            connection.close()
            print("數據庫連接已關閉")
    
    return {
        "message": f"成功導入 {imported_chapter_count} 個章節和 {imported_knowledge_count} 個知識點",
        "chapters_imported": imported_chapter_count,
        "knowledge_points_imported": imported_knowledge_count
    }

@app.post("/get_questions_by_level")
async def get_questions_by_level(request: Request):
    try:
        data = await request.json()
        chapter = data.get("chapter", "")
        section = data.get("section", "")
        knowledge_points = data.get("knowledge_points", "")
        user_id = data.get("user_id", "")
        level_id = data.get("level_id", "")  # 獲取關卡ID
        
        print(f"接收到的請求參數: chapter={chapter}, section={section}, knowledge_points={knowledge_points}, user_id={user_id}, level_id={level_id}")
        
        # 檢查參數
        if not section and not knowledge_points:
            return {"success": False, "message": "必須提供 section 或 knowledge_points"}
        
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
                if knowledge_points:
                    # 嘗試使用頓號（、）分隔
                    if '、' in knowledge_points:
                        knowledge_point_list = [kp.strip() for kp in knowledge_points.split('、')]
                    # 嘗試使用逗號（,）分隔
                    elif ',' in knowledge_points:
                        knowledge_point_list = [kp.strip() for kp in knowledge_points.split(',')]
                    # 如果只有一個知識點
                    else:
                        knowledge_point_list = [knowledge_points.strip()]

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
                if not knowledge_ids and level_id:
                    cursor.execute("""
                    SELECT kp.id
                    FROM knowledge_points kp
                    JOIN level_knowledge_mapping lkm ON kp.id = lkm.knowledge_id
                    WHERE lkm.level_id = %s
                    """, (level_id,))
                    results = cursor.fetchall()
                    for r in results:
                        knowledge_ids.append(r['id'])

                print(f"知識點列表: {knowledge_point_list}")
                print(f"找到的知識點 ID: {knowledge_ids}")
                
                # 如果有用戶ID，獲取用戶對這些知識點的掌握程度
                knowledge_scores = {}
                total_score = 0
                if user_id:
                    for knowledge_id in knowledge_ids:
                        cursor.execute("""
                        SELECT score FROM user_knowledge_score 
                        WHERE user_id = %s AND knowledge_id = %s
                        """, (user_id, knowledge_id))
                        result = cursor.fetchone()
                        # 如果沒有分數記錄，默認為5分（中等掌握程度）
                        score = result['score'] if result else 5
                        knowledge_scores[knowledge_id] = score
                        total_score += score
                
                # 如果沒有找到任何知識點 ID，返回錯誤
                if not knowledge_ids:
                    return {"success": False, "message": "找不到匹配的知識點"}

                # 計算每個知識點應該分配的題目數量
                total_questions = 10  # 總共要獲取10題
                questions_per_knowledge = {}

                if user_id and knowledge_scores:
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
                
                if chapter:
                    conditions.append("cl.chapter_name = %s")
                    params.append(chapter)
                
                if section:
                    conditions.append("kp.section_name = %s")
                    params.append(section)
                
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
                
                return {"success": True, "questions": result}
        
        finally:
            connection.close()
    
    except Exception as e:
        print(f"Error: {str(e)}")
        import traceback
        print(traceback.format_exc())
        return {"success": False, "message": f"獲取題目時出錯: {str(e)}"}

# 處理question_stats
@app.post("/record_answer")
async def record_answer(request: Request):
    try:
        data = await request.json()
        user_id = data.get('user_id')
        question_id = data.get('question_id')
        is_correct = data.get('is_correct')
        
        print(f"收到記錄答題請求: user_id={user_id}, question_id={question_id}, is_correct={is_correct}")
        
        if not user_id or not question_id:
            return {"success": False, "message": "缺少必要參數"}
        
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
                    (user_id, question_id)
                )
                record = cursor.fetchone()
                
                current_time = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                
                if record:
                    # 更新現有記錄
                    record_id = record['id']
                    total_attempts = record['total_attempts'] + 1
                    correct_attempts = record['correct_attempts'] + (1 if is_correct else 0)
                    
                    print(f"更新現有記錄: id={record_id}, total_attempts={total_attempts}, correct_attempts={correct_attempts}")
                    
                    cursor.execute(
                        "UPDATE user_question_stats SET total_attempts = %s, correct_attempts = %s, last_attempted_at = %s WHERE id = %s",
                        (total_attempts, correct_attempts, current_time, record_id)
                    )
                else:
                    # 創建新記錄
                    print(f"創建新記錄: user_id={user_id}, question_id={question_id}, is_correct={is_correct}")
                    
                    cursor.execute(
                        "INSERT INTO user_question_stats (user_id, question_id, total_attempts, correct_attempts, last_attempted_at) VALUES (%s, %s, %s, %s, %s)",
                        (user_id, question_id, 1, 1 if is_correct else 0, current_time)
                    )
                
                connection.commit()
                print(f"成功記錄答題情況")
                return {"success": True, "message": "答題記錄已保存"}
                
        except Exception as e:
            connection.rollback()
            print(f"資料庫錯誤: {str(e)}")
            return {"success": False, "message": f"資料庫錯誤: {str(e)}"}
        finally:
            connection.close()
            
    except Exception as e:
        print(f"處理答題記錄時出錯: {str(e)}")
        import traceback
        print(traceback.format_exc())
        return {"success": False, "message": f"處理錯誤: {str(e)}"}

@app.post("/report_question_error")
async def report_question_error(request: Request):
    try:
        data = await request.json()
        question_id = data.get("question_id")
        error_message = data.get("error_message")
        
        if not question_id or not error_message:
            return {"success": False, "message": "缺少必要參數"}
        
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
                
                return {"success": True, "message": "回報成功"}
        
        finally:
            connection.close()
    
    except Exception as e:
        print(f"Error: {str(e)}")
        import traceback
        print(traceback.format_exc())
        return {"success": False, "message": f"回報題目錯誤時出錯: {str(e)}"}

# 紀錄答題狀況、更新知識點紀錄
@app.post("/complete_level")
async def complete_level(request: Request):
    try:
        data = await request.json()
        user_id = data.get('user_id')
        level_id = data.get('level_id')
        stars = data.get('stars', 0)
        
        print(f"收到關卡完成請求: user_id={user_id}, level_id={level_id}, stars={stars}")
        
        if not user_id or not level_id:
            return {"success": False, "message": "缺少必要參數"}
        
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
                INSERT INTO user_level (user_id, level_id, stars, answered_at) 
                VALUES (%s, %s, %s, %s)
                """
                cursor.execute(insert_sql, (user_id, level_id, stars, current_time))
                
                connection.commit()
                
                # 更新知識點分數
                # 從 level_info 表中獲取關卡對應的 chapter_id
                cursor.execute("""
                SELECT chapter_id FROM level_info WHERE id = %s
                """, (level_id,))
                level_result = cursor.fetchone()
                
                if not level_result:
                    return {"success": True, "message": "關卡完成記錄已新增，但無法更新知識點分數"}
                
                chapter_id = level_result['chapter_id']
                
                # 獲取該章節的所有知識點
                cursor.execute("""
                SELECT id, point_name FROM knowledge_points WHERE chapter_id = %s
                """, (chapter_id,))
                knowledge_points = cursor.fetchall()
                
                if not knowledge_points:
                    return {"success": True, "message": "關卡完成記錄已新增，但該章節沒有知識點"}
                
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
                    
                    params = [user_id] + question_ids
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
                    """, (user_id, knowledge_id, score))
                    
                    updated_count += 1
                
                connection.commit()
                
                return {"success": True, "message": "關卡完成記錄已新增"}
        
        finally:
            connection.close()
    
    except Exception as e:
        print(f"記錄關卡完成時出錯: {str(e)}")
        import traceback
        print(traceback.format_exc())
        return {"success": False, "message": f"記錄關卡完成時出錯: {str(e)}"}

@app.post("/update_knowledge_score")
async def update_knowledge_score(request: Request):
    try:
        data = await request.json()
        user_id = data.get('user_id')
        level_id = data.get('level_id')  # 新增參數，可選
        
        print(f"收到更新知識點分數請求: user_id={user_id}, level_id={level_id}")
        
        if not user_id:
            print(f"錯誤: 缺少用戶 ID")
            return {"success": False, "message": "缺少用戶 ID"}
        
        connection = get_db_connection()
        connection.charset = 'utf8mb4'
        
        try:
            with connection.cursor() as cursor:
                # 設置連接的字符集
                cursor.execute("SET NAMES utf8mb4")
                cursor.execute("SET CHARACTER SET utf8mb4")
                cursor.execute("SET character_set_connection=utf8mb4")
                
                # 如果提供了關卡 ID，只更新該關卡相關的知識點
                if level_id:
                    print(f"只更新關卡 {level_id} 相關的知識點")
                    await _update_level_knowledge_scores(user_id, level_id, connection)
                    return {
                        "success": True, 
                        "message": f"已更新關卡 {level_id} 相關的知識點分數"
                    }
                
                # 否則更新所有知識點（保留原有功能）
                print(f"更新所有知識點")
                # 獲取所有知識點
                cursor.execute("SELECT id FROM knowledge_points")
                all_knowledge_points = cursor.fetchall()
                print(f"找到 {len(all_knowledge_points)} 個知識點")
                
                updated_scores = []
                
                # 對每個知識點計算分數
                for point in all_knowledge_points:
                    knowledge_id = point['id']
                    
                    # 獲取與該知識點相關的所有題目
                    cursor.execute("""
                    SELECT q.id 
                    FROM questions q 
                    WHERE q.knowledge_id = %s
                    """, (knowledge_id,))
                    
                    questions = cursor.fetchall()
                    question_ids = [q['id'] for q in questions]
                    
                    if not question_ids:
                        # 如果沒有相關題目，跳過此知識點
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
                    
                    params = [user_id] + question_ids
                    cursor.execute(query, params)
                    stats = cursor.fetchone()
                    
                    # 計算分數
                    total_attempts = stats['total_attempts'] if stats['total_attempts'] else 0
                    correct_attempts = stats['correct_attempts'] if stats['correct_attempts'] else 0
                    
                    # 修正的分數計算公式
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
                    update_sql = """
                    INSERT INTO user_knowledge_score (user_id, knowledge_id, score)
                    VALUES (%s, %s, %s)
                    ON DUPLICATE KEY UPDATE score = VALUES(score)
                    """
                    print(f"執行 SQL: {update_sql} 參數: {user_id}, {knowledge_id}, {score}")
                    
                    cursor.execute(update_sql, (user_id, knowledge_id, score))
                    affected_rows = cursor.rowcount
                    print(f"知識點 {knowledge_id} 更新結果: 影響 {affected_rows} 行")
                    
                    updated_scores.append({
                        "knowledge_id": knowledge_id,
                        "score": score,
                        "total_attempts": total_attempts,
                        "correct_attempts": correct_attempts,
                        "affected_rows": affected_rows
                    })
                
                print(f"提交事務，更新了 {len(updated_scores)} 個知識點")
                connection.commit()
                print(f"事務提交成功")
                
                return {
                    "success": True, 
                    "message": f"已更新 {len(updated_scores)} 個知識點的分數",
                    "updated_scores": updated_scores
                }
        
        finally:
            connection.close()
            print(f"資料庫連接已關閉")
    
    except Exception as e:
        print(f"更新知識點分數時出錯: {str(e)}")
        import traceback
        print(traceback.format_exc())
        return {"success": False, "message": f"更新知識點分數時出錯: {str(e)}"}

@app.get("/get_knowledge_scores/{user_id}")
async def get_knowledge_scores(user_id: str):
    try:
        print(f"收到獲取用戶知識點分數請求: user_id={user_id}")
        
        if not user_id:
            print(f"錯誤: 缺少用戶 ID")
            return {"success": False, "message": "缺少用戶 ID"}
        
        connection = get_db_connection()
        connection.charset = 'utf8mb4'
        
        try:
            with connection.cursor() as cursor:
                # 設置連接的字符集
                cursor.execute("SET NAMES utf8mb4")
                cursor.execute("SET CHARACTER SET utf8mb4")
                cursor.execute("SET character_set_connection=utf8mb4")
                
                # 獲取用戶的知識點分數，包括知識點名稱和小節名稱
                cursor.execute("""
                SELECT 
                    uks.knowledge_id,
                    uks.score,
                    kp.point_name,
                    kp.section_name,
                    cl.subject
                FROM 
                    user_knowledge_score uks
                JOIN 
                    knowledge_points kp ON uks.knowledge_id = kp.id
                JOIN 
                    chapter_list cl ON kp.chapter_id = cl.id
                WHERE 
                    uks.user_id = %s
                ORDER BY 
                    uks.score DESC
                """, (user_id,))
                
                scores = cursor.fetchall()
                
                return {
                    "success": True,
                    "scores": scores
                }
        
        finally:
            connection.close()
    
    except Exception as e:
        print(f"獲取用戶知識點分數時出錯: {str(e)}")
        import traceback
        print(traceback.format_exc())
        return {"success": False, "message": f"獲取用戶知識點分數時出錯: {str(e)}"}

@app.post("/get_user_level_stars")
async def get_user_level_stars(request: Request):
    try:
        data = await request.json()
        user_id = data.get('user_id')
        subject = data.get('subject')  # 新增科目參數
        
        print(f"收到獲取用戶星星數請求: user_id={user_id}, subject={subject}")
        
        if not user_id:
            print(f"錯誤: 缺少用戶 ID")
            return {"success": False, "message": "缺少用戶 ID"}
        
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
                
                params = [user_id]
                
                # 如果提供了科目，則加入科目過濾條件
                if subject:
                    print(f"科目: {subject}")
                    query += """
                    JOIN level_info li ON ul.level_id = li.id
                    JOIN chapter_list cl ON li.chapter_id = cl.id
                    WHERE ul.user_id = %s AND cl.subject = %s
                    """
                    params.append(subject)
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
                    level_stars[row['level_id']] = row['stars']
                
                print(f"找到用戶 {user_id} 的星星數記錄: {len(level_stars)} 個關卡")
                
                return {
                    "success": True,
                    "level_stars": level_stars
                }
        
        finally:
            connection.close()
            print(f"資料庫連接已關閉")
    
    except Exception as e:
        print(f"獲取用戶星星數時出錯: {str(e)}")
        import traceback
        print(traceback.format_exc())
        return {"success": False, "message": f"獲取用戶星星數時出錯: {str(e)}"}

@app.get("/get_weekly_stats/{user_id}")
async def get_weekly_stats(user_id: str):
    try:
        print(f"收到獲取用戶每週學習統計請求: user_id={user_id}")
        
        if not user_id:
            print(f"錯誤: 缺少用戶 ID")
            return {"success": False, "message": "缺少用戶 ID"}
        
        connection = get_db_connection()
        connection.charset = 'utf8mb4'
        
        try:
            with connection.cursor() as cursor:
                # 設置連接的字符集
                cursor.execute("SET NAMES utf8mb4")
                cursor.execute("SET CHARACTER SET utf8mb4")
                cursor.execute("SET character_set_connection=utf8mb4")
                
                # 獲取當前日期
                from datetime import datetime, timedelta
                today = datetime.now().date()
                
                # 計算本週的開始日期（週一）
                days_since_monday = today.weekday()
                this_week_start = today - timedelta(days=days_since_monday)
                
                # 計算上週的開始和結束日期
                last_week_start = this_week_start - timedelta(days=7)
                last_week_end = this_week_start - timedelta(days=1)
                
                # 獲取本週每天的完成關卡數
                this_week_stats = []
                daily_stats = []  # 新增日常學習統計數據
                
                for i in range(7):
                    day = this_week_start + timedelta(days=i)
                    day_start = datetime.combine(day, datetime.min.time())
                    day_end = datetime.combine(day, datetime.max.time())
                    
                    cursor.execute("""
                    SELECT COUNT(*) as level_count
                    FROM user_level
                    WHERE user_id = %s AND answered_at BETWEEN %s AND %s
                    """, (user_id, day_start, day_end))
                    
                    result = cursor.fetchone()
                    level_count = result['level_count'] if result else 0
                    
                    day_data = {
                        'day': ['週一', '週二', '週三', '週四', '週五', '週六', '週日'][i],
                        'date': day.strftime('%Y-%m-%d'),
                        'levels': level_count
                    }
                    
                    this_week_stats.append(day_data)
                    
                    # 為每日統計添加數據
                    daily_stats.append({
                        'date': day.strftime('%Y-%m-%d'),
                        'completed_levels': level_count
                    })
                
                # 獲取上週每天的完成關卡數
                last_week_stats = []
                for i in range(7):
                    day = last_week_start + timedelta(days=i)
                    day_start = datetime.combine(day, datetime.min.time())
                    day_end = datetime.combine(day, datetime.max.time())
                    
                    cursor.execute("""
                    SELECT COUNT(*) as level_count
                    FROM user_level
                    WHERE user_id = %s AND answered_at BETWEEN %s AND %s
                    """, (user_id, day_start, day_end))
                    
                    result = cursor.fetchone()
                    level_count = result['level_count'] if result else 0
                    
                    last_week_stats.append({
                        'day': ['週一', '週二', '週三', '週四', '週五', '週六', '週日'][i],
                        'date': day.strftime('%Y-%m-%d'),
                        'levels': level_count
                    })
                
                # 計算學習連續性（連續學習的天數）
                cursor.execute("""
                SELECT DISTINCT DATE(answered_at) as study_date
                FROM user_level
                WHERE user_id = %s
                ORDER BY study_date DESC
                LIMIT 30
                """, (user_id,))
                
                study_dates = [row['study_date'] for row in cursor.fetchall()]
                
                streak = 0
                if study_dates:
                    # 檢查今天是否有學習
                    if study_dates[0] == today:
                        streak = 1
                        # 檢查之前的連續天數
                        for i in range(1, len(study_dates)):
                            prev_date = study_dates[i-1]
                            curr_date = study_dates[i]
                            if (prev_date - curr_date).days == 1:
                                streak += 1
                            else:
                                break
                
                return {
                    "success": True,
                    "weekly_stats": {
                        "this_week": this_week_stats,
                        "last_week": last_week_stats
                    },
                    "daily_stats": daily_stats,  # 返回每日完成關卡數
                    "streak": streak
                }
        
        finally:
            connection.close()
    
    except Exception as e:
        print(f"獲取用戶每週學習統計時出錯: {str(e)}")
        import traceback
        print(traceback.format_exc())
        return {"success": False, "message": f"獲取用戶每週學習統計時出錯: {str(e)}"}

@app.get("/get_learning_suggestions/{user_id}")
async def get_learning_suggestions(user_id: str):
    try:
        print(f"收到獲取用戶學習建議請求: user_id={user_id}")
        
        if not user_id:
            print(f"錯誤: 缺少用戶 ID")
            return {"success": False, "message": "缺少用戶 ID"}
        
        connection = get_db_connection()
        connection.charset = 'utf8mb4'
        
        try:
            with connection.cursor() as cursor:
                # 設置連接的字符集
                cursor.execute("SET NAMES utf8mb4")
                cursor.execute("SET CHARACTER SET utf8mb4")
                cursor.execute("SET character_set_connection=utf8mb4")
                
                # 獲取弱點知識點（分數 > 0 但 < 5 的）
                cursor.execute("""
                SELECT 
                    uks.knowledge_id,
                    uks.score,
                    kp.point_name,
                    kp.section_name,
                    cl.subject,
                    cl.chapter_name
                FROM 
                    user_knowledge_score uks
                JOIN 
                    knowledge_points kp ON uks.knowledge_id = kp.id
                JOIN 
                    chapter_list cl ON kp.chapter_id = cl.id
                WHERE 
                    uks.user_id = %s AND uks.score > 0 AND uks.score < 5
                ORDER BY 
                    uks.score ASC
                LIMIT 10
                """, (user_id,))
                
                weak_points = cursor.fetchall()
                
                # 獲取推薦的下一步學習章節
                cursor.execute("""
                SELECT 
                    cl.id as chapter_id,
                    cl.subject,
                    cl.chapter_name,
                    AVG(uks.score) as avg_score,
                    COUNT(DISTINCT li.id) as total_levels,
                    COUNT(DISTINCT ul.level_id) as completed_levels
                FROM 
                    chapter_list cl
                JOIN 
                    knowledge_points kp ON cl.id = kp.chapter_id
                JOIN 
                    user_knowledge_score uks ON kp.id = uks.knowledge_id
                LEFT JOIN 
                    level_info li ON cl.id = li.chapter_id
                LEFT JOIN 
                    user_level ul ON li.id = ul.level_id AND ul.user_id = %s
                WHERE 
                    uks.user_id = %s
                GROUP BY 
                    cl.id, cl.subject, cl.chapter_name
                ORDER BY 
                    avg_score ASC, (total_levels - completed_levels) DESC
                LIMIT 5
                """, (user_id, user_id))
                
                recommended_chapters = cursor.fetchall()
                
                # 生成學習建議
                tips = [
                    "每天保持固定的學習時間，建立學習習慣",
                    "專注於弱點知識點，逐一攻克",
                    "複習已完成的關卡，鞏固知識",
                    "嘗試不同科目的學習，保持學習的多樣性",
                    "設定每週學習目標，追蹤進度"
                ]
                
                # 根據弱點知識點生成具體建議
                if weak_points:
                    subjects = set([wp['subject'] for wp in weak_points])
                    for subject in subjects:
                        subject_weak_points = [wp for wp in weak_points if wp['subject'] == subject]
                        if subject_weak_points:
                            point_names = [wp['point_name'] for wp in subject_weak_points[:3]]
                            tips.append(f"加強{subject}科目中的{', '.join(point_names)}等知識點")
                
                return {
                    "success": True,
                    "weak_points": weak_points,
                    "recommended_chapters": recommended_chapters,
                    "tips": tips
                }
        
        finally:
            connection.close()
    
    except Exception as e:
        print(f"獲取用戶學習建議時出錯: {str(e)}")
        import traceback
        print(traceback.format_exc())
        return {"success": False, "message": f"獲取用戶學習建議時出錯: {str(e)}"}

# 添加新的API端點用於獲取科目和章節列表
@app.get("/get_subjects_and_chapters")
async def get_subjects_and_chapters():
    try:
        connection = get_db_connection()
        connection.charset = 'utf8mb4'
        
        try:
            with connection.cursor() as cursor:
                # 設置連接的字符集
                cursor.execute("SET NAMES utf8mb4")
                cursor.execute("SET CHARACTER SET utf8mb4")
                cursor.execute("SET character_set_connection=utf8mb4")
                
                # 獲取所有科目
                cursor.execute("SELECT DISTINCT subject FROM chapter_list ORDER BY subject")
                subjects = [item['subject'] for item in cursor.fetchall()]
                
                # 獲取每個科目的章節
                chapters_by_subject = {}
                for subject in subjects:
                    cursor.execute(
                        "SELECT id, chapter_name FROM chapter_list WHERE subject = %s ORDER BY chapter_num", 
                        (subject,)
                    )
                    chapters = cursor.fetchall()
                    chapters_by_subject[subject] = chapters
                
                return {
                    "success": True,
                    "subjects": subjects,
                    "chapters_by_subject": chapters_by_subject
                }
        
        finally:
            connection.close()
    
    except Exception as e:
        print(f"獲取科目和章節列表時出錯: {str(e)}")
        import traceback
        print(traceback.format_exc())
        return {"success": False, "message": f"獲取科目和章節列表時出錯: {str(e)}"}

# 新增輔助函數：更新特定關卡相關的知識點分數
async def _update_level_knowledge_scores(user_id: str, level_id: str, connection):
    try:
        print(f"正在更新用戶 {user_id} 的關卡 {level_id} 相關知識點分數...")
        
        with connection.cursor() as cursor:
            # 從 level_knowledge_mapping 表獲取關卡相關的知識點
            cursor.execute("""
            SELECT knowledge_id
            FROM level_knowledge_mapping
            WHERE level_id = %s
            """, (level_id,))
            
            knowledge_points = cursor.fetchall()
            knowledge_ids = [point['knowledge_id'] for point in knowledge_points if point['knowledge_id']]
            
            # 如果沒有找到知識點映射，嘗試從題目中獲取
            if not knowledge_ids:
                print(f"在 level_knowledge_mapping 中找不到關卡 {level_id} 的知識點，嘗試從題目中獲取...")
                
                # 獲取該關卡的所有題目
                cursor.execute("""
                SELECT DISTINCT q.knowledge_id
                FROM questions q
                JOIN level_questions lq ON q.id = lq.question_id
                WHERE lq.level_id = %s
                """, (level_id,))
                
                question_knowledge_points = cursor.fetchall()
                knowledge_ids = [point['knowledge_id'] for point in question_knowledge_points if point['knowledge_id']]
            
            if not knowledge_ids:
                print(f"警告: 找不到關卡 {level_id} 相關的知識點，無法更新分數")
                return
            
            print(f"找到 {len(knowledge_ids)} 個關卡相關知識點: {knowledge_ids}")
            updated_count = 0
            
            # 對每個知識點計算分數
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
                    print(f"知識點 {knowledge_id} 沒有相關題目，跳過")
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
                
                params = [user_id] + question_ids
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
                """, (user_id, knowledge_id, score))
                
                updated_count += 1
                print(f"已更新知識點 {knowledge_id} 的分數: {score}")
            
            connection.commit()
            print(f"已更新 {updated_count} 個知識點的分數")
        
    except Exception as e:
        print(f"更新關卡知識點分數時出錯: {str(e)}")
        import traceback
        print(traceback.format_exc())

# 修改處理每日使用量通知的 API
@app.get("/notify-daily-report")
async def notify_daily_report():
    try:
        print("開始執行每日報告功能...")
        import smtplib
        from email.mime.text import MIMEText
        from datetime import datetime, timedelta, timezone
        
        # 獲取環境變數
        GMAIL_ADDRESS = os.getenv("GMAIL_ADDRESS")
        APP_PASSWORD = os.getenv("APP_PASSWORD")
        RECEIVERS = os.getenv("RECEIVERS", "").split(",") if os.getenv("RECEIVERS") else []
        
        print(f"環境變數檢查: GMAIL_ADDRESS={'已設置' if GMAIL_ADDRESS else '未設置'}")
        print(f"環境變數檢查: APP_PASSWORD={'已設置' if APP_PASSWORD else '未設置'}")
        print(f"環境變數檢查: RECEIVERS={RECEIVERS}")
        
        # 發送郵件
        def send_email(subject, body):
            print(f"準備發送郵件: 主題={subject}, 收件人={RECEIVERS}")
            if not GMAIL_ADDRESS or not APP_PASSWORD or not RECEIVERS:
                print("警告: 郵件發送信息不完整，無法發送郵件")
                return False
                
            try:
                msg = MIMEText(body, "plain", "utf-8")
                msg["Subject"] = subject
                msg["From"] = GMAIL_ADDRESS
                msg["To"] = ", ".join(RECEIVERS)
                
                print("連接到 SMTP 服務器...")
                with smtplib.SMTP_SSL("smtp.gmail.com", 465) as server:
                    print("登錄 SMTP 服務器...")
                    server.login(GMAIL_ADDRESS, APP_PASSWORD)
                    print("發送郵件...")
                    server.sendmail(GMAIL_ADDRESS, RECEIVERS, msg.as_string())
                    print("郵件發送成功")
                return True
            except Exception as e:
                print(f"發送郵件時出錯: {e}")
                import traceback
                print(traceback.format_exc())
                return False
        
        # 獲取當日關卡數據
        print("開始獲取當日關卡數據...")
        
        # 設置時區為台北時間
        taipei_tz = timezone(timedelta(hours=8))
        now = datetime.now(taipei_tz)
        
        # 計算昨天的日期（台北時間）
        today = now.date()
        yesterday = today - timedelta(days=1)
        yesterday_start = datetime.combine(yesterday, datetime.min.time(), tzinfo=taipei_tz)
        yesterday_end = datetime.combine(yesterday, datetime.max.time(), tzinfo=taipei_tz)
        
        yesterday_start_str = yesterday_start.strftime('%Y-%m-%d %H:%M:%S')
        yesterday_end_str = yesterday_end.strftime('%Y-%m-%d %H:%M:%S')
        
        print(f"當前時間（台北）: {now.strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"查詢日期範圍: {yesterday_start_str} 至 {yesterday_end_str}")
        
        # 連接到資料庫
        connection = get_db_connection()
        connection.charset = 'utf8mb4'
        
        try:
            with connection.cursor() as cursor:
                # 設置連接的字符集
                cursor.execute("SET NAMES utf8mb4")
                cursor.execute("SET CHARACTER SET utf8mb4")
                cursor.execute("SET character_set_connection=utf8mb4")
                
                # 獲取昨天完成的關卡數量
                cursor.execute("""
                SELECT COUNT(*) as total_levels, COUNT(DISTINCT user_id) as total_users
                FROM user_level
                WHERE answered_at BETWEEN %s AND %s
                """, (yesterday_start_str, yesterday_end_str))
                
                level_stats = cursor.fetchone()
                total_levels = level_stats['total_levels'] if level_stats else 0
                total_users = level_stats['total_users'] if level_stats else 0
                
                # 獲取昨天的答題數量
                cursor.execute("""
                SELECT COUNT(*) as total_answers, COUNT(DISTINCT user_id) as answer_users
                FROM user_question_stats
                WHERE last_attempted_at BETWEEN %s AND %s
                """, (yesterday_start_str, yesterday_end_str))
                
                # 獲取昨天活躍的前5名用戶
                cursor.execute("""
                SELECT user_id, COUNT(*) as level_count
                FROM user_level
                WHERE answered_at BETWEEN %s AND %s
                GROUP BY user_id
                ORDER BY level_count DESC
                LIMIT 5
                """, (yesterday_start_str, yesterday_end_str))
                
                top_users = cursor.fetchall()
                
                # 獲取用戶名稱
                top_user_details = []
                for user in top_users:
                    cursor.execute("SELECT name FROM users WHERE user_id = %s", (user['user_id'],))
                    user_info = cursor.fetchone()
                    user_name = user_info['name'] if user_info and user_info['name'] else user['user_id']
                    top_user_details.append({
                        "name": user_name,
                        "level_count": user['level_count']
                    })
        
        finally:
            connection.close()
        
        # 構建郵件內容
        today_str = today.strftime("%Y-%m-%d")
        yesterday_str = yesterday.strftime("%Y-%m-%d")
        subject = f"【Dogtor 每日系統報告】{today_str}"
        
        print("構建郵件內容...")
        body = f"""Dogtor 每日使用報告 ({yesterday_str})：

【使用統計】
昨日完成關卡數：{total_levels} 個
昨日活躍用戶數：{total_users} 人
"""

        if top_user_details:
            body += "\n【昨日最活躍用戶】\n"
            for i, user in enumerate(top_user_details, 1):
                body += f"{i}. {user['name']} - 完成 {user['level_count']} 個關卡\n"
        
        body += """
祝您有美好的一天！

（本報告由系統自動生成，請勿直接回覆）
"""
        
        print("郵件內容構建完成，開始發送...")
        email_sent = send_email(subject, body)
        
        if email_sent:
            return {"status": "success", "message": "每日報告已發送"}
        else:
            return {"status": "warning", "message": "每日報告生成成功，但郵件發送失敗"}
            
    except Exception as e:
        print(f"發送每日報告時出錯: {e}")
        import traceback
        print(traceback.format_exc())
        return {"status": "error", "message": f"發送每日報告時出錯: {str(e)}"}

@app.post("/get_user_stats")
async def get_user_stats(request: Request):
    try:
        data = await request.json()
        user_id = data.get('user_id')
        
        print(f"收到獲取用戶統計數據請求: user_id={user_id}")
        
        if not user_id:
            print(f"錯誤: 缺少用戶 ID")
            return {"success": False, "message": "缺少用戶 ID"}
        
        connection = get_db_connection()
        connection.charset = 'utf8mb4'
        
        try:
            with connection.cursor() as cursor:
                # 設置連接的字符集
                cursor.execute("SET NAMES utf8mb4")
                cursor.execute("SET CHARACTER SET utf8mb4")
                cursor.execute("SET character_set_connection=utf8mb4")
                
                # 獲取今天的日期範圍
                today = datetime.now().date()
                today_start = datetime.combine(today, datetime.min.time())
                today_end = datetime.combine(today, datetime.max.time())
                
                today_start_str = today_start.strftime('%Y-%m-%d %H:%M:%S')
                today_end_str = today_end.strftime('%Y-%m-%d %H:%M:%S')
                
                # 1. 獲取今日完成的關卡數量
                cursor.execute("""
                SELECT COUNT(*) as today_levels
                FROM user_level
                WHERE user_id = %s AND answered_at BETWEEN %s AND %s
                """, (user_id, today_start_str, today_end_str))
                
                today_result = cursor.fetchone()
                today_levels = today_result['today_levels'] if today_result else 0
                
                # 2. 獲取今日各科目完成的關卡數量
                cursor.execute("""
                SELECT cl.subject, COUNT(*) as level_count
                FROM user_level ul
                JOIN level_info li ON ul.level_id = li.id
                JOIN chapter_list cl ON li.chapter_id = cl.id
                WHERE ul.user_id = %s AND ul.answered_at BETWEEN %s AND %s
                GROUP BY cl.subject
                """, (user_id, today_start_str, today_end_str))
                
                today_subject_levels = cursor.fetchall()
                
                # 3. 獲取各科目完成的關卡數量
                cursor.execute("""
                SELECT cl.subject, COUNT(*) as level_count
                FROM user_level ul
                JOIN level_info li ON ul.level_id = li.id
                JOIN chapter_list cl ON li.chapter_id = cl.id
                WHERE ul.user_id = %s
                GROUP BY cl.subject
                """, (user_id,))
                
                subject_levels = cursor.fetchall()
                
                # 4. 獲取總共完成的關卡數量
                cursor.execute("""
                SELECT COUNT(*) as total_levels
                FROM user_level
                WHERE user_id = %s
                """, (user_id,))
                
                total_result = cursor.fetchone()
                total_levels = total_result['total_levels'] if total_result else 0
                
                # 5. 獲取總體答對率
                cursor.execute("""
                SELECT 
                    SUM(total_attempts) as total_attempts,
                    SUM(correct_attempts) as correct_attempts
                FROM user_question_stats
                WHERE user_id = %s
                """, (user_id,))
                
                accuracy_result = cursor.fetchone()
                total_attempts = accuracy_result['total_attempts'] if accuracy_result and accuracy_result['total_attempts'] else 0
                correct_attempts = accuracy_result['correct_attempts'] if accuracy_result and accuracy_result['correct_attempts'] else 0
                
                accuracy = 0
                if total_attempts > 0:
                    accuracy = (correct_attempts / total_attempts) * 100
                
                # 6. 獲取最近完成的關卡
                cursor.execute("""
                SELECT 
                    ul.level_id, 
                    ul.stars, 
                    ul.answered_at,
                    cl.subject,
                    cl.chapter_name
                FROM user_level ul
                JOIN level_info li ON ul.level_id = li.id
                JOIN chapter_list cl ON li.chapter_id = cl.id
                WHERE ul.user_id = %s
                ORDER BY ul.answered_at DESC
                LIMIT 5
                """, (user_id,))
                
                recent_levels = cursor.fetchall()
                
                # 格式化最近關卡的時間
                for level in recent_levels:
                    if 'answered_at' in level and level['answered_at']:
                        level['answered_at'] = level['answered_at'].strftime('%Y-%m-%d %H:%M:%S')
                
                return {
                    "success": True,
                    "stats": {
                        "today_levels": today_levels,
                        "today_subject_levels": today_subject_levels,
                        "subject_levels": subject_levels,
                        "total_levels": total_levels,
                        "accuracy": round(accuracy, 2),
                        "recent_levels": recent_levels
                    }
                }
        
        finally:
            connection.close()
    
    except Exception as e:
        print(f"獲取用戶統計數據時出錯: {str(e)}")
        import traceback
        print(traceback.format_exc())
        return {"success": False, "message": f"獲取用戶統計數據時出錯: {str(e)}"}

# 獲取好友列表
@app.get("/get_friends/{user_id}")
async def get_friends(user_id: str):
    try:
        connection = get_db_connection()
        cursor = connection.cursor(pymysql.cursors.DictCursor)
        
        # 獲取好友列表（包括雙向的好友關係）
        query = """
        SELECT u.user_id, u.name, u.nickname, u.photo_url, u.year_grade, u.introduction
        FROM users u
        INNER JOIN friendships f ON (f.requester_id = %s AND f.addressee_id = u.user_id)
            OR (f.addressee_id = %s AND f.requester_id = u.user_id)
        WHERE f.status = 'accepted'
        ORDER BY u.name
        """
        cursor.execute(query, (user_id, user_id))
        friends = cursor.fetchall()
        
        cursor.close()
        connection.close()
        
        return {
            "status": "success",
            "friends": friends
        }
        
    except Exception as e:
        print(f"獲取好友列表時出錯: {str(e)}")
        return {
            "status": "error",
            "message": "無法獲取好友列表"
        }

@app.get("/get_friend_requests/{user_id}")
async def get_friend_requests(user_id: str):
    try:
        connection = get_db_connection()
        cursor = connection.cursor(pymysql.cursors.DictCursor)
        
        # 獲取待處理的好友請求
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
        
        cursor.close()
        connection.close()
        
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

@app.post("/send_friend_request")
async def send_friend_request(request: FriendRequest):
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
        
        cursor.close()
        connection.close()
        
        return {"status": "success", "message": "好友請求已發送"}
        
    except Exception as e:
        print(f"發送好友請求時出錯: {str(e)}")
        return {"status": "error", "message": "無法發送好友請求"}

@app.post("/respond_friend_request")
async def respond_friend_request(request: FriendResponse):
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
        cursor.execute(update_query, (request.status, request.request_id))
        connection.commit()
        
        cursor.close()
        connection.close()
        
        return {
            "status": "success",
            "message": "好友請求已更新"
        }
        
    except Exception as e:
        print(f"回應好友請求時出錯: {str(e)}")
        return {
            "status": "error",
            "message": "無法處理好友請求"
        }

# 取消好友請求
@app.post("/cancel_friend_request")
async def cancel_friend_request(request: Request):
    try:
        data = await request.json()
        requester_id = data.get('requester_id')
        addressee_id = data.get('addressee_id')
        
        if not requester_id or not addressee_id:
            return {"status": "error", "message": "請求者ID和接收者ID不能為空"}
            
        connection = get_db_connection()
        cursor = connection.cursor(pymysql.cursors.DictCursor)
        
        # 查找並刪除待處理的好友請求
        query = """
        DELETE FROM friendships 
        WHERE requester_id = %s AND addressee_id = %s AND status = 'pending'
        """
        cursor.execute(query, (requester_id, addressee_id))
        affected_rows = cursor.rowcount
        connection.commit()
        
        cursor.close()
        connection.close()
        
        if affected_rows > 0:
            return {
                "status": "success",
                "message": "好友請求已取消"
            }
        else:
            return {
                "status": "error",
                "message": "找不到相符的好友請求"
            }
        
    except Exception as e:
        print(f"取消好友請求時出錯: {str(e)}")
        return {
            "status": "error",
            "message": "無法取消好友請求"
        }

# 搜尋用戶
@app.post("/search_users")
async def search_users(request: Request):
    try:
        data = await request.json()
        query = data.get('query', '').lower()
        current_user_id = data.get('current_user_id')
        
        print(f"搜尋參數: query={query}, current_user_id={current_user_id}")  # 調試日誌
        
        if not query:
            return {"status": "error", "message": "搜尋關鍵字不能為空"}
            
        connection = get_db_connection()
        cursor = connection.cursor(pymysql.cursors.DictCursor)  # 使用字典游標
        
        # 使用 email 進行搜尋，只搜尋 @ 前的部分
        email_prefix = query.split('@')[0] if '@' in query else query
        search_query = """
            SELECT user_id, email, name, photo_url, nickname, year_grade, introduction
            FROM users
            WHERE LOWER(email) LIKE CONCAT(%s, '%%@%%')
        """
        params = [email_prefix]
        
        if current_user_id:
            search_query += " AND user_id != %s"
            params.append(current_user_id)
            
        print(f"SQL 查詢: {search_query}")  # 調試日誌
        cursor.execute(search_query, params)
        
        users = cursor.fetchall()
        print(f"查詢結果: 找到 {len(users)} 個用戶")  # 調試日誌
        
        # 處理年級顯示格式
        for user in users:
            if user['year_grade'] and user['year_grade'].startswith('G'):
                grade_num = user['year_grade'][1:]
                try:
                    user['year_grade'] = f"{grade_num}年級"
                except ValueError:
                    pass  # 如果轉換失敗，保持原樣
        
        # 檢查好友狀態
        if current_user_id and users:
            for user in users:
                cursor.execute("""
                    SELECT id, status 
                    FROM friendships 
                    WHERE (requester_id = %s AND addressee_id = %s)
                    OR (requester_id = %s AND addressee_id = %s)
                """, (current_user_id, user['user_id'], user['user_id'], current_user_id))
                
                friendship = cursor.fetchone()
                user['friend_status'] = friendship['status'] if friendship else 'none'
                
                # 如果狀態是pending，還需要添加請求ID
                if friendship and friendship['status'] == 'pending':
                    user['request_id'] = friendship['id']
                    # 檢查是發送請求的人還是接收請求的人
                    cursor.execute("""
                        SELECT requester_id
                        FROM friendships
                        WHERE id = %s
                    """, (friendship['id'],))
                    requester = cursor.fetchone()
                    user['is_requester'] = requester['requester_id'] == current_user_id
        
        connection.close()
        return {"status": "success", "users": users}
    except Exception as e:
        print(f"搜尋用戶時出錯: {str(e)}")  # 錯誤日誌
        return {"status": "error", "message": f"搜尋用戶時出錯: {str(e)}"}

if __name__ == "__main__":
    import uvicorn
    
    # 從環境變數獲取端口，如果沒有則默認使用 8080
    port = int(os.getenv("PORT", 8080))
    
    # 啟動服務器，監聽所有網絡接口
    uvicorn.run(
        "app.main:app",  # 修改為 "app.main:app"，因為檔案在 app 資料夾中
        host="0.0.0.0",
        port=port,
        reload=False  # 在生產環境中禁用重載
    )
# 創建聊天歷史記錄表
@app.post("/create_chat_history_table")
async def create_chat_history_table():
    try:
        connection = get_db_connection()
        with connection.cursor() as cursor:
            cursor.execute("""
            CREATE TABLE IF NOT EXISTS chat_history (
                id INT AUTO_INCREMENT PRIMARY KEY,
                user_id VARCHAR(255) NOT NULL,
                question TEXT NOT NULL,
                answer TEXT NOT NULL,
                year_grade VARCHAR(255),
                subject VARCHAR(255),
                chapter VARCHAR(255),
                timestamp DATETIME NOT NULL,
                FOREIGN KEY (user_id) REFERENCES users(user_id)
            )
            """)
        connection.commit()
        return {"success": True, "message": "聊天歷史記錄表創建成功"}
    except Exception as e:
        print(f"創建聊天歷史記錄表時出錯: {str(e)}")
        return {"success": False, "message": f"創建聊天歷史記錄表時出錯: {str(e)}"}
    finally:
        connection.close()

# 保存聊天記錄
@app.post("/save_chat_history")
async def save_chat_history(request: Request):
    try:
        data = await request.json()
        user_id = data.get('user_id')
        question = data.get('question')
        answer = data.get('answer')
        subject = data.get('subject')
        chapter = data.get('chapter')
        year_grade = data.get('year_grade')  # 獲取年級信息
        timestamp = data.get('timestamp')

        if not user_id or not question or not answer:
            return {"success": False, "message": "缺少必要參數"}

        connection = get_db_connection()
        with connection.cursor() as cursor:
            sql = """
            INSERT INTO chat_history (user_id, question, answer, subject, chapter, year_grade, timestamp)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            """
            cursor.execute(sql, (user_id, question, answer, subject, chapter, year_grade, timestamp))
        connection.commit()
        print(f"聊天記錄保存成功: user_id={user_id}, question={question[:20]}..., year_grade={year_grade}")
        return {"success": True, "message": "聊天記錄保存成功"}
    except Exception as e:
        print(f"保存聊天記錄時出錯: {str(e)}")
        return {"success": False, "message": f"保存聊天記錄時出錯: {str(e)}"}
    finally:
        connection.close()

# 獲取聊天歷史記錄
@app.get("/get_chat_history/{user_id}")
async def get_chat_history(user_id: str):
    try:
        connection = get_db_connection()
        with connection.cursor() as cursor:
            sql = """
            SELECT question, answer, subject, chapter, year_grade, timestamp
            FROM chat_history
            WHERE user_id = %s
            ORDER BY timestamp DESC
            LIMIT 50
            """
            cursor.execute(sql, (user_id,))
            history = cursor.fetchall()
            
            # 格式化時間戳
            for record in history:
                if 'timestamp' in record and record['timestamp']:
                    record['timestamp'] = record['timestamp'].strftime('%Y-%m-%d %H:%M:%S')
            
            return {
                "success": True,
                "history": history
            }
    except Exception as e:
        print(f"獲取聊天歷史記錄時出錯: {str(e)}")
        return {"success": False, "message": f"獲取聊天歷史記錄時出錯: {str(e)}"}
    finally:
        connection.close()

MAX_HEARTS = 5
RECOVER_DURATION = timedelta(hours=2)

def calculate_current_hearts(last_updated, stored_hearts):
    now = datetime.utcnow()
    elapsed = now - last_updated
    recovered = elapsed // RECOVER_DURATION
    new_hearts = min(MAX_HEARTS, stored_hearts + recovered)
    time_since_last = elapsed % RECOVER_DURATION
    return new_hearts, time_since_last, recovered

@app.post("/check_heart")
async def check_heart(request: Request):
    try:
        data = await request.json()
        user_id = data.get("user_id", "")
        
        if not user_id:
            return {"success": False, "message": "Missing user_id"}

        connection = get_db_connection()
        connection.charset = 'utf8mb4'

        with connection.cursor() as cursor:
            cursor.execute("SET NAMES utf8mb4")
            cursor.execute("SET CHARACTER SET utf8mb4")
            cursor.execute("SET character_set_connection=utf8mb4")
            
            # 查詢 user_heart 資料
            cursor.execute("SELECT hearts, last_updated FROM user_heart WHERE user_id = %s", (user_id,))
            result = cursor.fetchone()
            
            if not result:
                return {"success": False, "message": f"User {user_id} has no heart data."}
            
            print(result)

            stored_hearts = result['hearts']
            last_updated = result['last_updated']

            current_hearts, time_since_last, recovered = calculate_current_hearts(last_updated, stored_hearts)

            # 如果有恢復心，更新 DB
            if recovered > 0 and current_hearts < MAX_HEARTS:
                cursor.execute(
                    "UPDATE user_heart SET hearts = %s, last_updated = %s WHERE user_id = %s",
                    (current_hearts, datetime.utcnow(), user_id)
                )
                connection.commit()

            time_to_next_heart = str(RECOVER_DURATION - time_since_last) if current_hearts < MAX_HEARTS else None

            return {
                "success": True,
                "user_id": user_id,
                "hearts": current_hearts,
                "next_heart_in": time_to_next_heart
            }

    except Exception as e:
        return {"success": False, "message": str(e)}

@app.post("/consume_heart")
async def consume_heart(request: Request):
    data = await request.json()
    user_id = data.get("user_id")
    if not user_id:
        return {"success": False, "message": "Missing user_id"}

    connection = get_db_connection()
    with connection.cursor() as cursor:
        cursor.execute("SELECT hearts, last_updated FROM user_heart WHERE user_id = %s", (user_id,))
        result = cursor.fetchone()

        if not result:
            return {"success": False, "message": "User not found"}

        stored_hearts, last_updated = result['hearts'], result['last_updated']
        now = datetime.utcnow()
        elapsed = now - last_updated
        recovered = elapsed // RECOVER_DURATION
        new_hearts = min(MAX_HEARTS, stored_hearts + recovered)

        if new_hearts < 1:
            return {"success": False, "message": "Not enough hearts"}

        updated_hearts = new_hearts - 1
        cursor.execute(
            "UPDATE user_heart SET hearts = %s, last_updated = %s WHERE user_id = %s",
            (updated_hearts, now, user_id)
        )
        connection.commit()

    return {"success": True, "hearts": updated_hearts}


@app.post("/send_learning_reminder")
async def send_learning_reminder(request: Request):
    data = await request.json()
    user_id = data.get("user_id")
    message = data.get("message", "你的朋友提醒你該學習了！")
    sender_id = data.get("sender_id", None)  # 誰發送的提醒（可選）
    
    if not user_id:
        return {"success": False, "message": "Missing user_id"}
    
    print(f"📬 收到學習提醒請求: user_id={user_id}, sender_id={sender_id}")
    
    try:
        connection = get_db_connection()
        
        try:
            with connection.cursor() as cursor:
                # 確保提醒歷史表存在
                cursor.execute("""
                CREATE TABLE IF NOT EXISTS reminder_history (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    user_id VARCHAR(255) NOT NULL,
                    sender_id VARCHAR(255),
                    message TEXT,
                    sent_at DATETIME NOT NULL,
                    success BOOLEAN NOT NULL DEFAULT FALSE,
                    INDEX (user_id),
                    INDEX (sent_at)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
                """)
                connection.commit()
                
                # 檢查是否在過去24小時內已經發送過提醒
                if sender_id:
                    cursor.execute("""
                        SELECT COUNT(*) as reminder_count
                        FROM reminder_history
                        WHERE user_id = %s AND sender_id = %s 
                            AND sent_at > DATE_SUB(NOW(), INTERVAL 24 HOUR)
                            AND success = TRUE
                    """, (user_id, sender_id))
                    
                    result = cursor.fetchone()
                    reminder_count = result['reminder_count'] if result else 0
                    
                    print(f"⏰ 24小時內提醒次數: {reminder_count}")
                    
                    # 如果同一個發送者對同一個用戶在24小時內發送了超過3次提醒，限制發送
                    if reminder_count >= 3:
                        print(f"🚫 提醒次數超過限制: {reminder_count}/3")
                        return {"success": False, "message": "您已在24小時內提醒該好友多次，請稍後再試"}
                
                # 首先檢查是否有 tokens 表
                cursor.execute("""
                    SHOW TABLES LIKE 'user_tokens'
                """)
                table_exists = cursor.fetchone()
                if not table_exists:
                    # 記錄提醒嘗試但標記為失敗
                    now = datetime.utcnow()
                    cursor.execute("""
                        INSERT INTO reminder_history (user_id, sender_id, message, sent_at, success)
                        VALUES (%s, %s, %s, %s, %s)
                    """, (user_id, sender_id, message, now, False))
                    connection.commit()
                    print("❌ user_tokens 表不存在")
                    return {"success": False, "message": "通知系統尚未設置完成，無法發送提醒"}
                
                # 查詢用戶的 firebase token
                cursor.execute("""
                    SELECT firebase_token
                    FROM user_tokens
                    WHERE user_id = %s
                    ORDER BY last_updated DESC
                """, (user_id,))
                
                tokens = cursor.fetchall()
                print(f"🔍 找到 {len(tokens)} 個推送令牌")
                
                if not tokens:
                    # 記錄找不到令牌的情況
                    now = datetime.utcnow()
                    cursor.execute("""
                        INSERT INTO reminder_history (user_id, sender_id, message, sent_at, success)
                        VALUES (%s, %s, %s, %s, %s)
                    """, (user_id, sender_id, message, now, False))
                    connection.commit()
                    
                    # 檢查用戶是否存在
                    cursor.execute("SELECT name FROM users WHERE user_id = %s", (user_id,))
                    user_exists = cursor.fetchone()
                    if not user_exists:
                        print(f"❌ 用戶不存在: {user_id}")
                        return {"success": False, "message": "找不到該用戶"}
                    else:
                        print(f"⚠️ 用戶存在但沒有推送令牌: {user_id}")
                        return {"success": False, "message": "該好友尚未註冊推送通知或未登入應用程式，暫時無法接收提醒"}
                
                success_count = 0
                error_message = ""
                failed_tokens = []
                
                # 嘗試使用 messaging 直接發送
                try:
                    from firebase_admin import messaging
                    
                    for token_row in tokens:
                        token = token_row["firebase_token"]
                        
                        try:
                            # 創建消息內容
                            message_obj = messaging.Message(
                                notification=messaging.Notification(
                                    title="學習提醒",
                                    body=message,
                                ),
                                token=token,
                                # 不添加發送者相關的數據，避免權限問題
                            )
                            
                            # 直接發送消息
                            response = messaging.send(message_obj)
                            print(f"✅ 學習提醒推播成功：{token[:10]}... → {response}")
                            success_count += 1
                        except Exception as token_error:
                            print(f"❌ 向令牌 {token[:10]}... 發送失敗：{token_error}")
                            failed_tokens.append(token[:10])
                            
                            # 如果錯誤是令牌無效，可以選擇從數據庫中刪除此令牌
                            error_str = str(token_error)
                            if ("InvalidRegistration" in error_str or 
                                "NotRegistered" in error_str or
                                "InvalidArgument" in error_str):
                                print(f"🗑️ 刪除無效令牌：{token[:10]}...")
                                cursor.execute("DELETE FROM user_tokens WHERE firebase_token = %s", (token,))
                                connection.commit()
                            continue
                            
                except Exception as push_error:
                    error_message = str(push_error)
                    print(f"❌ 學習提醒推播系統錯誤：{push_error}")
                    import traceback
                    print(traceback.format_exc())
                
                # 記錄提醒歷史（即使發送失敗，也記錄嘗試）
                now = datetime.utcnow()
                cursor.execute("""
                    INSERT INTO reminder_history (user_id, sender_id, message, sent_at, success)
                    VALUES (%s, %s, %s, %s, %s)
                """, (user_id, sender_id, message, now, success_count > 0))
                
                connection.commit()
                
                # 生成詳細的響應消息
                if success_count > 0:
                    success_message = f"✅ 學習提醒已成功發送給好友！"
                    if len(failed_tokens) > 0:
                        success_message += f" （部分設備可能無法接收）"
                    print(f"🎉 發送成功: {success_count}/{len(tokens)}")
                    return {"success": True, "message": success_message, "sent_count": success_count}
                else:
                    failure_reason = "該好友暫時無法接收通知"
                    if error_message:
                        if "not registered" in error_message.lower():
                            failure_reason = "該好友的設備尚未註冊推送通知"
                        elif "invalid" in error_message.lower():
                            failure_reason = "該好友的推送設置需要更新"
                        else:
                            failure_reason = f"發送通知時發生錯誤"
                    
                    print(f"❌ 發送失敗: {failure_reason}")
                    return {"success": False, "message": f"{failure_reason}，請稍後再試或嘗試其他聯繫方式"}
                
        finally:
            connection.close()
            
    except Exception as e:
        print(f"💥 發送學習提醒時出錯: {e}")
        import traceback
        print(traceback.format_exc())
        return {"success": False, "message": "系統暫時無法發送提醒，請稍後再試"}

@app.get("/get_learning_days/{user_id}")
async def get_learning_days(user_id: str):
    try:
        print(f"收到獲取用戶學習日期記錄請求: user_id={user_id}")
        
        if not user_id:
            print(f"錯誤: 缺少用戶 ID")
            return {"success": False, "message": "缺少用戶 ID"}
        
        connection = get_db_connection()
        connection.charset = 'utf8mb4'
        
        try:
            with connection.cursor() as cursor:
                # 設置連接的字符集
                cursor.execute("SET NAMES utf8mb4")
                cursor.execute("SET CHARACTER SET utf8mb4")
                cursor.execute("SET character_set_connection=utf8mb4")
                
                # 獲取用戶學習日期記錄（最近三個月內）
                from datetime import datetime, timedelta
                today = datetime.now().date()
                three_months_ago = today - timedelta(days=90)
                
                # 查詢用戶在過去三個月內所有學習天數
                cursor.execute("""
                SELECT DISTINCT DATE(answered_at) as learning_date
                FROM user_level
                WHERE user_id = %s AND answered_at >= %s
                ORDER BY learning_date DESC
                """, (user_id, three_months_ago))
                
                results = cursor.fetchall()
                
                # 將日期格式化為ISO字符串
                learning_days = [row['learning_date'].isoformat() for row in results]
                
                # 計算最長連續學習天數，上限2500天
                cursor.execute("""
                SELECT DISTINCT DATE(answered_at) as study_date
                FROM user_level
                WHERE user_id = %s
                ORDER BY study_date
                LIMIT 2500
                """, (user_id,))
                
                all_study_dates = [row['study_date'] for row in cursor.fetchall()]
                all_study_dates.sort(reverse=True)  # 確保日期是降序排列（最新的在前）
                
                # 計算當前連續學習天數
                current_streak = 0
                yesterday = today - timedelta(days=1)
                
                if all_study_dates:
                    # 檢查最近一次學習是否是今天或昨天
                    if all_study_dates[0] == today or all_study_dates[0] == yesterday:
                        current_streak = 1
                        last_date = all_study_dates[0]
                        
                        # 檢查之前的連續天數
                        for i in range(1, len(all_study_dates)):
                            # 檢查是否與上一個日期相差正好一天
                            expected_date = last_date - timedelta(days=1)
                            if all_study_dates[i] == expected_date:
                                current_streak += 1
                                last_date = all_study_dates[i]
                            else:
                                break
                
                # 計算歷史中最長連續學習記錄
                max_streak = 0
                if all_study_dates:
                    # 將日期排序（舊到新）
                    sorted_dates = sorted(all_study_dates)
                    temp_streak = 1
                    for i in range(1, len(sorted_dates)):
                        if (sorted_dates[i] - sorted_dates[i-1]).days == 1:
                            temp_streak += 1
                        else:
                            max_streak = max(max_streak, temp_streak)
                            temp_streak = 1
                    
                    max_streak = max(max_streak, temp_streak)
                
                # 限制最大值為2500
                current_streak = min(current_streak, 2500)
                max_streak = min(max_streak, 2500)
                
                return {
                    "success": True,
                    "learning_days": learning_days,
                    "current_streak": current_streak,
                    "total_streak": max_streak  # 歷史最高連續學習天數
                }
        
        finally:
            connection.close()
    
    except Exception as e:
        print(f"獲取用戶學習日期記錄時出錯: {str(e)}")
        import traceback
        print(traceback.format_exc())
        return {"success": False, "message": f"獲取用戶學習日期記錄時出錯: {str(e)}"}

@app.post("/get_monthly_subject_progress")
async def get_monthly_subject_progress(request: Request):
    try:
        data = await request.json()
        user_id = data.get('user_id')
        
        print(f"收到獲取用戶本月科目進度請求: user_id={user_id}")
        
        if not user_id:
            print(f"錯誤: 缺少用戶 ID")
            return {"success": False, "message": "缺少用戶 ID"}
        
        connection = get_db_connection()
        connection.charset = 'utf8mb4'
        
        try:
            with connection.cursor() as cursor:
                # 設置連接的字符集
                cursor.execute("SET NAMES utf8mb4")
                cursor.execute("SET CHARACTER SET utf8mb4")
                cursor.execute("SET character_set_connection=utf8mb4")
                
                # 獲取當前月份的開始和結束日期
                from datetime import datetime, timedelta
                today = datetime.now().date()
                month_start = datetime(today.year, today.month, 1).date()
                
                # 計算當前月份的最後一天
                if today.month == 12:
                    next_month = datetime(today.year + 1, 1, 1).date()
                else:
                    next_month = datetime(today.year, today.month + 1, 1).date()
                month_end = next_month - timedelta(days=1)
                
                # 轉換為字符串格式
                month_start_str = month_start.strftime('%Y-%m-%d 00:00:00')
                month_end_str = month_end.strftime('%Y-%m-%d 23:59:59')
                
                print(f"查詢時間範圍: {month_start_str} 到 {month_end_str}")
                
                # 獲取本月各科目完成的關卡數量
                cursor.execute("""
                SELECT cl.subject, COUNT(*) as level_count
                FROM user_level ul
                JOIN level_info li ON ul.level_id = li.id
                JOIN chapter_list cl ON li.chapter_id = cl.id
                WHERE ul.user_id = %s AND ul.answered_at BETWEEN %s AND %s
                GROUP BY cl.subject
                ORDER BY cl.subject
                """, (user_id, month_start_str, month_end_str))
                
                monthly_subjects = cursor.fetchall()
                print(f"找到 {len(monthly_subjects)} 個科目的本月進度")
                
                # 獲取所有可能的科目，以便包含尚未完成的科目
                cursor.execute("""
                SELECT DISTINCT subject
                FROM chapter_list
                ORDER BY subject
                """)
                
                all_subjects = cursor.fetchall()
                
                # 將查詢結果轉換為字典格式以便快速查找
                monthly_dict = {subject['subject']: subject for subject in monthly_subjects}
                
                # 確保所有科目都有進度數據，即使沒有完成任何關卡
                result_subjects = []
                for subject in all_subjects:
                    subject_name = subject['subject']
                    if subject_name in monthly_dict:
                        result_subjects.append(monthly_dict[subject_name])
                    else:
                        result_subjects.append({
                            'subject': subject_name,
                            'level_count': 0
                        })
                
                return {
                    "success": True,
                    "monthly_subjects": result_subjects,
                    "month_info": {
                        "start_date": month_start.strftime('%Y-%m-%d'),
                        "end_date": month_end.strftime('%Y-%m-%d'),
                        "days_total": month_end.day,
                        "days_passed": today.day,
                        "days_remaining": month_end.day - today.day,
                    }
                }
        
        finally:
            connection.close()
    
    except Exception as e:
        print(f"獲取用戶本月科目進度時出錯: {str(e)}")
        import traceback
        print(traceback.format_exc())
        return {"success": False, "message": f"獲取用戶本月科目進度時出錯: {str(e)}"}

@app.post("/get_subject_abilities")
async def get_subject_abilities(request: Request):
    try:
        data = await request.json()
        user_id = data.get('user_id')
        
        print(f"收到獲取用戶科目能力統計請求: user_id={user_id}")
        
        if not user_id:
            print(f"錯誤: 缺少用戶 ID")
            return {"success": False, "message": "缺少用戶 ID"}
        
        connection = get_db_connection()
        connection.charset = 'utf8mb4'
        
        try:
            with connection.cursor() as cursor:
                # 設置連接的字符集
                cursor.execute("SET NAMES utf8mb4")
                cursor.execute("SET CHARACTER SET utf8mb4")
                cursor.execute("SET character_set_connection=utf8mb4")
                
                # 獲取按科目分組的答題數據
                cursor.execute("""
                SELECT 
                    cl.subject,
                    SUM(uqs.total_attempts) as total_attempts,
                    SUM(uqs.correct_attempts) as correct_attempts
                FROM 
                    user_question_stats uqs
                JOIN 
                    questions q ON uqs.question_id = q.id
                JOIN 
                    knowledge_points kp ON q.knowledge_id = kp.id
                JOIN 
                    chapter_list cl ON kp.chapter_id = cl.id
                WHERE 
                    uqs.user_id = %s
                GROUP BY 
                    cl.subject
                ORDER BY 
                    cl.subject
                """, (user_id,))
                
                subject_abilities = cursor.fetchall()
                print(f"找到 {len(subject_abilities)} 個科目的能力統計")
                
                # 獲取所有可能的科目，以便包含尚未答題的科目
                cursor.execute("""
                SELECT DISTINCT subject
                FROM chapter_list
                ORDER BY subject
                """)
                
                all_subjects = cursor.fetchall()
                
                # 將查詢結果轉換為字典格式以便快速查找
                abilities_dict = {item['subject']: item for item in subject_abilities}
                
                # 確保所有科目都有數據，即使沒有答題記錄
                result_abilities = []
                for subject in all_subjects:
                    subject_name = subject['subject']
                    if subject_name in abilities_dict:
                        # 計算能力分數
                        ability = abilities_dict[subject_name]
                        total_attempts = float(ability['total_attempts'] or 0)
                        correct_attempts = float(ability['correct_attempts'] or 0)
                        
                        # 使用新的計算公式: 分數=((-(1/0.01)^x)+1) * (該科目的correct_attempt/x), x=該科目的total_attempt
                        ability_score = 0
                        if total_attempts > 0:
                            try:
                                # 確保 x 不為零且不會導致過大的計算結果
                                x = min(max(total_attempts, 1), 150)  # 限制在 1-150 範圍內，防止計算溢出
                                
                                # 確保 x 是 float 類型
                                x = float(x)
                                
                                accuracy = correct_attempts / total_attempts
                                experience_factor = 1 - ((1 / 1.01) ** x)  # 這可能會計算溢出，所以限制 x 範圍
                                ability_score = experience_factor * accuracy * 10
                            except OverflowError:
                                # 如果計算溢出，使用簡化的公式
                                accuracy = correct_attempts / total_attempts
                                ability_score = accuracy * 10
                        
                        # 限制分數在 0-10 範圍內
                        ability_score = min(max(ability_score, 0), 10)
                        
                        result_abilities.append({
                            'subject': subject_name,
                            'total_attempts': int(total_attempts),
                            'correct_attempts': int(correct_attempts),
                            'ability_score': round(ability_score, 2)
                        })
                    else:
                        result_abilities.append({
                            'subject': subject_name,
                            'total_attempts': 0,
                            'correct_attempts': 0,
                            'ability_score': 0
                        })
                
                # 按能力分數排序（從高到低）
                result_abilities.sort(key=lambda x: x['ability_score'], reverse=True)
                
                return {
                    "success": True,
                    "subject_abilities": result_abilities
                }
        
        finally:
            connection.close()
    
    except Exception as e:
        print(f"獲取用戶科目能力統計時出錯: {str(e)}")
        import traceback
        print(traceback.format_exc())
        return {"success": False, "message": f"獲取用戶科目能力統計時出錯: {str(e)}"}

@app.post("/generate_learning_suggestions")
async def generate_learning_suggestions(request: Request):
    try:
        data = await request.json()
        user_id = data.get('user_id')
        prompt = data.get('prompt')
        
        # 獲取用戶個人資訊
        user_name = data.get('user_name')
        year_grade = data.get('year_grade')
        user_introduction = data.get('user_introduction')
        
        if not user_id or not prompt:
            return {"success": False, "message": "缺少必要參數"}
        
        # 增強提示以獲取具體知識點名稱
        enhanced_prompt = f"""
{prompt}

請特別注意：
1. 回傳格式必須是嚴格的JSON格式
2. 請在sections中提供具體的章節或知識點名稱，而不是一般性建議
3. "priority"部分列出2-3個最應該優先學習的具體知識點或科目名稱
4. "review"部分列出2-3個需要複習的具體知識點或科目名稱
5. "improve"部分列出2-3個可以提升的具體知識點或科目名稱
6. 不要使用通用的描述，而是使用具體名稱，例如"化學中的氧化還原反應"，"物理中的牛頓第二定律"等
"""
        
        # 嘗試使用 AI 服務
        response_text = ""
        # 嘗試使用 Vertex AI (Gemini)
        try:
            from vertexai.generative_models import GenerativeModel
            import vertexai
            
            # 初始化 VertexAI
            vertexai.init(project="dogtor-454402", location="us-central1")
            
            # 創建模型實例
            model = GenerativeModel("gemini-2.0-flash")
            
            # 添加系統提示，使用用戶個人資訊
            system_message = "你是一個專業的學習顧問，提供個人化的學習建議。"
            if user_name:
                system_message += f"你正在為學生 {user_name} 提供建議，"
            
            if year_grade:
                # 轉換年級顯示格式，例如 G10 轉為 高一
                grade_display = year_grade
                if year_grade.startswith('G'):
                    grade_num = year_grade[1:]
                    grade_mapping = {
                        '1': '國小一年級',
                        '2': '國小二年級',
                        '3': '國小三年級',
                        '4': '國小四年級',
                        '5': '國小五年級',
                        '6': '國小六年級',
                        '7': '國一',
                        '8': '國二',
                        '9': '國三',
                        '10': '高一',
                        '11': '高二',
                        '12': '高三'
                    }
                    grade_display = grade_mapping.get(grade_num, f"{grade_num}年級")
                system_message += f"該學生目前就讀{grade_display}，"
            
            if user_introduction:
                system_message += f"該學生的自我介紹是：{user_introduction}。"
            
            system_message += "請根據學生的個人資訊和學習數據，提供最適合的學習建議。"
            
            # 生成回應
            response = model.generate_content(
                system_message + "\n\n" + enhanced_prompt
            )
            response_text = response.text.strip()
            
            print(f"Gemini原始回應: {response_text[:100]}...")
        except ImportError as ie:
            # 如果Vertex AI導入失敗，使用OpenAI的API
            from openai import OpenAI
            import os
            
            # 使用OpenAI API
            client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
            
            # 添加系統提示，使用用戶個人資訊
            system_message = "你是一個專業的學習顧問，提供個人化的學習建議。"
            if user_name:
                system_message += f"你正在為學生 {user_name} 提供建議，"
            
            if year_grade:
                # 轉換年級顯示格式，例如 G10 轉為 高一
                grade_display = year_grade
                if year_grade.startswith('G'):
                    grade_num = year_grade[1:]
                    grade_mapping = {
                        '1': '國小一年級',
                        '2': '國小二年級',
                        '3': '國小三年級',
                        '4': '國小四年級',
                        '5': '國小五年級',
                        '6': '國小六年級',
                        '7': '國一',
                        '8': '國二',
                        '9': '國三',
                        '10': '高一',
                        '11': '高二',
                        '12': '高三'
                    }
                    grade_display = grade_mapping.get(grade_num, f"{grade_num}年級")
                system_message += f"該學生目前就讀{grade_display}，"
            
            if user_introduction:
                system_message += f"該學生的自我介紹是：{user_introduction}。"
            
            system_message += "請根據學生的個人資訊和學習數據，提供最適合的學習建議。"
            
            response = client.chat.completions.create(
                model="gpt-4o",
                messages=[
                    {"role": "system", "content": system_message},
                    {"role": "user", "content": enhanced_prompt}
                ],
                max_tokens=500
            )
            
            response_text = response.choices[0].message.content.strip()
            print(f"OpenAI原始回應: {response_text[:100]}...")
        except Exception as e:
            print(f"AI服務調用失敗: {e}")
            response_text = ""
        
        # 通用的回應處理邏輯
        # 清理回應文本，嘗試提取有效的 JSON 部分
        cleaned_text = response_text
        
        # 移除可能的 JSON 文本說明，尋找第一個 '{' 和最後一個 '}'
        json_start = cleaned_text.find('{')
        json_end = cleaned_text.rfind('}')
        
        if json_start >= 0 and json_end > json_start:
            cleaned_text = cleaned_text[json_start:json_end+1]
            print(f"清理後的 JSON: {cleaned_text[:100]}...")
        
        # 嘗試解析JSON格式的回應
        try:
            # 解析JSON格式回應
            parsed_data = json.loads(cleaned_text)
            
            suggestions = parsed_data.get('suggestions', [])
            sections = parsed_data.get('sections', {})
            
            # 清理建議內容，移除多餘的引號和不必要的格式
            cleaned_suggestions = []
            for suggestion in suggestions:
                # 確保建議是字符串類型
                if not isinstance(suggestion, str):
                    continue
                        
                # 移除可能的多餘引號
                suggestion = suggestion.strip()
                if suggestion.startswith('"') and suggestion.endswith('"'):
                    suggestion = suggestion[1:-1]
                
                # 移除多餘的逗號、分號等
                if suggestion.endswith(',') or suggestion.endswith(';'):
                    suggestion = suggestion[:-1]
                
                if suggestion:
                    cleaned_suggestions.append(suggestion)
            
            suggestions = cleaned_suggestions
            
            # 確保至少有5個建議
            default_suggestions = [
                "每天堅持學習，建立穩定的學習習慣。",
                "重點關注弱點科目，制定專項練習計劃。",
                "使用思維導圖整理知識點，加深理解。",
                "定期複習已學內容，鞏固記憶。",
                "嘗試不同的學習方法，找到最適合自己的。"
            ]
            
            while len(suggestions) < 5:
                for suggestion in default_suggestions:
                    if suggestion not in suggestions:
                        suggestions.append(suggestion)
                        break
                    if len(suggestions) >= 5:
                        break
            
            # 確保有必要的sections且內容具體
            default_sections = {
                "priority": "需要先確定該學生的弱點知識點後，才能給出具體的優先學習建議",
                "review": "需要查看該學生最近的學習記錄，才能給出具體的複習建議",
                "improve": "需要分析該學生的強項，才能給出具體的提升建議"
            }
            
            # 檢查sections是否包含具體的內容
            for key, default_value in default_sections.items():
                # 僅當sections缺少某個關鍵字或內容為空時才使用默認值
                if key not in sections:
                    sections[key] = default_value
                # 檢查sections的內容是否過於簡短或通用
                elif len(sections[key]) < 10 or "具體" in sections[key] or "建議" in sections[key]:
                    # 如果內容過於簡短或包含非具體的描述詞，則提示需要更具體
                    sections[key] = default_value
            
            return {
                "success": True, 
                "suggestions": suggestions[:5],
                "sections": sections
            }
            
        except json.JSONDecodeError:
            # 如果不是JSON格式，使用文本處理
            print(f"JSON解析失敗，嘗試文本處理...")
            
            # 檢查是否包含類似 ```json 這樣的代碼塊
            json_code_block_start = response_text.find("```json")
            json_code_block_end = response_text.rfind("```")
            
            if json_code_block_start >= 0 and json_code_block_end > json_code_block_start:
                # 提取 ```json 和 ``` 之間的內容
                json_block = response_text[json_code_block_start + 7:json_code_block_end].strip()
                try:
                    parsed_data = json.loads(json_block)
                    
                    suggestions = parsed_data.get('suggestions', [])
                    sections = parsed_data.get('sections', {})
                    
                    # 清理建議內容
                    cleaned_suggestions = []
                    for suggestion in suggestions:
                        if not isinstance(suggestion, str):
                            continue
                        suggestion = suggestion.strip()
                        if suggestion.startswith('"') and suggestion.endswith('"'):
                            suggestion = suggestion[1:-1]
                        if suggestion.endswith(',') or suggestion.endswith(';'):
                            suggestion = suggestion[:-1]
                        if suggestion:
                            cleaned_suggestions.append(suggestion)
                    
                    suggestions = cleaned_suggestions
                    
                    # 確保至少有5個建議
                    default_suggestions = [
                        "每天堅持學習，建立穩定的學習習慣。",
                        "重點關注弱點科目，制定專項練習計劃。",
                        "使用思維導圖整理知識點，加深理解。",
                        "定期複習已學內容，鞏固記憶。",
                        "嘗試不同的學習方法，找到最適合自己的。"
                    ]
                    
                    while len(suggestions) < 5:
                        for suggestion in default_suggestions:
                            if suggestion not in suggestions:
                                suggestions.append(suggestion)
                                break
                            if len(suggestions) >= 5:
                                break
                    
                    # 確保有必要的sections且內容具體
                    default_sections = {
                        "priority": "需要先確定該學生的弱點知識點後，才能給出具體的優先學習建議",
                        "review": "需要查看該學生最近的學習記錄，才能給出具體的複習建議",
                        "improve": "需要分析該學生的強項，才能給出具體的提升建議"
                    }
                    
                    # 檢查sections是否包含具體的內容
                    for key, default_value in default_sections.items():
                        # 僅當sections缺少某個關鍵字或內容為空時才使用默認值
                        if key not in sections:
                            sections[key] = default_value
                        # 檢查sections的內容是否過於簡短或通用
                        elif len(sections[key]) < 10 or "具體" in sections[key] or "建議" in sections[key]:
                            # 如果內容過於簡短或包含非具體的描述詞，則提示需要更具體
                            sections[key] = default_value
                    
                    return {
                        "success": True, 
                        "suggestions": suggestions[:5],
                        "sections": sections
                    }
                except json.JSONDecodeError:
                    # 如果代碼塊內容也不是有效JSON，繼續使用正常的文本處理
                    pass
            
            # 收集一般文本建議
            suggestions = []
            for line in response_text.split('\n'):
                line = line.strip()
                # 忽略空行、代碼塊標記和開頭是JSON語法的行
                if not line or line == '```' or line == '```json' or line.startswith('{') or line.startswith('}'):
                    continue
                
                # 忽略開頭是數字或符號的行（通常是編號）但提取其內容
                if line and not line[0].isdigit() and not line.startswith('-') and not line.startswith('*'):
                    if len(line) > 10:  # 確保這是一條有實質內容的建議
                        suggestions.append(line)
                # 如果是以編號或符號開頭，去掉前缀
                elif line and (line.startswith('-') or line.startswith('*')):
                    clean_line = line[1:].strip()
                    if clean_line and len(clean_line) > 10:  # 確保提取有意義的建議
                        suggestions.append(clean_line)
                elif line and line[0].isdigit() and line[1:].startswith('.'):
                    clean_line = line[2:].strip()
                    if clean_line and len(clean_line) > 10:
                        suggestions.append(clean_line)
            
            # 如果解析出的建議少於5條，補充默認建議
            default_suggestions = [
                "每天堅持學習，建立穩定的學習習慣。",
                "重點關注弱點科目，制定專項練習計劃。",
                "使用思維導圖整理知識點，加深理解。",
                "定期複習已學內容，鞏固記憶。",
                "嘗試不同的學習方法，找到最適合自己的。"
            ]
            
            while len(suggestions) < 5:
                for suggestion in default_suggestions:
                    if suggestion not in suggestions:
                        suggestions.append(suggestion)
                        break
                    if len(suggestions) >= 5:
                        break
            
            # 只返回前5條建議和默認的sections
            default_sections = {
                "priority": "優先學習弱點科目的基礎知識點，打好基礎。",
                "review": "需要複習最近學習過的內容，鞏固記憶。", 
                "improve": "可以嘗試挑戰更高難度的問題，提升學習能力。"
            }
            
            return {
                "success": True, 
                "suggestions": suggestions[:5],
                "sections": default_sections
            }
        
    except Exception as e:
        print(f"生成學習建議時出錯: {e}")
        import traceback
        print(traceback.format_exc())
        return {"success": False, "message": str(e)}

@app.post("/register_token")
async def register_token(request: Request):
    connection = get_db_connection()
    try:
        data = await request.json()
        user_id = data.get('user_id')
        firebase_token = data.get('firebase_token')
        old_token = data.get('old_token', None)
        device_info = data.get('device_info', None)

        if not user_id or not firebase_token:
            return {"success": False, "message": "缺少必要參數"}

        with connection.cursor() as cursor:
            # 如果有傳 old_token，先試著用 old_token 來更新資料
            if old_token:
                update_sql = """
                    UPDATE user_tokens
                    SET firebase_token = %s, user_id = %s, device_info = %s, last_updated = %s
                    WHERE firebase_token = %s
                """
                affected = cursor.execute(update_sql, (
                    firebase_token, user_id, device_info, datetime.utcnow(), old_token
                ))
                if affected:
                    connection.commit()
                    print(f"🔁 已更新舊 token 為新 token：{firebase_token[:10]}...")
                    return {"success": True, "message": "更新成功"}
                else:
                    print("⚠️ 找不到舊 token，改為新增 token")

            # 如果沒舊 token 或找不到，就嘗試插入新 token
            insert_sql = """
                INSERT INTO user_tokens (user_id, firebase_token, device_info, last_updated)
                VALUES (%s, %s, %s, %s)
                ON DUPLICATE KEY UPDATE
                    user_id = VALUES(user_id),
                    device_info = VALUES(device_info),
                    last_updated = VALUES(last_updated)
            """
            cursor.execute(insert_sql, (user_id, firebase_token, device_info, datetime.utcnow()))
            connection.commit()
            print(f"✅ Token 註冊成功: {firebase_token[:10]}...")
            return {"success": True, "message": "Token 註冊成功"}
    except Exception as e:
        print(f"❌ Token 註冊時出錯: {str(e)}")
        return {"success": False, "message": f"Token 註冊時出錯: {str(e)}"}
    finally:
        connection.close()

@app.post("/send_test_push")
async def send_test_push(request: Request):
    data = await request.json()
    token = data.get("token")
    title = data.get("title", "Dogtor 通知")
    body = data.get("body", "這是測試推播")

    if not token:
        return {"success": False, "message": "缺少 token"}

    result = send_push_notification(token, title, body)
    return {"success": result != "error", "message": result}

@app.post("/cron_push_heart_reminder")
def push_heart_reminder():
    now = datetime.utcnow()
    today_str = now.strftime("%Y-%m-%d")

    connection = get_db_connection()
    with connection.cursor() as cursor:

        # ① 體力已滿
        cursor.execute("""
            SELECT ut.firebase_token
            FROM user_tokens ut
            JOIN user_heart uh ON ut.user_id = uh.user_id
            WHERE uh.hearts = 5
        """)
        full_heart_tokens = [row["firebase_token"] for row in cursor.fetchall()]
        for token in full_heart_tokens:
            send_push_notification(token, "體力已回滿！", "快來 Dogtor 答題吧 ⚔️")

    connection.close()
    return {"success": True, "message": "體力回復推播發送完成"}

@app.post("/cron_push_learning_reminder")
def push_learning_reminder():
    now = datetime.utcnow()
    today_str = now.strftime("%Y-%m-%d")

    connection = get_db_connection()
    with connection.cursor() as cursor:        # ② 今日未作答
        cursor.execute("""
            SELECT ut.firebase_token
            FROM user_tokens ut
            LEFT JOIN (
                SELECT DISTINCT user_id FROM chat_history
                WHERE DATE(timestamp) = %s
            ) as active_today
            ON ut.user_id = active_today.user_id
            WHERE active_today.user_id IS NULL
        """, (today_str,))
        inactive_tokens = [row["firebase_token"] for row in cursor.fetchall()]
        for token in inactive_tokens:
            send_push_notification(token, "今天還沒答題唷 👀", "來 Dogtor 一起挑戰吧 💡")
    
    connection.close()
    return {"success": True, "message": "未答題推播發送完成"}

@app.post("/create_reminder_history_table")
async def create_reminder_history_table():
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute("""
            CREATE TABLE IF NOT EXISTS reminder_history (
                id INT AUTO_INCREMENT PRIMARY KEY,
                user_id VARCHAR(255) NOT NULL,
                sender_id VARCHAR(255),
                message TEXT,
                sent_at DATETIME NOT NULL,
                success BOOLEAN NOT NULL DEFAULT FALSE,
                INDEX (user_id),
                INDEX (sent_at)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            """)
        connection.commit()
        return {"success": True, "message": "Reminder history table created successfully"}
    except Exception as e:
        print(f"創建提醒歷史表時出錯: {e}")
        return {"success": False, "message": str(e)}
    finally:
        connection.close()

@app.post("/debug_push_notification")
async def debug_push_notification(request: Request):
    """用於調試推送通知問題的測試端點"""
    data = await request.json()
    user_id = data.get("user_id")
    
    if not user_id:
        return {"success": False, "message": "Missing user_id"}
        
    try:
        connection = get_db_connection()
        
        try:
            with connection.cursor() as cursor:
                # 查詢用戶的 firebase token
                cursor.execute("""
                    SELECT firebase_token
                    FROM user_tokens
                    WHERE user_id = %s
                    ORDER BY last_updated DESC
                    LIMIT 1
                """, (user_id,))
                
                token_row = cursor.fetchone()
                
                if not token_row:
                    return {"success": False, "message": "找不到用戶的推送通知令牌"}
                
                token = token_row["firebase_token"]
                
                # 直接使用 messaging 庫
                try:
                    from firebase_admin import messaging
                    
                    # 創建消息內容
                    message = messaging.Message(
                        notification=messaging.Notification(
                            title="測試通知",
                            body="這是一條測試通知",
                        ),
                        token=token,
                    )
                    
                    # 發送消息
                    response = messaging.send(message)
                    print(f"✅ 調試推播成功：{token[:10]}... → {response}")
                    
                    return {
                        "success": True, 
                        "message": "測試通知發送成功", 
                        "response": response,
                        "token_prefix": token[:10]
                    }
                except Exception as push_error:
                    import traceback
                    error_trace = traceback.format_exc()
                    print(f"❌ 調試推播失敗：{push_error}\n{error_trace}")
                    return {
                        "success": False, 
                        "message": f"發送測試通知失敗: {str(push_error)}",
                        "error_trace": error_trace
                    }
                
        finally:
            connection.close()
            
    except Exception as e:
        print(f"調試推送通知時出錯: {e}")
        import traceback
        error_trace = traceback.format_exc()
        print(error_trace)
        return {"success": False, "message": f"調試推送通知時出錯: {str(e)}", "error_trace": error_trace}

@app.post("/validate_tokens")
async def validate_tokens(request: Request):
    """驗證並清理無效的 Firebase 令牌"""
    data = await request.json()
    user_id = data.get("user_id")
    
    if not user_id:
        return {"success": False, "message": "Missing user_id"}
    
    try:
        connection = get_db_connection()
        
        try:
            with connection.cursor() as cursor:
                # 檢查是否有 tokens 表
                cursor.execute("""
                    SHOW TABLES LIKE 'user_tokens'
                """)
                table_exists = cursor.fetchone()
                if not table_exists:
                    return {"success": False, "message": "令牌表不存在"}
                
                # 查詢用戶的 firebase tokens
                cursor.execute("""
                    SELECT id, firebase_token, last_updated
                    FROM user_tokens
                    WHERE user_id = %s
                    ORDER BY last_updated DESC
                """, (user_id,))
                
                tokens = cursor.fetchall()
                if not tokens:
                    return {"success": False, "message": "找不到用戶的推送通知令牌", "tokens_count": 0}
                
                from firebase_admin import messaging
                valid_tokens = []
                invalid_tokens = []
                
                # 驗證每個令牌
                for token_row in tokens:
                    token_id = token_row["id"]
                    token = token_row["firebase_token"]
                    last_updated = token_row["last_updated"]
                    
                    try:
                        # 嘗試發送一個空消息來驗證令牌
                        message = messaging.Message(
                            data={"test": "true"},  # 使用靜默推送測試有效性
                            token=token,
                        )
                        
                        # 發送測試消息
                        try:
                            response = messaging.send(message, dry_run=True)  # 使用 dry_run 模式測試
                            print(f"✅ 令牌有效：{token[:10]}... → {response}")
                            valid_tokens.append({
                                "id": token_id,
                                "token_prefix": token[:10],
                                "last_updated": last_updated.strftime("%Y-%m-%d %H:%M:%S") if last_updated else None
                            })
                        except Exception as send_error:
                            if "InvalidRegistration" in str(send_error) or "NotRegistered" in str(send_error):
                                print(f"❌ 令牌無效：{token[:10]}... → {send_error}")
                                # 刪除無效令牌
                                cursor.execute("DELETE FROM user_tokens WHERE id = %s", (token_id,))
                                connection.commit()
                                invalid_tokens.append({
                                    "id": token_id,
                                    "token_prefix": token[:10],
                                    "error": str(send_error)
                                })
                            else:
                                # 其他錯誤，可能是連接問題等
                                print(f"⚠️ 令牌驗證出錯：{token[:10]}... → {send_error}")
                                valid_tokens.append({
                                    "id": token_id,
                                    "token_prefix": token[:10],
                                    "last_updated": last_updated.strftime("%Y-%m-%d %H:%M:%S") if last_updated else None,
                                    "warning": str(send_error)
                                })
                    except Exception as e:
                        print(f"⚠️ 驗證過程出錯：{e}")
                        continue
                
                return {
                    "success": True,
                    "message": "令牌驗證完成",
                    "valid_tokens_count": len(valid_tokens),
                    "invalid_tokens_count": len(invalid_tokens),
                    "valid_tokens": valid_tokens,
                    "invalid_tokens": invalid_tokens
                }
                
        finally:
            connection.close()
            
    except Exception as e:
        print(f"驗證令牌時出錯: {e}")
        import traceback
        error_trace = traceback.format_exc()
        print(error_trace)
        return {"success": False, "message": f"驗證令牌時出錯: {str(e)}", "error_trace": error_trace}

# 模型配置
MODEL_BUCKET = "dogtor_asset"
MODEL_PATH = "models/best_textcnn.pt"

# 全局變量存儲已加載的模型
loaded_model = None
model_loaded = False

# TextCNN 模型定義
class TextCNN(nn.Module):
    def __init__(self, vocab_size, embed_size, num_classes, num_filters=100, filter_sizes=[3, 4, 5], dropout=0.5):
        super(TextCNN, self).__init__()
        self.embedding = nn.Embedding(vocab_size, embed_size)
        self.convs = nn.ModuleList([
            nn.Conv1d(embed_size, num_filters, filter_size)  # 修改為 Conv1d，並調整輸入輸出通道
            for filter_size in filter_sizes
        ])
        self.dropout = nn.Dropout(dropout)
        self.fc = nn.Linear(len(filter_sizes) * num_filters, num_classes)
        
    def forward(self, x):
        x = self.embedding(x)  # (batch_size, seq_len, embed_size)
        x = x.permute(0, 2, 1)  # (batch_size, embed_size, seq_len)
        
        conv_outputs = []
        for conv in self.convs:
            conv_out = torch.relu(conv(x))  # (batch_size, num_filters, new_seq_len)
            pooled = torch.max_pool1d(conv_out, conv_out.size(2))  # (batch_size, num_filters, 1)
            conv_outputs.append(pooled.squeeze(2))  # (batch_size, num_filters)
        
        x = torch.cat(conv_outputs, dim=1)  # (batch_size, len(filter_sizes) * num_filters)
        x = self.dropout(x)
        x = self.fc(x)
        return x

def download_model_from_gcs():
    """從 Google Cloud Storage 下載模型"""
    global loaded_model, model_loaded
    
    try:
        print("開始從 Google Cloud Storage 下載模型...")
        
        # 初始化 GCS 客戶端
        client = storage.Client()
        bucket = client.bucket(MODEL_BUCKET)
        blob = bucket.blob(MODEL_PATH)
        
        # 下載到臨時文件
        with tempfile.NamedTemporaryFile(delete=False, suffix='.pt') as temp_file:
            blob.download_to_filename(temp_file.name)
            
            # 加載模型
            print(f"正在加載模型: {temp_file.name}")
            
            # 加載模型檢查點
            checkpoint = torch.load(temp_file.name, map_location='cpu')
            
            # 從檢查點獲取模型參數
            model_state = checkpoint.get('model_state_dict', checkpoint)
            vocab_size = checkpoint.get('vocab_size', 10000)  # 默認值
            embed_size = checkpoint.get('embed_size', 100)    # 默認值
            num_classes = checkpoint.get('num_classes', 50)   # 默認值
            
            # 如果檢查點中沒有這些參數，嘗試從模型狀態推斷
            if 'vocab_size' not in checkpoint:
                vocab_size = model_state['embedding.weight'].shape[0]
            if 'embed_size' not in checkpoint:
                embed_size = model_state['embedding.weight'].shape[1]
            if 'num_classes' not in checkpoint:
                num_classes = model_state['fc.weight'].shape[0]
            
            print(f"模型參數: vocab_size={vocab_size}, embed_size={embed_size}, num_classes={num_classes}")
            
            # 創建模型實例
            model = TextCNN(
                vocab_size=vocab_size,
                embed_size=embed_size,
                num_classes=num_classes
            )
            
            # 加載模型權重
            model.load_state_dict(model_state)
            model.eval()
            
            loaded_model = {
                'model': model,
                'checkpoint': checkpoint,
                'vocab_size': vocab_size,
                'embed_size': embed_size,
                'num_classes': num_classes
            }
            
            model_loaded = True
            print("✅ 模型加載成功!")
            
        # 清理臨時文件
        os.unlink(temp_file.name)
        
        return True
        
    except Exception as e:
        print(f"❌ 模型加載失敗: {str(e)}")
        import traceback
        print(traceback.format_exc())
        return False

def preprocess_text(text, vocab_to_idx=None, max_length=512):
    """預處理文本數據"""
    try:
        # 基本文本清理
        text = text.lower().strip()
        
        # 移除特殊字符，保留中文、英文和數字
        text = re.sub(r'[^\u4e00-\u9fff\w\s]', ' ', text)
        
        # 簡單的詞彙化（這裡需要根據實際的詞彙表調整）
        words = text.split()
        
        # 如果沒有詞彙表，創建一個簡單的字符級索引
        if vocab_to_idx is None:
            # 字符級處理
            chars = list(text.replace(' ', ''))
            # 創建簡單的字符到索引映射
            unique_chars = set(chars)
            vocab_to_idx = {char: idx + 1 for idx, char in enumerate(unique_chars)}
            vocab_to_idx['<UNK>'] = 0
            
            indices = [vocab_to_idx.get(char, 0) for char in chars]
        else:
            # 詞級處理
            indices = [vocab_to_idx.get(word, vocab_to_idx.get('<UNK>', 0)) for word in words]
        
        # 截斷或填充到固定長度
        if len(indices) > max_length:
            indices = indices[:max_length]
        else:
            indices.extend([0] * (max_length - len(indices)))
            
        return torch.tensor(indices, dtype=torch.long).unsqueeze(0)  # 添加 batch 維度
        
    except Exception as e:
        print(f"文本預處理錯誤: {str(e)}")
        return None

@app.post("/classify_text")
async def classify_text(request: Request):
    """使用 TextCNN 模型對文本進行分類"""
    global loaded_model, model_loaded
    
    try:
        data = await request.json()
        text = data.get('text', '')
        
        if not text:
            return {"success": False, "message": "缺少文本輸入"}
        
        print(f"收到分類請求，文本長度: {len(text)}")
        
        # 如果模型還沒有加載，嘗試加載
        if not model_loaded:
            print("模型尚未加載，開始加載...")
            success = download_model_from_gcs()
            if not success:
                return {"success": False, "message": "模型加載失敗"}
        
        if loaded_model is None:
            return {"success": False, "message": "模型未準備就緒"}
        
        # 獲取模型和相關信息
        model = loaded_model['model']
        checkpoint = loaded_model['checkpoint']
        
        # 嘗試從檢查點獲取詞彙表和標籤映射
        vocab_to_idx = checkpoint.get('vocab_to_idx', None)
        idx_to_label = checkpoint.get('idx_to_label', None)
        label_to_idx = checkpoint.get('label_to_idx', None)
        
        print(f"詞彙表大小: {len(vocab_to_idx) if vocab_to_idx else 'N/A'}")
        print(f"標籤數量: {len(idx_to_label) if idx_to_label else 'N/A'}")
        
        # 預處理文本
        processed_text = preprocess_text(text, vocab_to_idx)
        if processed_text is None:
            return {"success": False, "message": "文本預處理失敗"}
        
        # 模型推理
        with torch.no_grad():
            outputs = model(processed_text)
            probabilities = torch.softmax(outputs, dim=1)
            predicted_idx = torch.argmax(probabilities, dim=1).item()
            confidence = probabilities[0][predicted_idx].item()
        
        # 獲取預測標籤
        if idx_to_label and predicted_idx < len(idx_to_label):
            predicted_label = idx_to_label[predicted_idx]
        else:
            predicted_label = f"類別_{predicted_idx}"
        
        print(f"預測結果: {predicted_label}, 信心度: {confidence:.4f}")
        
        # 獲取前3個預測結果
        top3_probs, top3_indices = torch.topk(probabilities[0], min(3, probabilities.shape[1]))
        top3_results = []
        
        for i, (prob, idx) in enumerate(zip(top3_probs, top3_indices)):
            label = idx_to_label[idx.item()] if idx_to_label and idx.item() < len(idx_to_label) else f"類別_{idx.item()}"
            top3_results.append({
                "rank": i + 1,
                "label": label,
                "confidence": prob.item()
            })
        
        return {
            "success": True,
            "predicted_label": predicted_label,
            "confidence": confidence,
            "top3_predictions": top3_results,
            "text_length": len(text)
        }
        
    except Exception as e:
        print(f"文本分類時出錯: {str(e)}")
        import traceback
        print(traceback.format_exc())
        return {"success": False, "message": f"分類失敗: {str(e)}"}

@app.post("/reload_model")
async def reload_model():
    """重新加載模型"""
    global loaded_model, model_loaded
    
    try:
        print("開始重新加載模型...")
        loaded_model = None
        model_loaded = False
        
        success = download_model_from_gcs()
        
        if success:
            return {"success": True, "message": "模型重新加載成功"}
        else:
            return {"success": False, "message": "模型重新加載失敗"}
            
    except Exception as e:
        print(f"重新加載模型時出錯: {str(e)}")
        return {"success": False, "message": f"重新加載失敗: {str(e)}"}

@app.get("/model_status")
async def model_status():
    """檢查模型狀態"""
    global loaded_model, model_loaded
    
    try:
        if model_loaded and loaded_model:
            model_info = {
                "loaded": True,
                "vocab_size": loaded_model.get('vocab_size'),
                "embed_size": loaded_model.get('embed_size'), 
                "num_classes": loaded_model.get('num_classes'),
                "model_type": "TextCNN"
            }
            
            # 檢查是否有標籤信息
            checkpoint = loaded_model.get('checkpoint', {})
            if 'idx_to_label' in checkpoint:
                model_info["labels"] = checkpoint['idx_to_label']
            
            return {"success": True, "model_info": model_info}
        else:
            return {
                "success": True, 
                "model_info": {"loaded": False, "message": "模型尚未加載"}
            }
            
    except Exception as e:
        print(f"檢查模型狀態時出錯: {str(e)}")
        return {"success": False, "message": f"檢查模型狀態失敗: {str(e)}"}

# 在應用啟動時嘗試加載模型（可選）
@app.on_event("startup")
async def startup_event():
    """應用啟動時的初始化"""
    print("🚀 應用正在啟動...")
    
    # 可以選擇在啟動時預加載模型，或者在第一次請求時加載
    # download_model_from_gcs()
    
    print("✅ 應用啟動完成")

@app.post("/analyze_image")
async def analyze_image(request: Request):
    try:
        data = await request.json()
        image_base64 = data.get("image_base64")
        image_mime_type = data.get("image_mime_type", "image/jpeg")
        
        if not image_base64:
            return {"success": False, "message": "未提供圖片數據"}
        
        # 初始化 Vertex AI
        vertexai.init(project=os.getenv("GOOGLE_CLOUD_PROJECT"), location="us-central1")
        
        # 創建模型實例
        model = GenerativeModel("gemini-2.0-flash")
        
        # 準備圖片數據
        image_bytes = base64.b64decode(image_base64)
        image_part = Part.from_data(image_bytes, mime_type=image_mime_type)
        
        # 創建提示詞
        prompt = """請詳細描述這張圖片中的文字內容和題目。如果這是一道學術題目，請：
1. 完整轉錄所有文字內容
2. 識別題目類型（選擇題、填空題、計算題等）
3. 判斷該題目是屬於國高中哪一科目、哪一章節、哪一單元
4. 簡要說明題目的主要內容和要求
5. 如果有數學公式或特殊符號，請盡量準確描述

請用繁體中文回答。"""
        
        # 生成回應
        response = model.generate_content([prompt, image_part])
        
        # 解析回應
        content = response.text.strip()
        
        return {
            "success": True,
            "description": content
        }
        
    except Exception as e:
        print(f"圖片分析錯誤: {str(e)}")
        return {
            "success": False,
            "message": f"圖片分析失敗: {str(e)}"
        }

@app.post("/analyze_quiz_performance")
async def analyze_quiz_performance(request: Request):
    """使用 Gemini AI 分析用戶當前答題表現並提供鼓勵和建議"""
    try:
        data = await request.json()
        answer_history = data.get('answer_history', [])
        subject = data.get('subject', '')
        knowledge_points = data.get('knowledge_points', '')
        correct_count = data.get('correct_count', 0)
        total_count = data.get('total_count', 0)
        
        if not answer_history:
            return {"success": False, "message": "缺少答題資料"}
        
        # 初始化 Vertex AI
        vertexai.init(project=os.getenv("GOOGLE_CLOUD_PROJECT"), location="us-central1")
        
        # 創建模型實例
        model = GenerativeModel("gemini-2.0-flash")
        
        # 準備分析資料
        correct_answers = [item for item in answer_history if item['is_correct']]
        wrong_answers = [item for item in answer_history if not item['is_correct']]
        
        # 統計知識點表現
        knowledge_stats = {}
        for item in answer_history:
            kp = item.get('knowledge_point', '未知')
            if kp not in knowledge_stats:
                knowledge_stats[kp] = {'correct': 0, 'total': 0}
            knowledge_stats[kp]['total'] += 1
            if item['is_correct']:
                knowledge_stats[kp]['correct'] += 1
        
        # 找出表現較弱的知識點
        weak_points = []
        for kp, stats in knowledge_stats.items():
            if stats['total'] > 0:
                accuracy = stats['correct'] / stats['total']
                if accuracy < 0.7 and stats['total'] >= 2:  # 正確率低於70%且至少有2題
                    weak_points.append(f"{kp} ({stats['correct']}/{stats['total']})")
        
        # 構建分析提示詞
        accuracy_percent = (correct_count / total_count * 100) if total_count > 0 else 0
        
        prompt = f"""請以溫暖鼓勵的語氣，分析這位學生在這次測驗中的表現：

**測驗資訊：**
- 科目：{subject}
- 知識點：{knowledge_points}
- 成績：{correct_count}/{total_count} ({accuracy_percent:.0f}%)

**知識點表現：**
"""
        
        for kp, stats in knowledge_stats.items():
            accuracy = (stats['correct'] / stats['total'] * 100) if stats['total'] > 0 else 0
            prompt += f"- {kp}：{stats['correct']}/{stats['total']} ({accuracy:.0f}%)\n"
        
        if wrong_answers:
            prompt += f"\n**答錯的題目：**\n"
            for i, item in enumerate(wrong_answers[:5], 1):  # 只分析前5題錯誤
                prompt += f"{i}. {item['knowledge_point']} - 選了「{item['selected_option']}」，正確答案是「{item['correct_option']}」\n"
        
        prompt += f"""
請用繁體中文提供：
1. 一句鼓勵的話
2. 如果有表現較弱的知識點，簡單指出需要加強的地方
3. 給出1-2個具體的學習建議

請保持正面鼓勵的語氣，控制在70字以內。"""
        
        # 生成分析
        response = model.generate_content(prompt)
        analysis = response.text.strip()
        
        return {
            "success": True,
            "analysis": analysis
        }
        
    except Exception as e:
        print(f"AI 分析錯誤: {str(e)}")
        return {
            "success": False,
            "message": f"分析失敗: {str(e)}"
        }