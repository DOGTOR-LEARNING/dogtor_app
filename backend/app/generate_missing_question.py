import os
import json
import time
import pymysql
import argparse
from openai import OpenAI
from google.cloud import aiplatform
from typing import List, Dict, Any, Tuple
from vertexai.generative_models import GenerativeModel
import vertexai
from dotenv import load_dotenv

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
        raise

def find_knowledge_points_with_few_questions(connection, min_questions=12) -> List[Dict[str, Any]]:
    """找出題目數量少於指定數量的知識點"""
    try:
        with connection.cursor() as cursor:
            # 查詢每個知識點的題目數量
            sql = """
            SELECT 
                kp.id AS knowledge_id, 
                kp.point_name AS knowledge_name,
                kp.section_name,
                cl.subject,
                cl.year_grade,
                cl.book,
                cl.chapter_num,
                cl.chapter_name,
                COUNT(q.id) AS question_count
            FROM 
                knowledge_points kp
            JOIN 
                chapter_list cl ON kp.chapter_id = cl.id
            LEFT JOIN 
                questions q ON kp.id = q.knowledge_id
            GROUP BY 
                kp.id
            HAVING 
                COUNT(q.id) < %s
            ORDER BY 
                cl.subject, cl.year_grade, cl.book, cl.chapter_num, kp.section_num, kp.id
            """
            cursor.execute(sql, (min_questions,))
            results = cursor.fetchall()
            
            print(f"找到 {len(results)} 個題目數量少於 {min_questions} 的知識點")
            return results
    except Exception as e:
        print(f"查詢知識點時出錯: {e}")
        return []

def generate_questions_for_knowledge_point(knowledge_info: Dict[str, Any], needed_count: int) -> List[Dict[str, Any]]:
    """為指定知識點生成題目"""
    try:
        print(f"[生成題目] 為知識點 {knowledge_info['knowledge_name']} 生成 {needed_count} 個題目")
        
        # 構建小節數據
        section_data = {
            'year_grade': knowledge_info['year_grade'],
            'book': knowledge_info['book'],
            'chapter_num': knowledge_info['chapter_num'],
            'chapter_name': knowledge_info['chapter_name'],
            'section_num': 1,  # 默認值
            'section_name': knowledge_info['section_name'],
            'description': f"包含知識點: {knowledge_info['knowledge_name']}",
            'knowledge_points': [knowledge_info['knowledge_name']]  # 只包含當前知識點
        }
        
        # 使用現有函數生成題目
        questions_by_point = generate_questions_with_gpt4o([knowledge_info['knowledge_name']], section_data, batch_size=1)
        
        # 獲取生成的題目
        questions = questions_by_point.get(knowledge_info['knowledge_name'], [])
        
        # 如果生成的題目不夠，可能需要多次調用
        while len(questions) < needed_count:
            print(f"[生成題目] 已生成 {len(questions)} 題，還需要 {needed_count - len(questions)} 題")
            more_questions = generate_questions_with_gpt4o([knowledge_info['knowledge_name']], section_data, batch_size=1)
            new_questions = more_questions.get(knowledge_info['knowledge_name'], [])
            if not new_questions:
                break  # 如果無法生成更多題目，則退出循環
            questions.extend(new_questions)
        
        # 限制題目數量
        return questions[:needed_count]
    except Exception as e:
        print(f"[生成題目] 生成題目時出錯: {e}")
        return []

