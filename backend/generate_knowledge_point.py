import os
import openai
import base64
from io import BytesIO
from PIL import Image
from dotenv import load_dotenv
from openai import OpenAI
from PIL import Image

import csv

load_dotenv()

# 獲取環境變數
api_key = os.getenv("OPENAI_API_KEY")
print("api:", api_key)

# 設定 OpenAI API Key
openai.api_key = api_key

# 初始化 OpenAI 客戶端
client = OpenAI(api_key=api_key)

path = "/Users/bowen/Desktop/NTU/Grade2-2/DOGTOR/國中社會科題庫-公民.csv"

system_message = "['num', 'year_grade', 'book', 'chapter_num', 'chapter_name', 'section_num', 'section_name', 'knowledge_points', 'section_summary'] 請針對輸入的範圍資訊找出2個重要的知識點（以頓號分隔），並整理一段 200 字的小節大綱介紹，概括整節內容，不用換行；請回傳繁體字，回傳格式嚴格遵守csv格式：知識點,小節大綱，其中csv的分隔逗號請使用半形符號，並且前後都不要有換行符號"

user_message = ""

text = ""

i = 0

with open(path, newline='', encoding='utf-8') as csvfile:
    
    reader = csv.reader(csvfile)
    for row in reader:
        #if i == 0:
        #    continue
        #print(row)  # 每次讀取一行
        line = ','.join(row)
        #print(line)
        user_message = line
        response = client.chat.completions.create(
            model="gpt-4o", #gpt-4-vision-preview
            messages=[
                {"role": "system", "content": system_message},
                {"role": "user", "content": [
                    {"type": "text", "text": user_message},
                ]}
            ],
            max_tokens=4096
        )

        print(response.choices[0].message.content)
        text += line[:-1]
        text += response.choices[0].message.content
        text += "\n"

        i += 1

with open("output.csv", "w", encoding="utf-8") as file:
    file.write(text)

print("文字已成功存入 output.csv")

