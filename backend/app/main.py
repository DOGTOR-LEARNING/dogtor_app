from fastapi import FastAPI, UploadFile, File, HTTPException, Request
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
    user_message: str
    image_base64: Optional[str] = None
    subject: Optional[str] = None      # 添加科目
    chapter: Optional[str] = None      # 添加章節

# 用途可以是釐清概念或是問題目
@app.post("/chat")
async def chat_with_openai(request: ChatRequest):
    system_message = "你是個幽默的臺灣國高中老師，請用繁體中文回答問題，"
    if request.subject:
        system_message += f"學生想問的科目是{request.subject or ''}，"
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
        writer.writerow([data['q_id'], data['subject'], data['chapter'], data['description'], data['difficulty'], data['simple_answer'], data['detailed_answer'], data['timestamp']])

# Function to get the next q_id
async def get_next_q_id():
    counter_file = 'q_id_counter.txt'
    if not os.path.exists(counter_file):
        with open(counter_file, 'w') as f:
            f.write('0')
    with open(counter_file, 'r+') as f:
        current_id = int(f.read().strip())
        next_id = current_id + 1
        f.seek(0)
        f.write(str(next_id))
        f.truncate()
    return next_id

# Define a new endpoint to retrieve mistakes
@app.get("/mistake_book")
async def get_mistakes():
    mistakes = []
    if os.path.exists('questions.csv'):
        with open('questions.csv', mode='r', newline='', encoding='utf-8') as file:
            reader = csv.DictReader(file)
            for row in reader:
                mistakes.append(row)
        print(mistakes)
    return mistakes

# Modify the submit_question endpoint to use the new q_id logic
@app.post("/submit_question")
async def submit_question(request: dict):
    q_id = await get_next_q_id()
    summary = request.get('summary')
    subject = request.get('subject')
    chapter = request.get('chapter')
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

    # Save question data to CSV
    await save_question_to_csv({
        'q_id': q_id,
        'summary': summary,
        'subject': subject,
        'chapter': chapter,
        'description': description,
        'difficulty': difficulty,
        'simple_answer': simple_answer,
        'detailed_answer': detailed_answer,
        'tag': tag,
        'timestamp': timestamp
    })

    return {"status": "success", "message": "Question submitted successfully."}

# 串 GPT 統整問題摘要
# 回傳摘要、科目
@app.post("/summarize")
async def chat_with_openai(request: ChatRequest):
    message = "請你分辨輸入圖片的科目類型（國文、數學、英文、社會、自然），並且用十個字以內的話總結這個題目的重點。回傳csv格式為：科目,十字總結"
    
    if request.image_base64:
        messages = {
            "role": "user",
            "content": [
                {"type": "text", "text": message},
                {
                    "type": "image_url",
                    "image_url": {
                        "url": f"data:image/jpeg;base64,{request.image_base64}"
                    }
                }
            ]
        }
    else:
        messages = {"role": "user", "content": message}

    response = client.chat.completions.create(
        model="gpt-4o",
        messages=messages,
        max_tokens=500 # why
    )
    
    return {"response": response.choices[0].message.content}

############### SQL

# 連接到 Google Cloud SQL
def get_db_connection():
    try:
        connection = pymysql.connect(
            user=os.getenv('DB_USER'),
            password=os.getenv('DB_PASSWORD'),
            database=os.getenv('DB_NAME'),
            unix_socket=f"/cloudsql/{os.getenv('INSTANCE_CONNECTION_NAME')}",
            cursorclass=pymysql.cursors.DictCursor
        )
        return connection
    except Exception as e:
        print(f"Database connection error: {str(e)}")
        raise

# 用戶模型.
class User(BaseModel):
    user_id: str
    email: Optional[str] = None
    name: Optional[str] = None
    photo_url: Optional[str] = None
    created_at: Optional[str] = None

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

