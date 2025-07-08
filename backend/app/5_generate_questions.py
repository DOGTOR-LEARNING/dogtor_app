import csv
import os
import json
import time
import pymysql
import argparse
from concurrent.futures import ThreadPoolExecutor
from google.cloud import aiplatform
from google.auth import exceptions
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
try:
    # 嘗試初始化 AI Platform 客戶端
    aiplatform.init(project="dogtor-454402", location="us-central1")
    print("成功初始化AI平台客戶端")
except exceptions.DefaultCredentialsError:
    print("未能找到有效的認證。請檢查您的憑證設置。")
except Exception as e:
    print(f"發生錯誤: {e}")

gemini_client = OpenAI(
    api_key=os.getenv("GEMINI_API_KEY"),
    base_url="https://generativelanguage.googleapis.com/v1beta/openai/"
)

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
                port=5433,
                password=os.getenv('DB_PASSWORD'),
                database=os.getenv('DB_NAME'),
                unix_socket=f"/cloudsql/{os.getenv('INSTANCE_CONNECTION_NAME')}",
                cursorclass=pymysql.cursors.DictCursor
            )
        else:
            # 在本地環境中運行，使用 Cloud SQL Proxy
            connection = pymysql.connect(
                host=os.getenv('DB_HOST', '127.0.0.1'),
                port=int(os.getenv('DB_PORT', 5433)),
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
                if len(row) < 7:  # 確保行有足夠的列
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
                }
                sections_data.append(section_data)
        
        print(f"成功從 CSV 讀取 {len(sections_data)} 個小節數據")
        return sections_data
    except Exception as e:
        print(f"讀取 CSV 文件時出錯: {e}")
        return []

def load_reference_questions(sections_data: List[Dict[str, Any]], csv_file_path: str = "processing/question_knowledge_point_matching_results.csv") -> Dict[str, List[Dict[str, Any]]]:
    """從 question_knowledge_point_matching_results.csv 讀取參考題目，按知識點分組"""
    reference_questions = {}
    
    # 先從 sections_data 收集所有知識點
    all_knowledge_points = set()
    for section in sections_data:
        for kp in section['knowledge_points']:
            all_knowledge_points.add(kp)
    
    print(f"收集到 {len(all_knowledge_points)} 個知識點")
    print(f"知識點列表: {list(all_knowledge_points)[:10]}...")  # 只顯示前10個
    
    try:
        print(f"開始讀取參考題目文件: {csv_file_path}")
        
        # 檢查文件是否存在
        if not os.path.exists(csv_file_path):
            print(f"錯誤：參考題目文件不存在: {csv_file_path}")
            return {}
            
        with open(csv_file_path, 'r', encoding='utf-8') as file:
            reader = csv.DictReader(file)
            print(f"CSV 列名: {reader.fieldnames}")
            
            row_count = 0
            matched_count = 0
            
            for row in reader:
                try:
                    row_count += 1
                    if row_count % 1000 == 0:
                        print(f"已處理 {row_count} 行...")
                    
                    # 檢查必要的欄位是否存在
                    required_fields = ['matched_knowledge_point', 'question_text']
                    missing_fields = [field for field in required_fields if field not in row or not row[field]]
                    if missing_fields:
                        continue
                    
                    # 檢查這個題目的知識點是否在我們的知識點列表中
                    matched_kp = row['matched_knowledge_point'].strip()
                    if matched_kp in all_knowledge_points:
                        matched_count += 1
                        
                        if matched_kp not in reference_questions:
                            reference_questions[matched_kp] = []
                        
                        reference_questions[matched_kp].append({
                            "subject": row.get('subject', ''),
                            "chapter_name": row.get('chapter_name', ''),
                            "section_name": row.get('section_name', ''),
                            "question_text": row['question_text']
                        })
                        
                except Exception as row_error:
                    print(f"處理第 {row_count} 行時出錯: {row_error}")
                    continue
        
        print(f"成功載入 {len(reference_questions)} 個知識點的參考題目")
        print(f"總共處理了 {row_count} 行，其中 {matched_count} 行成功匹配")
        for kp, questions in reference_questions.items():
            print(f"  - {kp}: {len(questions)} 題")
        
        return reference_questions
        
    except Exception as e:
        print(f"載入參考題目時出錯: {e}")
        import traceback
        traceback.print_exc()
        return {}

