import os
import openai
import base64
from io import BytesIO
from pdf2image import convert_from_path
from PIL import Image
from dotenv import load_dotenv
from openai import OpenAI
from PIL import Image
import pytesseract


load_dotenv()

# 獲取環境變數
api_key = os.getenv("OPENAI_API_KEY")
print("api:", api_key)

# 設定 OpenAI API Key
openai.api_key = api_key

# 初始化 OpenAI 客戶端
client = OpenAI(api_key=api_key)

# 轉換 PDF 每一頁為圖片
pdf_path = "/Users/bowen/Desktop/NTU/Grade2-2/人工智慧/B12705014_hw1_written.pdf"
pdf_path = "/Users/bowen/Desktop/NTU/Grade2-2/DOGTOR/Dogtor_Database_Schema.pdf"
img_path = "/Users/bowen/Desktop/Screenshots/math_test.png"
#img_path = "/Users/bowen/Desktop/Screenshots/geography_test.png"
#img_path = "/Users/bowen/Desktop/Screenshots/big.png"
#img_path = "/Users/bowen/Desktop/Screenshots/three.png"
images = convert_from_path(pdf_path)

#img = Image.open(img_path)
#text = pytesseract.image_to_string(img, lang='eng')
#print(text)
# 將圖片轉換為 base64 格式
'''
def encode_image(image):
    buffered = BytesIO()
    image.save(buffered, format="PNG")
    return base64.b64encode(buffered.getvalue()).decode("utf-8")

# OCR 辨識每一頁文字
text = ""
for i, img in enumerate(images):
    print(f"Processing page {i+1}...")
    base64_image = encode_image(img)

    system_message = "你是一個 OCR 文字辨識助手，請幫我辨識圖片內的文字"

    response = client.chat.completions.create(
        model="gpt-4o", #gpt-4-vision-preview
        messages=[
            {"role": "system", "content": system_message},
            {"role": "user", "content": [
                {"type": "text", "text": f"請回傳圖片上的文字和數字"},
                {"type": "image_url", "image_url": {
                 "url": f"data:image/png;base64,{base64_image}"}
                }
            ]}
        ],
        max_tokens=4096
    )

    page_text = response.choices[0].message.content
    text += f"\n--- Page {i+1} ---\n" + page_text

# 顯示或儲存結果
print("-------辨識結果--------")
print(text)

# 存成文字檔
with open("output_openai.txt", "w", encoding="utf-8") as f:
    f.write(text)
'''

import tiktoken

# 使用 GPT-4 的 tokenizer
enc = tiktoken.get_encoding("cl100k_base")  # GPT-4 使用 "cl100k_base" 编码



def encode_image(image_path):
    with open(image_path, "rb") as img_file:  # 读取图片为字节流
        img_bytes = img_file.read()
    return base64.b64encode(img_bytes).decode("utf-8")  # 编码为 base64 字符串

base64_image = encode_image(img_path)

tokens = enc.encode(base64_image)

print(f"Token count: {len(tokens)}")

response = client.chat.completions.create(
        model="gpt-4o", #gpt-4-vision-preview
        messages=[
            {"role": "system", "content": "你是一個 OCR 文字辨識助手，請幫我辨識圖片內的文字"},
            {"role": "user", 
            "content": [
                {"type": "text", "text": "請回傳圖片上的文字和數字"},
                {"type": "image_url", 
                 "image_url": {
                    "url": f"data:image/png;base64,{base64_image}"
                 }
                }
            ]}
        ],
        max_tokens=4096
    )

print("response", response.choices[0].message.content)
