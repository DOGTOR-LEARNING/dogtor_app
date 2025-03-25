import csv
import os
import json
import time
import pymysql
import argparse
from concurrent.futures import ThreadPoolExecutor
from google.cloud import aiplatform
from openai import OpenAI
from typing import List, Dict, Any, Tuple
from dotenv import load_dotenv
from vertexai.generative_models import GenerativeModel
import vertexai

# 加載 .env 文件
load_dotenv()

# 初始化 AI 客戶端
openai_client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
# 初始化 DeepSeek 客戶端
deepseek_client = OpenAI(
    api_key=os.getenv("DEEPSEEK_API_KEY"),
    base_url="https://api.deepseek.com"
)
aiplatform.init(project=os.getenv("GOOGLE_CLOUD_PROJECT"))

def validate_env_vars():
    """驗證必要的環境變量"""
    required_vars = [
        "OPENAI_API_KEY", 
        "DEEPSEEK_API_KEY",  # 添加 DeepSeek API 金鑰檢查
        "GOOGLE_CLOUD_PROJECT",
        "DB_USER", 
        "DB_PASSWORD", 
        "DB_NAME",
        "INSTANCE_CONNECTION_NAME"
    ]
    
    missing_vars = [var for var in required_vars if not os.getenv(var)]
    
    if missing_vars:
        raise EnvironmentError(f"缺少必要的環境變量: {', '.join(missing_vars)}")

# 獲取數據庫連接
def get_db_connection():
    try:
        # 檢查是否在 Google Cloud 環境中運行
        if os.getenv('GAE_ENV', '').startswith('standard') or os.getenv('K_SERVICE'):
            # 在 App Engine 或 Cloud Run 中運行
            connection = pymysql.connect(
                user=os.getenv('DB_USER'),
                password=os.getenv('DB_PASSWORD'),
                database=os.getenv('DB_NAME'),
                unix_socket=f"/cloudsql/{os.getenv('INSTANCE_CONNECTION_NAME')}",
                cursorclass=pymysql.cursors.DictCursor
            )
        else:
            # 在本地環境中運行，使用 Cloud SQL Proxy
            connection = pymysql.connect(
                host=os.getenv('DB_HOST', '127.0.0.1'),
                port=int(os.getenv('DB_PORT', 3306)),
                user=os.getenv('DB_USER'),
                password=os.getenv('DB_PASSWORD'),
                database=os.getenv('DB_NAME'),
                cursorclass=pymysql.cursors.DictCursor
            )
        
        print("成功連接到數據庫")
        return connection
    except Exception as e:
        print(f"數據庫連接錯誤: {str(e)}")
        print(f"環境變量: DB_USER={os.getenv('DB_USER')}, DB_NAME={os.getenv('DB_NAME')}, INSTANCE_CONNECTION_NAME={os.getenv('INSTANCE_CONNECTION_NAME')}")
        raise

def read_csv_data(csv_file_path: str) -> List[Dict[str, Any]]:
    """從 CSV 文件讀取教育數據"""
    sections_data = []
    try:
        with open(csv_file_path, 'r', encoding='utf-8') as file:
            reader = csv.reader(file)
            # 跳過標題行
            next(reader, None)
            
            for row in reader:
                if len(row) < 9:  # 確保行有足夠的列
                    print(f"警告: 跳過無效行 {row}")
                    continue
                
                section_data = {
                    "id": row[0],
                    "year_grade": row[1],
                    "book": row[2],
                    "chapter_num": row[3],
                    "chapter_name": row[4],
                    "section_num": row[5],
                    "section_name": row[6],
                    "knowledge_points": [kp.strip() for kp in row[7].split('、') if kp.strip()],
                    "description": row[8] if len(row) > 8 else ""
                }
                sections_data.append(section_data)
        
        print(f"成功從 CSV 讀取 {len(sections_data)} 個小節數據")
        return sections_data
    except Exception as e:
        print(f"讀取 CSV 文件時出錯: {e}")
        return []