def generate_questions_with_reference(knowledge_points: List[str], section_data: Dict[str, Any], reference_questions: Dict[str, List[Dict[str, Any]]], batch_size: int = 2) -> Dict[str, List[Dict[str, Any]]]:
    """使用 Gemini 2.5 Flash 參考現有題目為每個知識點生成題目，分批處理知識點"""
    all_questions = {}
    
    # 將知識點分成小批次
    for i in range(0, len(knowledge_points), batch_size):
        batch_points = knowledge_points[i:i+batch_size]
        print(f"[生成題目] 處理知識點批次 {i//batch_size + 1}/{(len(knowledge_points) + batch_size - 1)//batch_size}: {', '.join(batch_points)}")
        
        # 為每個知識點收集參考題目
        reference_text = ""
        for point in batch_points:
            if point in reference_questions:
                reference_text += f"\n\n【知識點：{point} 的參考題目】\n"
                for j, ref_q in enumerate(reference_questions[point], 1):  # 使用所有參考題目
                    reference_text += f"{j}. {ref_q['question_text']}\n"
            else:
                reference_text += f"\n\n【知識點：{point}】\n（沒有找到相關的參考題目，請根據知識點名稱和小節描述生成適當的題目）\n"
        
        # 構建提示
        prompt = f"""
你是一個專業的臺灣教育內容生成器。我需要你參考現有題目為以下教育內容生成選擇題：

年級: {section_data['year_grade']}
章節: {section_data['chapter_num']} {section_data['chapter_name']}
小節: {section_data['section_num']} {section_data['section_name']}

這個小節包含以下所有知識點:
{', '.join(section_data['knowledge_points'])}

在本次請求中，我需要你為以下知識點生成題目:
{', '.join(batch_points)}

參考題目如下：
{reference_text}

請為每個指定的知識點生成 15 道選擇題，要求：

1. **概念一致性**：生成的題目概念要跟參考題目一樣，涵蓋相同的知識點和概念範圍，概念一致即可，計算量不要太大，要可在短時間內檢驗學生觀念正確性，若參考題目不足時，請預測符合該年級程度該知識點的觀念
2. **題型要求**：題型可以是一般的選擇題，或是挖空格選出正確選項的挖空選擇題。每道題有 4 個選項，只有 1 個正確答案
3. **選項範圍**：選項內容不要超出參考題型的範圍，保持與參考題目相似的概念深度
4. **題目品質**：
   - 題目要清晰、準確，沒有歧義
   - 選項要合理，干擾項要有迷惑性
   - 正確答案必須是 1、2、3、4 中的一個數字
   - 適合該年級學生，計算量不要太大
5. **生活化元素**：可以適度加入生活化的元素，引起學生的學習興趣
6. **特色元素**：可以非常少量地加入一些有趣的選項，以激發學生探索題庫時的驚喜樂趣，但不要太多，以免影響題目的嚴肅性
7. **格式嚴謹**：如果有指數或是化學式，請直接使用上標或下標文字，不要用 '^' 或 '_' 符號，如：Fe₂O₃，不要 Fe2O3；或是 cm³，不要 cm3
8. **題型靈活**：題型描述可以靈活，各題型不要過於雷同
9. **題目圖**：數學相關題目可以用 markdown 呈現，題目與選項都可以，有需要圖片如果可以就用 markdown 畫，否則就不要出圖片題，出觀念即可，避免用文字描述數學圖形
10. **數學出法**：當觀念需要計算時，可以出算式挖空題，要求學生選出該填入的數字或是算式，主要是要驗證學生有沒有熟悉該觀念，盡量避免需要大量計算

請按照以下JSON格式返回：
{{
  "questions": [
    {{
      "knowledge_point": "知識點名稱",
      "question": "題目內容",
      "options": ["選項1", "選項2", "選項3", "選項4"],
      "answer": "正確答案的編號(1-4)"
    }},
    // 更多題目...
  ]
}}

請確保 JSON 格式正確，可以被直接解析。
"""

        try:
            print(f"[生成題目] 調用 Gemini 2.5 Flash API")
            
            # 使用 Gemini 2.5 Flash 生成題目
            response = gemini_client.chat.completions.create(
                model="gemini-2.5-flash",
                messages=[
                    {"role": "system", "content": "你是一個專業的臺灣教育題目生成器，專注於生成符合中學學生認知水平的選擇題，中文字一律用繁體中文，不要使用簡體中文。請參考提供的參考題目來生成概念一致但內容不同的新題目。"},
                    {"role": "user", "content": prompt}
                ],
                response_format={"type": "json_object"}
            )
            
            # 解析回應
            content = response.choices[0].message.content
            result = json.loads(content)
            
            # 處理生成的題目
            for question in result.get("questions", []):
                knowledge_point = question.get("knowledge_point", "")
                
                # 確保知識點存在於字典中
                if knowledge_point not in all_questions:
                    all_questions[knowledge_point] = []
                
                # 添加題目
                all_questions[knowledge_point].append({
                    "question": question.get("question", ""),
                    "options": question.get("options", []),
                    "answer": question.get("answer", "")
                })
            
            print(f"[生成題目] 成功為批次 {i//batch_size + 1} 生成 {len(result.get('questions', []))} 個題目")
            
        except Exception as e:
            print(f"[生成題目] 生成題目時出錯: {e}")
    
    # 打印生成的題目數量
    total_questions = sum(len(questions) for questions in all_questions.values())
    print(f"[生成題目] 總共為 {len(all_questions)} 個知識點生成了 {total_questions} 個題目")
    
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