def generate_questions_with_gpt4o(knowledge_points: List[str], section_data: Dict[str, Any], batch_size: int = 2) -> Dict[str, List[Dict[str, Any]]]:
    """使用 GPT-4o 為每個知識點生成題目，分批處理知識點"""
    all_questions = {}
    
    # 將知識點分成小批次
    for i in range(0, len(knowledge_points), batch_size):
        batch_points = knowledge_points[i:i+batch_size]
        print(f"[生成題目] 處理知識點批次 {i//batch_size + 1}/{(len(knowledge_points) + batch_size - 1)//batch_size}: {', '.join(batch_points)}")
        
        # 構建提示
        prompt = f"""
你是一個專業的臺灣教育內容生成器。我需要你為以下教育內容生成選擇題：

年級: {section_data['year_grade']}
冊數: {section_data['book']}
章節: {section_data['chapter_num']} {section_data['chapter_name']}
小節: {section_data['section_num']} {section_data['section_name']}
小節概述: {section_data['description']}

這個小節包含以下所有知識點:
{', '.join(section_data['knowledge_points'])}

但在本次請求中，我只需要你為以下知識點生成題目:
{', '.join(batch_points)}

請為每個指定的知識點生成3道選擇題，題型可以是一般的選擇題，或是挖空格選出正確選項的挖空選擇題。每道題有 4 個選項，只有 1 個正確答案。

要求:
1. 題目難度可以有挑戰性，但要適合該年級學生
2. 題目要清晰、準確，沒有歧義
3. 選項要合理，干擾項要有迷惑性
4. 正確答案必須是 1、2、3、4 中的一個數字
5. 題目是偏向觀念理解、記憶、應用，計算量不要太大
6. 題目要能夠引起學生的學習興趣，可以適度加入生活化的元素
7. 可以非常少量地加入一些有趣的選項，以激發學生探索題庫時的驚喜樂趣，但不要多，以免影響題目的嚴肅性
8. 題目可以很少量地加入合適的 emoji ，讓題目看起來避免太過生硬

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
            print(f"[生成題目] 調用 GPT-4o API")
            # 調用 GPT-4o API
            response = openai_client.chat.completions.create(
                model="gpt-4o",
                messages=[
                    {"role": "system", "content": "你是一個專業的臺灣教育題目生成器，專注於生成符合中學學生認知水平的選擇題，中文字一律用繁體中文，不要使用簡體中文。"},
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

def verify_question(question_data: Dict[str, Any]) -> Tuple[bool, str, str]:
    """驗證題目的正確性，要求三個模型都檢查正確才返回正確"""
    # 嘗試使用不同的模型進行驗證
    models = [
        ("DeepSeek", verify_question_with_deepseek),
        ("o3-mini", verify_question_with_o3mini),
        ("Gemini", verify_question_with_gemini)
    ]
    
    all_results = []
    
    for model_name, verify_func in models:
        try:
            print(f"使用 {model_name} 驗證題目...")
            is_correct, correct_answer, explanation = verify_func(question_data)
            
            print(f"{model_name} 驗證結果: {'正確' if is_correct else '不正確，正確答案為 ' + correct_answer}")
            all_results.append((is_correct, correct_answer, explanation))
        except Exception as e:
            print(f"{model_name} 驗證出錯: {e}")
            # 如果有模型出錯，視為驗證失敗
            all_results.append((False, "", ""))
    
    # 檢查是否所有模型都認為答案正確
    if all(result[0] for result in all_results):
        print("所有模型都認為答案正確")
        return True, question_data['answer'], ""
    
    # 如果有任何模型認為答案不正確，返回不正確
    print("至少有一個模型認為答案不正確，題目被拒絕")
    return False, "", ""

def verify_question_with_deepseek(question_data: Dict[str, Any]) -> Tuple[bool, str, str]:
    """使用 DeepSeek 驗證題目"""
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
            model="deepseek-chat",
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


        vertexai.init(project=os.getenv("GOOGLE_CLOUD_PROJECT"), location="us-central1")
        
        # 創建模型實例
        model = GenerativeModel("gemini-2.0-flash")
        
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
請以臺灣中學學習助手的口吻為以下選擇題生成清晰、簡短的解釋:

題目: {question_data['question']}
選項:
1. {question_data['options'][0]}
2. {question_data['options'][1]}
3. {question_data['options'][2]}
4. {question_data['options'][3]}
正確答案: {question_data['answer']}

請提供一個清晰、簡潔的解釋，簡單幾句話告訴這位同學為什麼這個答案是正確的，又或是為什麼其他選項不正確。
解釋應該有教育意義，幫助學生理解相關知識點，且中文字要是繁體中文，如果非常合適的話，可以很少量的使用 emoji 。
"""

        # 調用 o3-mini API
        response = openai_client.chat.completions.create(
            model="o3-mini",  # 改為使用 o3-mini
            messages=[{"role": "user", "content": prompt}],
        )
        
        # 獲取解釋
        explanation = response.choices[0].message.content
        return explanation
    except Exception as e:
        print(f"生成題目解釋時出錯: {e}")
        return "無法生成解釋。"