def generate_questions_with_gpt4o(knowledge_points: List[str], section_data: Dict[str, Any], batch_size: int = 2) -> Dict[str, List[Dict[str, Any]]]:
    """使用 GPT-4o 為每個知識點生成題目，分批處理知識點"""
    all_questions = {}
    
    # 將知識點分成小批次
    for i in range(0, len(knowledge_points), batch_size):
        batch_points = knowledge_points[i:i+batch_size]
        print(f"處理知識點批次 {i//batch_size + 1}/{(len(knowledge_points) + batch_size - 1)//batch_size}: {', '.join(batch_points)}")
        
        try:
            # 構建提示
            prompt = f"""
你是一個專業的教育內容生成器。我需要你為以下教育內容生成選擇題：

年級: {section_data['year_grade']}
冊數: {section_data['book']}
章節: {section_data['chapter_num']} {section_data['chapter_name']}
小節: {section_data['section_num']} {section_data['section_name']}
小節描述: {section_data['description']}

這個小節包含以下所有知識點:
{', '.join(section_data['knowledge_points'])}

但在本次請求中，我只需要你為以下知識點生成題目:
{', '.join(batch_points)}

請為每個指定的知識點生成 20 道選擇題，每道題有 4 個選項，只有 1 個正確答案。

要求:
1. 題目難度要適合該年級學生
2. 題目要清晰、準確，沒有歧義
3. 選項要合理，干擾項要有迷惑性
4. 正確答案必須是 1、2、3、4 中的一個數字

請以 JSON 格式回傳，格式如下:
{{
  "知識點1": [
    {{
      "question": "題目內容",
      "options": ["選項1", "選項2", "選項3", "選項4"],
      "answer": "正確選項的數字(1-4)"
    }},
    // 更多題目...
  ],
  "知識點2": [
    // 該知識點的題目...
  ]
}}

請確保 JSON 格式正確，可以被直接解析。
"""

            # 調用 GPT-4o API
            response = openai_client.chat.completions.create(
                model="gpt-4o",
                messages=[{"role": "user", "content": prompt}],
                temperature=0.7,
                max_tokens=10000,
                response_format={"type": "json_object"}
            )
            
            # 解析回應
            content = response.choices[0].message.content
            batch_questions = json.loads(content)
            
            # 合併到總結果中
            all_questions.update(batch_questions)
            
            print(f"成功為批次 {i//batch_size + 1} 生成題目")
            
            # 添加延遲以避免 API 限制
            time.sleep(2)
            
        except Exception as e:
            print(f"為批次 {i//batch_size + 1} 生成題目時出錯: {e}")
    
    return all_questions

def verify_question_with_deepseek(question_data: Dict[str, Any]) -> Tuple[bool, str, str]:
    """使用 DeepSeek Reasoner 驗證題目"""
    try:
        prompt = f"""
請驗證以下選擇題的正確性:

題目: {question_data['question']}
選項:
1. {question_data['options'][0]}
2. {question_data['options'][1]}
3. {question_data['options'][2]}
4. {question_data['options'][3]}
給出的正確答案: {question_data['answer']}

請分析這道題目，判斷給出的答案是否正確。
如果答案正確，請只回答 "Y"。
如果答案不正確，請只回答正確的選項編號（1、2、3 或 4）。
不要提供任何其他解釋或格式。
"""

        # 調用 DeepSeek Reasoner API
        response = deepseek_client.chat.completions.create(
            model="deepseek-reasoner",
            messages=[{"role": "user", "content": prompt}],
            temperature=0.1,
            max_tokens=10,  # 限制回應長度
        )
        
        # 解析回應
        content = response.choices[0].message.content.strip()
        
        # 判斷結果
        is_correct = content == "Y"
        correct_answer = ""
        explanation = ""
        
        if not is_correct and content in ["1", "2", "3", "4"]:
            correct_answer = content
        
        return is_correct, correct_answer, explanation
    except Exception as e:
        print(f"使用 DeepSeek 驗證題目時出錯: {e}")
        return False, "", ""

def verify_question_with_o3mini(question_data: Dict[str, Any]) -> Tuple[bool, str, str]:
    """使用 o3-mini 驗證題目"""
    try:
        prompt = f"""
請驗證以下選擇題的正確性:

題目: {question_data['question']}
選項:
1. {question_data['options'][0]}
2. {question_data['options'][1]}
3. {question_data['options'][2]}
4. {question_data['options'][3]}
給出的正確答案: {question_data['answer']}

請分析這道題目，判斷給出的答案是否正確。
如果答案正確，請只回答 "Y"。
如果答案不正確，請只回答正確的選項編號（1、2、3 或 4）。
不要提供任何其他解釋或格式。
"""

        # 調用 o3-mini API
        response = openai_client.chat.completions.create(
            model="o3-mini",
            messages=[{"role": "user", "content": prompt}],
            max_tokens=10,  # 限制回應長度
        )
        
        # 解析回應
        content = response.choices[0].message.content.strip()
        
        # 判斷結果
        is_correct = content == "Y"
        correct_answer = ""
        explanation = ""
        
        if not is_correct and content in ["1", "2", "3", "4"]:
            correct_answer = content
        
        return is_correct, correct_answer, explanation
    except Exception as e:
        print(f"使用 o3-mini 驗證題目時出錯: {e}")
        return False, "", ""