請分析這道題目，如果題目有嚴重瑕疵，請只回答 "N"。
如果題目沒有嚴重瑕疵，請判斷給出的答案是否正確。
如果答案正確，請只回答 "Y"。
如果答案不正確，請只回答正確的選項編號（1、2、3 或 4）。
不要提供任何其他解釋或格式。
"""

        # 調用 DeepSeek Reasoner API
        response = deepseek_client.chat.completions.create(
            model="deepseek-chat",
            messages=[{"role": "user", "content": prompt}],
            temperature=0.1,
            max_tokens=10,  # 限制回應長度
        )
        
        # 解析回應
        content = response.choices[0].message.content.strip()
        content = content.strip('"')
        print("content deepseek:", content)
        # 判斷結果
        is_correct = False
        if content == "Y" or content == '\"Y\"':
            is_correct = True
        correct_answer = ""
        explanation = ""
        
        if not is_correct and content in ["1", "2", "3", "4"]:
            correct_answer = content

        if not is_correct and content == "N":
            explanation = "題目有嚴重瑕疵。"
        
        return is_correct, correct_answer, explanation
    except Exception as e:
        print(f"使用 DeepSeek 驗證題目時出錯: {e}")
        return False, "", ""

def verify_question_with_o3mini(question_data: Dict[str, Any]) -> Tuple[bool, str, str]:
    """使用 o4-mini 驗證題目"""
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

請分析這道題目，如果題目有嚴重瑕疵，請只回答 "N"。
如果題目沒有嚴重瑕疵，請判斷給出的答案是否正確。
如果答案正確，請只回答 "Y"。
如果答案不正確，請只回答正確的選項編號（1、2、3 或 4）。
不要提供任何其他解釋或格式。
"""

        # 調用 o4-mini API
        response = openai_client.chat.completions.create(
            model="o4-mini",
            messages=[{"role": "user", "content": prompt}],
        )
        
        # 解析回應
        content = response.choices[0].message.content.strip()
        content = content.strip('"')
        print("content o4-mini:", content)
        # 判斷結果
        is_correct = False
        if content == "Y" or content == '\"Y\"':
            is_correct = True
        correct_answer = ""
        explanation = ""
        
        if not is_correct and content in ["1", "2", "3", "4"]:
            correct_answer = content

        if not is_correct and content == "N":
            explanation = "題目有嚴重瑕疵。"
        
        return is_correct, correct_answer, explanation
    except Exception as e:
        print(f"使用 o4-mini 驗證題目時出錯: {e}")
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