def generate_explanation(question_data: Dict[str, Any]) -> str:
    """生成題目解釋"""
    try:
        # 嘗試使用 o3-mini 生成解釋
        explanation = generate_explanation_with_o3mini(question_data)
        if explanation and explanation != "無法生成解釋。":
            return explanation
    except Exception as e:
        print(f"使用 o3-mini 生成解釋時出錯: {e}")
    
    # 如果 o3-mini 失敗，返回默認解釋
    return "無法生成解釋。"

def save_question_to_database(connection, knowledge_id: int, question_data: Dict[str, Any], explanation: str) -> bool:
    """將題目保存到數據庫"""
    try:
        with connection.cursor() as cursor:
            # 檢查題目是否已存在
            check_sql = """
            SELECT id FROM questions 
            WHERE knowledge_id = %s AND question_text = %s
            """
            cursor.execute(check_sql, (knowledge_id, question_data['question']))
            if cursor.fetchone():
                print(f"題目已存在: {question_data['question'][:30]}...")
                return False
            
            # 插入新題目
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

def process_knowledge_point(connection, knowledge_info: Dict[str, Any], min_questions: int):
    """處理單個知識點，生成並保存題目"""
    try:
        knowledge_id = knowledge_info['knowledge_id']
        current_count = knowledge_info['question_count']
        needed_count = min_questions - current_count
        
        print(f"\n處理知識點: {knowledge_info['knowledge_name']} (ID: {knowledge_id})")
        print(f"當前題目數量: {current_count}, 需要生成: {needed_count}")
        
        if needed_count <= 0:
            print("已有足夠題目，跳過")
            return
        
        # 生成題目
        questions = generate_questions_for_knowledge_point(knowledge_info, needed_count)
        
        # 處理每個題目
        saved_count = 0
        for question in questions:
            # 驗證題目 - 要求三個模型都檢查正確
            is_correct, correct_answer, _ = verify_question(question)
            
            if is_correct:
                # 生成解釋
                explanation = generate_explanation(question)
                
                # 保存題目
                if save_question_to_database(connection, knowledge_id, question, explanation):
                    saved_count += 1
            else:
                print(f"題目被捨棄: {question['question'][:30]}...")
        
        print(f"知識點 {knowledge_info['knowledge_name']} 成功保存 {saved_count}/{len(questions)} 個新題目")
        
    except Exception as e:
        print(f"處理知識點時出錯: {e}")

def main():
    parser = argparse.ArgumentParser(description='為題目數量不足的知識點生成更多題目')
    parser.add_argument('--min', type=int, default=12, help='每個知識點的最小題目數量')
    parser.add_argument('--subject', type=str, help='指定學科（可選）')
    parser.add_argument('--limit', type=int, default=None, help='處理的知識點數量上限（可選）')
    args = parser.parse_args()
    
    try:
        # 連接數據庫
        connection = get_db_connection()
        
        # 查找題目數量不足的知識點
        knowledge_points = find_knowledge_points_with_few_questions(connection, args.min)
        
        if args.subject:
            # 過濾指定學科的知識點
            knowledge_points = [kp for kp in knowledge_points if kp['subject'] == args.subject]
            print(f"過濾後剩餘 {len(knowledge_points)} 個 {args.subject} 學科的知識點")
        
        # 限制處理的知識點數量
        if args.limit and args.limit > 0:
            knowledge_points = knowledge_points[:args.limit]
            print(f"限制處理前 {args.limit} 個知識點")
        
        # 處理每個知識點
        for i, knowledge_info in enumerate(knowledge_points):
            print(f"\n處理進度: {i+1}/{len(knowledge_points)}")
            process_knowledge_point(connection, knowledge_info, args.min)
            
            # 每處理 5 個知識點暫停一下，避免 API 限制
            if (i + 1) % 5 == 0 and i < len(knowledge_points) - 1:
                print("暫停 30 秒...")
                time.sleep(30)
        
        print("\n所有知識點處理完成")
    
    except Exception as e:
        print(f"程序執行出錯: {e}")
    
    finally:
        # 關閉數據庫連接
        if 'connection' in locals() and connection:
            connection.close()

if __name__ == "__main__":
    main()