def verify_question_with_gemini(question_data: Dict[str, Any]) -> Tuple[bool, str, str]:
    """使用 Gemini 2.0 Flash 驗證題目"""
    try:
        prompt = f"""
請驗證以下選擇題的正確性:

題目: {question_data['question']}
選項:
1. {question_data['options'][0]}
2. {question_data['options'][1]}
3. {question_data['options'][2]}
4. {question_data['options'][3]}
給出的正確答案: {question_data['answer']}

請分析這道題目，判斷給出的答案是否正確。
如果答案正確，請只回答 "Y"。
如果答案不正確，請只回答正確的選項編號（1、2、3 或 4）。
不要提供任何其他解釋或格式。
"""


        vertexai.init(project=os.getenv("GOOGLE_CLOUD_PROJECT"), location="asia-east1-c")
        
        # 創建模型實例
        model = GenerativeModel("gemini-1.5-flash-002")
        
        # 生成回應
        response = model.generate_content(prompt)
        
        # 解析回應
        content = response.text.strip()
        
        # 判斷結果
        is_correct = content == "Y"
        correct_answer = ""
        explanation = ""
        
        if not is_correct and content in ["1", "2", "3", "4"]:
            correct_answer = content
        
        return is_correct, correct_answer, explanation
    except Exception as e:
        print(f"使用 Gemini 驗證題目時出錯: {e}")
        return False, "", ""

def generate_explanation_with_o3mini(question_data: Dict[str, Any]) -> str:
    """使用 o3-mini 生成題目解釋"""
    try:
        prompt = f"""
請為以下選擇題生成詳細的解釋:

題目: {question_data['question']}
選項:
1. {question_data['options'][0]}
2. {question_data['options'][1]}
3. {question_data['options'][2]}
4. {question_data['options'][3]}
正確答案: {question_data['answer']}

請提供一個清晰、簡潔的解釋，說明為什麼這個答案是正確的，或是其他選項為什麼不正確。
解釋應該有教育意義，幫助學生理解相關知識點。
"""

        # 調用 o3-mini API
        response = openai_client.chat.completions.create(
            model="o3-mini",  # 改為使用 o3-mini
            messages=[{"role": "user", "content": prompt}],
            max_tokens=1000
        )
        
        # 獲取解釋
        explanation = response.choices[0].message.content
        return explanation
    except Exception as e:
        print(f"生成題目解釋時出錯: {e}")
        return "無法生成解釋。"

def save_question_to_database(connection, knowledge_id: int, question_data: Dict[str, Any], explanation: str):
    """將題目保存到數據庫"""
    try:
        with connection.cursor() as cursor:
            sql = """
            INSERT INTO questions 
            (knowledge_id, question_text, option_1, option_2, option_3, option_4, correct_answer, explanation) 
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            """
            cursor.execute(
                sql, 
                (
                    knowledge_id,
                    question_data['question'],
                    question_data['options'][0],
                    question_data['options'][1],
                    question_data['options'][2],
                    question_data['options'][3],
                    question_data['answer'],
                    explanation
                )
            )
        connection.commit()
        print(f"成功保存題目: {question_data['question'][:30]}...")
        return True
    except Exception as e:
        print(f"保存題目到數據庫時出錯: {e}")
        connection.rollback()
        return False

def get_or_create_chapter(connection, subject: str, section_data: Dict[str, Any]) -> int:
    """獲取或創建章節，返回章節 ID"""
    try:
        with connection.cursor() as cursor:
            # 檢查章節是否存在
            sql = """
            SELECT id FROM chapter_list 
            WHERE subject = %s AND chapter_name = %s
            """
            cursor.execute(sql, (subject, section_data['chapter_name']))
            result = cursor.fetchone()
            
            if result:
                return result['id']
            
            # 創建新章節
            sql = """
            INSERT INTO chapter_list 
            (subject, year_grade, book, chapter_num, chapter_name) 
            VALUES (%s, %s, %s, %s, %s)
            """
            cursor.execute(
                sql, 
                (
                    subject,
                    int(section_data['year_grade']),
                    section_data['book'],
                    int(section_data['chapter_num']),
                    section_data['chapter_name']
                )
            )
            connection.commit()
            
            # 獲取新創建的章節 ID
            return cursor.lastrowid
    except Exception as e:
        print(f"獲取或創建章節時出錯: {e}")
        connection.rollback()
        return 0

def get_or_create_knowledge_point(connection, chapter_id: int, section_data: Dict[str, Any], point_name: str) -> int:
    """獲取或創建知識點，返回知識點 ID"""
    try:
        with connection.cursor() as cursor:
            # 檢查知識點是否存在
            sql = """
            SELECT id FROM knowledge_points 
            WHERE section_name = %s AND point_name = %s
            """
            cursor.execute(sql, (section_data['section_name'], point_name))
            result = cursor.fetchone()
            
            if result:
                return result['id']
            
            # 創建新知識點
            sql = """
            INSERT INTO knowledge_points 
            (section_num, section_name, point_name, chapter_id) 
            VALUES (%s, %s, %s, %s)
            """
            cursor.execute(
                sql, 
                (
                    int(section_data['section_num']),
                    section_data['section_name'],
                    point_name,
                    chapter_id
                )
            )
            connection.commit()
            
            # 獲取新創建的知識點 ID
            return cursor.lastrowid
    except Exception as e:
        print(f"獲取或創建知識點時出錯: {e}")
        connection.rollback()
        return 0