請分析這道題目，如果題目有嚴重瑕疵，請只回答 "N"。
如果題目沒有嚴重瑕疵，請判斷給出的答案是否正確。
如果答案正確，請只回答 "Y"。
如果答案不正確，請只回答正確的選項編號（1、2、3 或 4）。
不要提供任何其他解釋或格式。
"""


        # 改用 Gemini 2.0 Flash 驗證題目
        response = gemini_client.chat.completions.create(
            model="gemini-2.0-flash",
            messages=[
                {"role": "user", "content": prompt}
            ]
        )
        
        content = response.choices[0].message.content.strip()
        content = content.strip('"')
        print("content gemini:", content)
        #print(content)
        
        #Bowen跑不起來的 vertexai
        #vertexai.init(project=os.getenv("GOOGLE_CLOUD_PROJECT"), location="us-central1")
        
        # 創建模型實例
        #model = GenerativeModel("gemini-2.0-flash")
        
        # 生成回應
        #response = model.generate_content(prompt)
        
        # 解析回應
        #content = response.text.strip()
        
        # 判斷結果
        is_correct = False
        if content == "Y" or content == '\"Y\"':
            is_correct = True
        correct_answer = ""
        explanation = ""
        
        if not is_correct and content in ["1", "2", "3", "4"]:
            correct_answer = content

        if not is_correct and content == "N":
            explanation = "題目有嚴重瑕疵。"
        
        return is_correct, correct_answer, explanation
    except Exception as e:
        print(f"使用 Gemini 驗證題目時出錯: {e}")
        return False, "", ""

def generate_explanation_with_o3mini(question_data: Dict[str, Any]) -> str:
    """使用 o4-mini 生成題目解釋"""
    try:
        prompt = f"""
請為以下選擇題生成清晰、簡短的解釋:

題目: {question_data['question']}
選項:
1. {question_data['options'][0]}
2. {question_data['options'][1]}
3. {question_data['options'][2]}
4. {question_data['options'][3]}
正確答案: {question_data['answer']}

