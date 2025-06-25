import os
import google.generativeai as genai
import pandas as pd
from dotenv import load_dotenv
import time

load_dotenv()

# 獲取環境變數
api_key = os.getenv("GEMINI_API_KEY")

# 設定 Google API Key
genai.configure(api_key=api_key)

# 初始化 Gemini 客戶端
model = genai.GenerativeModel('gemini-2.5-flash')

# 定義檔案路徑
sections_path = "processing/jun_science.xlsx"
questions_path = "processing/question_bank.csv"
output_path = "processing/knowledge_points_output.csv"

# 更新系統訊息，要求生成3-7個知識點
system_message = "請根據以下屬於同一個小節的題目，請從這些題目中大致歸納出3到7個重要的、出現頻率高的知識點，知識點只需要是名詞，不需要解釋，知識點名詞要具有高度辨識度，可以明確表達這個知識點所代表的知識，如：生命現象，就可以知道這個知識點會涵蓋生長、生殖、感應、代謝，但也請注意不要過度分類，如：實驗儀器、實驗器材是類似概念，顯微鏡構造、顯微鏡分類等可以統整成一個顯微鏡的類型與構造。請用頓號「、」分隔知識點。請只回傳知識點，不要有任何其他文字或換行符號。"

# 讀取資料
try:
    sections_df = pd.read_excel(sections_path)
    questions_df = pd.read_csv(questions_path)
except FileNotFoundError as e:
    print(f"錯誤：找不到檔案 {e.filename}")
    exit()

# 準備寫入新的CSV檔案
output_columns = list(sections_df.columns) + ['generated_knowledge_points']
output_df = pd.DataFrame(columns=output_columns)

# 逐一處理每個小節
for index, section_row in sections_df.iterrows():
    section_name = section_row['section_name']
    
    # 篩選出符合當前小節名稱的題目
    related_questions = questions_df[questions_df['section name'] == section_name]
    
    if related_questions.empty:
        print(f"在題庫中找不到關於 '{section_name}' 的題目，跳過。")
        continue
    
    # 將所有相關題目的內容合併成一個字串
    # 我們假設題目內容在 'question' 欄位，如果不是請修改
    questions_text = " ".join(related_questions['ques_detl'].astype(str))
    
    print(f"正在為 '{section_name}' 生成知識點...")
    
    try:
        # 組合完整的 prompt
        prompt = f"{system_message}\n\n{questions_text}"
        
        response = model.generate_content(prompt)
        
        knowledge_points = response.text.strip()
        print(f"成功生成知識點：{knowledge_points}")
        
        # 將結果加入新的 row
        new_row = section_row.to_dict()
        new_row['generated_knowledge_points'] = knowledge_points
        
        # 將 new_row 轉為 DataFrame 再進行 concat
        new_row_df = pd.DataFrame([new_row])
        output_df = pd.concat([output_df, new_row_df], ignore_index=True)

    except Exception as e:
        print(f"為 '{section_name}' 生成知識點時發生錯誤: {e}")
        # 如果需要，可以在這裡加入錯誤處理邏輯，例如重試
    
    # 為了避免觸發API頻率限制，可以加入短暫延遲
    time.sleep(1)

# 將最終結果儲存到CSV檔案
output_df.to_csv(output_path, index=False, encoding='utf-8-sig')

print(f"\n處理完成！知識點已成功存入 {output_path}")