# 創建新用戶
@app.post("/users")
async def create_user(user: User):
    connection = None
    try:
        connection = get_db_connection()
        with connection.cursor() as cursor:
            # 檢查用戶是否已存在
            sql = "SELECT * FROM users WHERE user_id = %s"
            cursor.execute(sql, (user.user_id,))
            existing_user = cursor.fetchone()
            
            if existing_user:
                # 用戶已存在，檢查並初始化知識點分數
                await initialize_user_knowledge_scores(user.user_id, connection)
                return {"message": "User already exists", "user": existing_user}
            
            # 創建新用戶
            sql = """
            INSERT INTO users (user_id, email, name, photo_url, created_at)
            VALUES (%s, %s, %s, %s, %s)
            """
            cursor.execute(sql, (
                user.user_id,
                user.email,
                user.name,
                user.photo_url,
                user.created_at or datetime.now().isoformat()
            ))
            connection.commit()
            
            # 獲取創建的用戶
            sql = "SELECT * FROM users WHERE user_id = %s"
            cursor.execute(sql, (user.user_id,))
            new_user = cursor.fetchone()
            
            # 初始化知識點分數
            await initialize_user_knowledge_scores(user.user_id, connection)
            
            return {"message": "User created successfully", "user": new_user}
    except Exception as e:
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
            print(f"找到用戶: {user_result['name']} (ID: {user_result['user_id']})")
            
            # 檢查 user_knowledge_score 表結構
            try:
                cursor.execute("DESCRIBE user_knowledge_score")
                table_structure = cursor.fetchall()
                print(f"user_knowledge_score 表結構:")
                for column in table_structure:
                    print(f"  - {column['Field']}: {column['Type']} (Null: {column['Null']}, Key: {column['Key']})")
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
            print(f"知識點示例:")
            for point in sample_points:
                print(f"  - ID: {point['id']}, 小節: {point['section_name']}, 知識點: {point['point_name']}")
            
            sql = "SELECT id FROM knowledge_points"
            cursor.execute(sql)
            all_knowledge_points = cursor.fetchall()
            print(f"獲取到 {len(all_knowledge_points)} 個知識點")
            
            # 獲取用戶已有的知識點分數
            sql = "SELECT COUNT(*) as count FROM user_knowledge_score WHERE user_id = %s"
            cursor.execute(sql, (user_id,))
            count_result = cursor.fetchone()
            existing_count = count_result['count']
            print(f"用戶已有 {existing_count} 個知識點分數記錄")
            
            if existing_count > 0:
                # 顯示一些現有記錄作為示例
                sql = "SELECT * FROM user_knowledge_score WHERE user_id = %s LIMIT 3"
                cursor.execute(sql, (user_id,))
                sample_scores = cursor.fetchall()
                print(f"用戶現有知識點分數示例:")
                for score in sample_scores:
                    print(f"  - ID: {score['id']}, 知識點ID: {score['knowledge_id']}, 分數: {score['score']}")
            
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
                        print(f"測試知識點ID: {test_knowledge_id}")
                        sql = """
                        INSERT INTO user_knowledge_score (user_id, knowledge_id, score)
                        VALUES (%s, %s, 0)
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
            
            # 更新用戶信息
            sql = """
            UPDATE users
            SET email = %s, name = %s, photo_url = %s
            WHERE user_id = %s
            """
            cursor.execute(sql, (
                user.email,
                user.display_name,
                user.photo_url,
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
async def import_knowledge_points(file: UploadFile = File(...)):
    """
    導入知識點 CSV 文件
    """
    print("開始導入知識點...")
    
    if not file.filename.endswith('.csv'):
        raise HTTPException(status_code=400, detail="只接受 CSV 文件")
    
    # 讀取上傳的文件內容
    contents = await file.read()
    csv_file = io.StringIO(contents.decode('utf-8'))
    csv_reader = csv.reader(csv_file)
    
    # 跳過標題行（如果有）
    next(csv_reader, None)
    
    connection = None
    imported_count = 0
    
    try:
        connection = get_db_connection()
        
        for row in csv_reader:
            if len(row) < 4:
                print(f"跳過無效行: {row}")
                continue
            
            chapter_name = row[0].strip()
            section_num = int(row[1].strip())
            section_name = row[2].strip()
            knowledge_points_str = row[3].strip()
            
            # 查找 chapter_id
            with connection.cursor() as cursor:
                sql = "SELECT id FROM chapter_list WHERE chapter_name = %s"
                cursor.execute(sql, (chapter_name,))
                result = cursor.fetchone()
                
                if not result:
                    print(f"找不到章節: {chapter_name}，跳過")
                    continue
                
                chapter_id = result['id']
                print(f"找到章節 ID: {chapter_id} 對應章節: {chapter_name}")
                
                # 分割知識點
                knowledge_points = [kp.strip() for kp in knowledge_points_str.split('、')]
                
                # 插入每個知識點
                for point_name in knowledge_points:
                    if not point_name:
                        continue
                    
                    try:
                        sql = """
                        INSERT INTO knowledge_points 
                        (section_num, section_name, point_name, chapter_id)
                        VALUES (%s, %s, %s, %s)
                        """
                        cursor.execute(sql, (section_num, section_name, point_name, chapter_id))
                        imported_count += 1
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
    
    return {"message": f"成功導入 {imported_count} 個知識點"}

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
                    SELECT q.id, q.knowledge_id, q.question_text, q.option_1, q.option_2, q.option_3, q.option_4, q.correct_answer, q.explanation
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
                    SELECT q.id, q.knowledge_id, q.question_text, q.option_1, q.option_2, q.option_3, q.option_4, q.correct_answer, q.explanation
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
                    # 獲取題目對應的知識點
                    cursor.execute("""
                    SELECT kp.point_name
                    FROM knowledge_points kp
                    WHERE kp.id = %s
                    """, (q['knowledge_id'],))
                    
                    knowledge_point_result = cursor.fetchone()
                    knowledge_point = knowledge_point_result['point_name'] if knowledge_point_result else ""
                    
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
                        "knowledge_point": knowledge_point  # 添加知識點信息
                    })
                
                return {"success": True, "questions": result}
        
        finally:
            connection.close()
    
    except Exception as e:
        print(f"Error: {str(e)}")
        import traceback
        print(traceback.format_exc())
        return {"success": False, "message": f"獲取題目時出錯: {str(e)}"}

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

@app.post("/complete_level")
async def complete_level(request: Request):
    try:
        data = await request.json()
        user_id = data.get('user_id')
        level_id = data.get('level_id')
        stars = data.get('stars', 0)
        
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
                
                # 檢查記錄是否存在
                cursor.execute(
                    "SELECT id, stars FROM user_level WHERE user_id = %s AND level_id = %s",
                    (user_id, level_id)
                )
                record = cursor.fetchone()
                
                current_time = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                
                if record:
                    # 只有當新的星星數量更高時才更新
                    if stars > record['stars']:
                        cursor.execute(
                            "UPDATE user_level SET stars = %s, answered_at = %s WHERE id = %s",
                            (stars, current_time, record['id'])
                        )
                else:
                    # 創建新記錄
                    cursor.execute(
                        "INSERT INTO user_level (user_id, level_id, stars, answered_at) VALUES (%s, %s, %s, %s)",
                        (user_id, level_id, stars, current_time)
                    )
                
                connection.commit()
                
                # 更新用戶的知識點分數
                await _update_user_knowledge_scores(user_id, connection)
                
                return {"success": True, "message": "關卡完成記錄已更新"}
        
        finally:
            connection.close()
    
    except Exception as e:
        print(f"記錄關卡完成時出錯: {str(e)}")
        import traceback
        print(traceback.format_exc())
        return {"success": False, "message": f"記錄關卡完成時出錯: {str(e)}"}

# 輔助函數：更新用戶知識點分數
async def _update_user_knowledge_scores(user_id: str, connection):
    try:
        print(f"正在更新用戶 {user_id} 的知識點分數...")
        
        with connection.cursor() as cursor:
            # 獲取所有知識點
            cursor.execute("SELECT id FROM knowledge_points")
            all_knowledge_points = cursor.fetchall()
            
            updated_count = 0
            
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
                    accuracy = correct_attempts / total_attempts if total_attempts > 0 else 0
                    
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
                ON DUPLICATE KEY UPDATE score = %s
                """, (user_id, knowledge_id, score, score))
                
                updated_count += 1
            
            connection.commit()
            print(f"已更新 {updated_count} 個知識點的分數")
    
    except Exception as e:
        print(f"更新知識點分數時出錯: {str(e)}")
        import traceback
        print(traceback.format_exc())

