from fastapi import FastAPI, UploadFile, File, HTTPException
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

@app.post("/generate_questions")
async def generate_questions(request: dict):
    section = request.get("section", "")
    knowledge_points = request.get("knowledge_points", {})
    section_summary = request.get("section_summary", "")
    
    prompt = f"""請根據國中「{section}」章節的範圍出 10 題認知性選擇題，格式請嚴格遵守下列 CSV 格式：

知識點,問題,解答,選項一,選項二,選項三,選項四

**課程大綱**：
{section_summary}

**請限制範圍在國中程度，不要涉及高中及以上知識。**
此回合涵蓋的知識點及該學生對各知識點的認知程度：
"""

    # 添加知識點和分數
    for point, score in knowledge_points.items():
        prompt += f"{point},{score}\n"

    # 添加其他提示內容...
    # prompt += f"**嚴禁以下內容**：{negative_prompt}"

    prompt += f"""

請根據學生對這些知識點的掌握程度（1~10 分）來調整題數及難度：
掌握分數越高(8分以上)的題數少一點、難度高一點。
掌握分數越高(3分以上)的題數多一點、簡單一點。

範例：
知識點,問題,解答,選項一,選項二,選項三,選項四
常見化學反應,下列那一項不是化學反應常伴隨的現象？,3,氣體產生,沉澱物產生,固體融化,顏色改變
示性式,醋酸的示性式是？,4,HCOOH,H₂CO₃,H₂O,CH₃COOH

請針對該學生產生 10 題相關題目，不要有多餘的解釋或格式錯誤，僅回傳純 CSV 格式數據，開頭 **不要重複標題行**，並重複檢查格式是否符合要求，並重複確認題目與答案正確。
"""
    
    response = client.chat.completions.create(
        model="gpt-4o",
        messages=[
            {"role": "system", "content": "你是一個專業的題目生成器，請使用繁體中文。"},
            {"role": "user", "content": prompt}
        ],
        temperature=0.7,
    )
    
    content = response.choices[0].message.content
    print(f"Generated content: {content}")
    
    return content

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
    return mistakes

# Modify the submit_question endpoint to use the new q_id logic
@app.post("/submit_question")
async def submit_question(request: dict):
    q_id = await get_next_q_id()
    subject = request.get('subject')
    chapter = request.get('chapter')
    description = request.get('description')
    difficulty = request.get('difficulty')
    simple_answer = request.get('simple_answer', '')
    detailed_answer = request.get('detailed_answer', '')
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
        'subject': subject,
        'chapter': chapter,
        'description': description,
        'difficulty': difficulty,
        'simple_answer': simple_answer,
        'detailed_answer': detailed_answer,
        'timestamp': timestamp
    })

    return {"status": "success", "message": "Question submitted successfully."}


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
    connection = None  # 初始化為 None
    try:
        connection = get_db_connection()
        with connection.cursor() as cursor:
            # 檢查用戶是否存在
            sql = "SELECT * FROM users WHERE user_id = %s"
            cursor.execute(sql, (user_id,))
            result = cursor.fetchone()
            
            if result:
                return {"exists": True, "user": result}
            else:
                return {"exists": False}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    finally:
        if connection:  # 只有在 connection 存在時才關閉
            connection.close()

# 創建新用戶
@app.post("/users")
async def create_user(user: User):
    try:
        connection = get_db_connection()
        with connection.cursor() as cursor:
            # 檢查用戶是否已存在
            sql = "SELECT * FROM users WHERE user_id = %s"
            cursor.execute(sql, (user.user_id,))
            existing_user = cursor.fetchone()
            
            if existing_user:
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
            
            return {"message": "User created successfully", "user": new_user}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    finally:
        connection.close()

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