請提供一個簡短但清楚的解釋，說明這題的主要觀念或是解題關鍵！
解釋應該有教育意義，幫助學生理解相關知識點，且中文字要是繁體中文，可以非常少量使用合適的 emoji 。
"""

        # 調用 Gemini 2.5 Flash API
        response = gemini_client.chat.completions.create(
            model="gemini-2.5-flash",  # 使用 Gemini 2.5 Flash
            messages=[{"role": "user", "content": prompt}],
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
                print(f"章節已存在，使用現有章節 ID: {result['id']}")
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
            chapter_id = cursor.lastrowid
            print(f"創建新章節，章節 ID: {chapter_id}")
            return chapter_id
            
    except Exception as e:
        print(f"獲取或創建章節時出錯: {e}")
        # 如果是重複鍵錯誤，再次嘗試獲取現有章節
        if "Duplicate entry" in str(e):
            try:
                with connection.cursor() as cursor:
                    sql = """
                    SELECT id FROM chapter_list 
                    WHERE subject = %s AND chapter_name = %s
                    """
                    cursor.execute(sql, (subject, section_data['chapter_name']))
                    result = cursor.fetchone()
                    if result:
                        print(f"檢測到重複，使用現有章節 ID: {result['id']}")
                        return result['id']
            except Exception as retry_error:
                print(f"重試獲取章節時出錯: {retry_error}")
        
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
                print(f"知識點已存在，使用現有知識點 ID: {result['id']}")
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
            knowledge_id = cursor.lastrowid
            print(f"創建新知識點，知識點 ID: {knowledge_id}")
            return knowledge_id
            
    except Exception as e:
        print(f"獲取或創建知識點時出錯: {e}")
        # 如果是重複鍵錯誤，再次嘗試獲取現有知識點
        if "Duplicate entry" in str(e):
            try:
                with connection.cursor() as cursor:
                    sql = """
                    SELECT id FROM knowledge_points 
                    WHERE section_name = %s AND point_name = %s
                    """
                    cursor.execute(sql, (section_data['section_name'], point_name))
                    result = cursor.fetchone()
                    if result:
                        print(f"檢測到重複，使用現有知識點 ID: {result['id']}")
                        return result['id']
            except Exception as retry_error:
                print(f"重試獲取知識點時出錯: {retry_error}")
        
        connection.rollback()
        return 0

def process_question(connection, knowledge_id: int, question_data: Dict[str, Any]):
    """處理單個題目：驗證並保存到數據庫"""
    try:
        
        print(f"  [驗證開始] 使用三個模型驗證題目")

        print("題目內容：")
        print()
        
        # 使用三個模型驗證題目
        print(f"  [驗證 1/3] 使用 DeepSeek 驗證")
        deepseek_result = verify_question_with_deepseek(question_data)
        print(f"  [驗證 2/3] 使用 o4-mini 驗證")
        gpt4_result = verify_question_with_o3mini(question_data)
        print(f"  [驗證 3/3] 使用 Gemini 驗證")
        gemini_result = verify_question_with_gemini(question_data)
        
        deepseek_correct, deepseek_answer, _ = deepseek_result
        gpt4_correct, gpt4_answer, _ = gpt4_result
        gemini_correct, gemini_answer, _ = gemini_result
        
        print(f"  [驗證結果] DeepSeek: {deepseek_correct}, o4-mini: {gpt4_correct}, Gemini: {gemini_correct}")
        
        # 如果三個模型都認為答案正確
        if deepseek_correct and gpt4_correct and gemini_correct:
            print(f"  [處理] 三個模型都認為答案正確，生成解釋")
            # 生成解釋並保存題目
            explanation = generate_explanation_with_o3mini(question_data)
            print(f"  [保存] 保存題目到數據庫")
            save_question_to_database(connection, knowledge_id, question_data, explanation)
            return True
        
        # 如果三個模型都給出相同的不同答案
        elif (not deepseek_correct and not gpt4_correct and not gemini_correct and
              deepseek_answer == gpt4_answer == gemini_answer and
              deepseek_answer in ["1", "2", "3", "4"]):
            
            print(f"  [處理] 三個模型都給出相同的另一個答案: {deepseek_answer}，修正答案")
            # 修正答案
            question_data['answer'] = deepseek_answer
            
            # 生成解釋並保存題目
            print(f"  [生成] Gemini 生成解釋")
            explanation = generate_explanation_with_o3mini(question_data)
            print(f"  [保存] 保存修正後的題目到數據庫")
            save_question_to_database(connection, knowledge_id, question_data, explanation)
            return True
        
        # 其他情況：模型給出不同答案或認為題目有問題
        else:
            print(f"  [捨棄] 題目被捨棄: {question_data['question']}...") #[:30]
            print(f"  [詳情] DeepSeek: 正確={deepseek_correct}, 答案={deepseek_answer}")
            print(f"  [詳情] o3mini: 正確={gpt4_correct}, 答案={gpt4_answer}")
            print(f"  [詳情] Gemini: 正確={gemini_correct}, 答案={gemini_answer}")
            return False
    except Exception as e:
        print(f"  [錯誤] 處理題目時出錯: {e}")
        return False

def process_section(subject: str, section_data: Dict[str, Any]) -> List[str]:
    """處理單個小節的所有知識點和題目"""
    connection = None
    log_details = []
    try:
        print(f"\n===== 開始處理小節: {section_data['section_name']} =====")
        connection = get_db_connection()
        
        # 獲取或創建章節
        print(f"[檢查點 1] 嘗試獲取或創建章節: {section_data['chapter_name']}")
        chapter_id = get_or_create_chapter(connection, subject, section_data)
        if not chapter_id:
            log_message = f"無法獲取或創建章節，跳過處理小節: {section_data['section_name']}"
            print(log_message)
            log_details.append(log_message)
            return log_details
        print(f"[檢查點 1 完成] 成功獲取章節 ID: {chapter_id}")
        
        # 獲取知識點列表
        knowledge_points = section_data['knowledge_points']
        print(f"[檢查點 2] 小節 {section_data['section_name']} 包含 {len(knowledge_points)} 個知識點")
        
        # 使用全局載入的參考題目
        print(f"[檢查點 2.5] 使用已載入的參考題目")
        global reference_questions
        
        # 使用 Gemini 2.5 Flash 參考現有題目生成題目
        print(f"[檢查點 3] 開始使用 Gemini 2.5 Flash 參考現有題目生成題目")
        questions_by_point = generate_questions_with_reference(knowledge_points, section_data, reference_questions, batch_size=2)
        print(f"[檢查點 3 完成] 成功生成 {sum(len(qs) for qs in questions_by_point.values())} 個題目")
        
        # 處理每個知識點
        for point_name, questions in questions_by_point.items():
            print(f"\n[檢查點 4] 開始處理知識點: {point_name}")
            # 獲取或創建知識點
            knowledge_id = get_or_create_knowledge_point(connection, chapter_id, section_data, point_name)
            if not knowledge_id:
                log_message = f"知識點 '{point_name}': 無法獲取或创建知識點ID，已跳過。"
                print(log_message)
                log_details.append(log_message)
                continue
            
            print(f"[檢查點 4.1] 成功獲取知識點 ID: {knowledge_id}")
            
            # 處理該知識點的所有題目
            successful_questions = 0
            total_generated = len(questions)

            if total_generated == 0:
                log_message = f"知識點 '{point_name}': 未生成任何題目。"
                print(f"[檢查點 4 完成] {log_message}")
                log_details.append(log_message)
                continue

            for i, question_data in enumerate(questions):
                print(f"[檢查點 4.2] 處理題目 {i+1}/{len(questions)}: {question_data['question']}...") #[:30]
                print("選項A:", question_data['options'][0])
                print("選項B:", question_data['options'][1])
                print("選項C:", question_data['options'][2])
                print("選項D:", question_data['options'][3])
                print("答案：", question_data['answer'])
                # 添加延遲以避免 API 限制
                time.sleep(1)
                
                if process_question(connection, knowledge_id, question_data):
                    successful_questions += 1
            
            log_message = f"知識點 '{point_name}': 成功保存 {successful_questions}/{total_generated} 個題目"
            print(f"[檢查點 4 完成] {log_message}")
            log_details.append(log_message)
    
    except Exception as e:
        print(f"處理小節時出錯: {e}")
        log_details.append(f"處理小節時出錯: {e}")
        raise # 重新拋出異常，以便上層函數可以捕獲並記錄為失敗
    finally:
        if connection:
            connection.close()
        print(f"===== 完成處理小節: {section_data['section_name']} =====\n")
    
    return log_details

def main():
    parser = argparse.ArgumentParser(description='從 CSV 生成題庫並存儲到數據庫')
    parser.add_argument('csv_file', help='輸入的 CSV 文件路徑')
    parser.add_argument('subject', help='學科名稱')
    parser.add_argument('--start', type=int, default=0, help='開始處理的小節索引 (從0開始)')
    parser.add_argument('--end', type=int, default=None, help='結束處理的小節索引 (不包含)')
    parser.add_argument('--skip-existing', action='store_true', help='跳過已存在章節的小節')
    parser.add_argument('--resume', action='store_true', help='從上次中斷的地方繼續')
    parser.add_argument('--log-file', default='processing_log.txt', help='處理日誌文件')
    args = parser.parse_args()
    
    # 讀取 CSV 數據
    sections_data = read_csv_data(args.csv_file)
    if not sections_data:
        print("沒有找到有效的小節數據，程序退出")
        return
    
    # 計算處理範圍
    total_sections = len(sections_data)
    start_idx = args.start
    end_idx = args.end if args.end is not None else total_sections
    
    # 確保範圍有效
    start_idx = max(0, min(start_idx, total_sections))
    end_idx = max(start_idx, min(end_idx, total_sections))
    
    print(f"總共 {total_sections} 個小節")
    print(f"將處理小節 {start_idx} 到 {end_idx-1} (共 {end_idx - start_idx} 個小節)")
    
    # 載入或創建處理日誌
    processed_sections = set()
    failed_sections = set()
    
    if args.resume and os.path.exists(args.log_file):
        print(f"讀取處理日誌: {args.log_file}")
        with open(args.log_file, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                if line.startswith('COMPLETED:'):
                    section_name = line.replace('COMPLETED:', '')
                    processed_sections.add(section_name)
                elif line.startswith('FAILED:'):
                    section_name = line.replace('FAILED:', '')
                    failed_sections.add(section_name)
        print(f"已完成: {len(processed_sections)} 個小節")
        print(f"失敗: {len(failed_sections)} 個小節")
    
    # 篩選需要處理的小節
    sections_to_process = []
    for i in range(start_idx, end_idx):
        section_data = sections_data[i]
        section_name = section_data['section_name']
        
        # 檢查是否要跳過已處理的小節
        if args.resume and section_name in processed_sections:
            print(f"跳過已完成的小節: {section_name}")
            continue
            
        sections_to_process.append((i, section_data))
    
    if not sections_to_process:
        print("沒有需要處理的小節")
        return
    
    print(f"實際需要處理: {len(sections_to_process)} 個小節")
    
    # 載入參考題目（傳遞所有小節數據以收集知識點）
    print("[初始化] 載入參考題目...")
    global reference_questions
    reference_questions = load_reference_questions(sections_data)
    
    # 處理小節
    def process_with_logging(section_info):
        idx, section_data = section_info
        section_name = section_data['section_name']
        try:
            print(f"\n[{idx+1}/{total_sections}] 開始處理: {section_name}")
            
            # 檢查是否要跳過已存在的章節
            if args.skip_existing:
                connection = get_db_connection()
                try:
                    with connection.cursor() as cursor:
                        sql = "SELECT id FROM chapter_list WHERE subject = %s AND chapter_name = %s"
                        cursor.execute(sql, (args.subject, section_data['chapter_name']))
                        if cursor.fetchone():
                            print(f"跳過已存在章節的小節: {section_name}")
                            with open(args.log_file, 'a', encoding='utf-8') as f:
                                f.write(f"SKIPPED:{section_name}\n")
                            return
                finally:
                    connection.close()
            
            # 處理小節
            log_details = process_section(args.subject, section_data)
            
            # 記錄成功
            with open(args.log_file, 'a', encoding='utf-8') as f:
                f.write(f"COMPLETED:{section_name}\n")
                for detail in log_details:
                    f.write(f"  - {detail}\n")
            
            print(f"[{idx+1}/{total_sections}] 完成處理: {section_name}")
            
        except Exception as e:
            print(f"[{idx+1}/{total_sections}] 處理失敗: {section_name}, 錯誤: {e}")
            with open(args.log_file, 'a', encoding='utf-8') as f:
                f.write(f"FAILED:{section_name}\n")
                f.write(f"  ERROR: {str(e)}\n")
    
    # 序列處理（避免 API 限制）
    for section_info in sections_to_process:
        process_with_logging(section_info)

if __name__ == "__main__":
    validate_env_vars()
    main()