@app.post("/get_user_level_stars")
async def get_user_level_stars(request: Request):
    try:
        data = await request.json()
        user_id = data.get("user_id")
        
        if not user_id:
            return {"success": False, "message": "缺少用戶 ID"}
        
        connection = get_db_connection()
        connection.charset = 'utf8mb4'
        
        try:
            with connection.cursor() as cursor:
                # 設置連接的字符集
                cursor.execute("SET NAMES utf8mb4")
                cursor.execute("SET CHARACTER SET utf8mb4")
                cursor.execute("SET character_set_connection=utf8mb4")
                
                # 查詢用戶在每個關卡中獲得的最大星星數，使用 level_id 作為鍵
                sql = """
                SELECT ul.level_id, MAX(ul.stars) as max_stars
                FROM user_level ul
                WHERE ul.user_id = %s
                GROUP BY ul.level_id
                """
                cursor.execute(sql, (user_id,))
                results = cursor.fetchall()
                
                # 將結果轉換為字典格式，使用 level_id 作為鍵
                level_stars = {}
                for row in results:
                    level_stars[str(row['level_id'])] = row['max_stars']
                
                return {"success": True, "level_stars": level_stars}
        
        finally:
            connection.close()
    
    except Exception as e:
        print(f"Error: {str(e)}")
        import traceback
        print(traceback.format_exc())
        return {"success": False, "message": f"獲取用戶關卡星星數時出錯: {str(e)}"}