def process_question(connection, knowledge_id: int, question_data: Dict[str, Any]):
    """處理單個題目：驗證並保存到數據庫"""
    try:
        # 使用三個模型驗證題目
        deepseek_result = verify_question_with_deepseek(question_data)
        gpt4_result = verify_question_with_o3mini(question_data)
        gemini_result = verify_question_with_gemini(question_data)
        
        deepseek_correct, deepseek_answer, _ = deepseek_result
        gpt4_correct, gpt4_answer, _ = gpt4_result
        gemini_correct, gemini_answer, _ = gemini_result
        
        # 如果三個模型都認為答案正確
        if deepseek_correct and gpt4_correct and gemini_correct:
            # 生成解釋並保存題目
            explanation = generate_explanation_with_o3mini(question_data)
            save_question_to_database(connection, knowledge_id, question_data, explanation)
            return True
        
        # 如果三個模型都給出相同的不同答案
        elif (not deepseek_correct and not gpt4_correct and not gemini_correct and
              deepseek_answer == gpt4_answer == gemini_answer and
              deepseek_answer in ["1", "2", "3", "4"]):
            
            # 修正答案
            question_data['answer'] = deepseek_answer
            
            # 生成解釋並保存題目
            explanation = generate_explanation_with_o3mini(question_data)
            save_question_to_database(connection, knowledge_id, question_data, explanation)
            return True
        
        # 其他情況：模型給出不同答案或認為題目有問題
        else:
            print(f"題目被捨棄: {question_data['question'][:30]}...")
            print(f"DeepSeek: 正確={deepseek_correct}, 答案={deepseek_answer}")
            print(f"o3mini: 正確={gpt4_correct}, 答案={gpt4_answer}")
            print(f"Gemini: 正確={gemini_correct}, 答案={gemini_answer}")
            return False
    except Exception as e:
        print(f"處理題目時出錯: {e}")
        return False

def process_section(subject: str, section_data: Dict[str, Any]):
    """處理單個小節的所有知識點和題目"""
    connection = None
    try:
        connection = get_db_connection()
        
        # 獲取或創建章節
        chapter_id = get_or_create_chapter(connection, subject, section_data)
        if not chapter_id:
            print(f"無法獲取或創建章節，跳過處理小節: {section_data['section_name']}")
            return
        
        # 獲取知識點列表
        knowledge_points = section_data['knowledge_points']
        print(f"小節 {section_data['section_name']} 包含 {len(knowledge_points)} 個知識點")
        
        # 使用 GPT-4o 分批生成題目
        questions_by_point = generate_questions_with_gpt4o(knowledge_points, section_data, batch_size=2)
        
        # 處理每個知識點
        for point_name, questions in questions_by_point.items():
            # 獲取或創建知識點
            knowledge_id = get_or_create_knowledge_point(connection, chapter_id, section_data, point_name)
            if not knowledge_id:
                print(f"無法獲取或創建知識點，跳過處理: {point_name}")
                continue
            
            print(f"處理知識點: {point_name} (ID: {knowledge_id})")
            
            # 處理該知識點的所有題目
            successful_questions = 0
            for question_data in questions:
                # 添加延遲以避免 API 限制
                time.sleep(1)
                
                if process_question(connection, knowledge_id, question_data):
                    successful_questions += 1
            
            print(f"知識點 {point_name} 成功保存 {successful_questions}/{len(questions)} 個題目")
    
    except Exception as e:
        print(f"處理小節時出錯: {e}")
    finally:
        if connection:
            connection.close()

def main():
    parser = argparse.ArgumentParser(description='從 CSV 生成題庫並存儲到數據庫')
    parser.add_argument('csv_file', help='輸入的 CSV 文件路徑')
    parser.add_argument('subject', help='學科名稱')
    args = parser.parse_args()
    
    # 讀取 CSV 數據
    sections_data = read_csv_data(args.csv_file)
    if not sections_data:
        print("沒有找到有效的小節數據，程序退出")
        return
    
    # 使用線程池處理多個小節
    with ThreadPoolExecutor(max_workers=1) as executor:  # 限制為 1 以避免 API 限制
        for section_data in sections_data:
            executor.submit(process_section, args.subject, section_data)
    
    print("所有小節處理完成")

if __name__ == "__main__":
    validate_env_vars()
    main()