@app.post("/update_knowledge_score")
async def update_knowledge_score(request: Request):
    try:
        data = await request.json()
        user_id = data.get('user_id')
        
        if not user_id:
            return {"success": False, "message": "缺少用戶 ID"}
        
        connection = get_db_connection()
        connection.charset = 'utf8mb4'
        
        try:
            with connection.cursor() as cursor:
                # 設置連接的字符集
                cursor.execute("SET NAMES utf8mb4")
                cursor.execute("SET CHARACTER SET utf8mb4")
                cursor.execute("SET character_set_connection=utf8mb4")
                
                # 獲取所有知識點
                cursor.execute("SELECT id FROM knowledge_points")
                all_knowledge_points = cursor.fetchall()
                
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
                        accuracy = correct_attempts / total_attempts if total_attempts > 0 else 0
                        
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
                    ON DUPLICATE KEY UPDATE score = %s
                    """, (user_id, knowledge_id, score, score))
                    
                    updated_scores.append({
                        "knowledge_id": knowledge_id,
                        "score": score,
                        "total_attempts": total_attempts,
                        "correct_attempts": correct_attempts
                    })
                
                connection.commit()
                
                return {
                    "success": True, 
                    "message": f"已更新 {len(updated_scores)} 個知識點的分數",
                    "updated_scores": updated_scores
                }
        
        finally:
            connection.close()
    
    except Exception as e:
        print(f"更新知識點分數時出錯: {str(e)}")
        import traceback
        print(traceback.format_exc())
        return {"success": False, "message": f"更新知識點分數時出錯: {str(e)}"}

@app.get("/get_knowledge_scores/{user_id}")
async def get_knowledge_scores(user_id: str):
    try:
        connection = get_db_connection()
        connection.charset = 'utf8mb4'
        
        try:
            with connection.cursor() as cursor:
                # 設置連接的字符集
                cursor.execute("SET NAMES utf8mb4")
                cursor.execute("SET CHARACTER SET utf8mb4")
                cursor.execute("SET character_set_connection=utf8mb4")
                
                # 獲取用戶的所有知識點分數
                cursor.execute("""
                SELECT 
                    uks.knowledge_id,
                    uks.score,
                    kp.section_name,
                    kp.point_name
                FROM user_knowledge_score uks
                JOIN knowledge_points kp ON uks.knowledge_id = kp.id
                WHERE uks.user_id = %s
                """, (user_id,))
                
                scores = cursor.fetchall()
                
                return {
                    "success": True,
                    "scores": scores
                }
        
        finally:
            connection.close()
    
    except Exception as e:
        print(f"獲取知識點分數時出錯: {str(e)}")
        import traceback
        print(traceback.format_exc())
        return {"success": False, "message": f"獲取知識點分數時出錯: {str(e)}"}
