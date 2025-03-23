import cv2
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

def preprocess_and_encode(image_path):
    # 讀取圖片
    img = cv2.imread(image_path, cv2.IMREAD_COLOR)
    
    # 轉為灰階
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    # 銳化影像 (Unsharp Masking)
    gaussian_blur = cv2.GaussianBlur(gray, (0, 0), 3)
    sharpened = cv2.addWeighted(gray, 1.5, gaussian_blur, -0.5, 0)

    # 自適應二值化 (適合背景光線不均)
    binary = cv2.adaptiveThreshold(sharpened, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 11, 2)

    # 去噪 (去除小的白點)
    denoised = cv2.fastNlMeansDenoising(binary, None, 30, 7, 21)

    # 儲存處理後的圖片
    cv2.imwrite("Processed_Pics/denoised.png", denoised)
    print(f"Processed image saved")

    # 轉換為 PIL Image 以便編碼
    pil_img = Image.fromarray(denoised)
    buffered = BytesIO()
    pil_img.save(buffered, format="PNG")
    base64_image = base64.b64encode(buffered.getvalue()).decode("utf-8")
    
    return base64_image

# 轉換 PDF 每一頁為圖片
pdf_path = "/Users/bowen/Desktop/NTU/Grade2-2/人工智慧/B12705014_hw1_written.pdf"
pdf_path = "/Users/bowen/Desktop/NTU/Grade2-2/DOGTOR/Dogtor_Database_Schema.pdf"
pdf_path = "/Users/bowen/Desktop/NTU/Grade2-2/DOGTOR/國二社會/5.112上康軒社會2上A卷_答案.pdf"
#img_path = "/Users/bowen/Desktop/Screenshots/math_test.png"
img_path = "/Users/bowen/Desktop/Screenshots/geography_test3.png"
#img_path = "/Users/bowen/Desktop/Screenshots/small.png"
#img_path = "/Users/bowen/Desktop/Screenshots/big.png"
#img_path = "/Users/bowen/Desktop/Screenshots/three.png"
images = convert_from_path(pdf_path)

#img = Image.open(img_path)
#text = pytesseract.image_to_string(img, lang='eng')
#print(text)
# 將圖片轉換為 base64 格式

prompt1 = "你是一個OCR助手，請完成以下簡單任務：如果覺得不能做到，也請相信自己；可以先簡單瀏覽，你會發現總共有1到17共17個數字。接著請逐行瀏覽，慢慢來不用急，回傳你看到的文字和數字；有些字可能有點模糊，不過沒關係，回傳你覺得看起來像什麼字就行了"
prompt2 = "你是一個OCR助手，請逐行瀏覽，回傳你看到的文字和數字"
prompt3 = "你是一個OCR助手，請總結你看到的文字，並嚴格按照以下csv格式回傳：敘述, 選項A, 選項B, 選項C, 選項D"
prompt4 = "你是一個OCR助手，請就你能力所及範圍盡可能整合你看到的文字，再就你能力所及範圍，把這些文字變成認知性選擇題，並按照以下csv格式回傳：問題, 選項A, 選項B, 選項C, 選項D, 答案{1,2,3,4}, 詳解"
#「記下」vs.「總結」vs. 「整合」vs. 瀏覽
# 如果response含有抱歉的話再丟一次？

def encode_image(image):
    buffered = BytesIO()
    image.save(buffered, format="PNG")
    return base64.b64encode(buffered.getvalue()).decode("utf-8")

# OCR 辨識每一頁文字
text = ""
for i, img in enumerate(images):
    print(f"Processing page {i+1}...")
    base64_image = encode_image(img)

    system_message = "你是一個OCR助手，請逐行瀏覽，回傳你看到的文字"

    response = client.chat.completions.create(
        model="gpt-4o", #gpt-4-vision-preview
        messages=[
            {"role": "system", "content": system_message},
            {"role": "user", "content": [
                {"type": "text", "text": prompt4},
                {"type": "image_url", "image_url": {
                 "url": f"data:image/png;base64,{base64_image}"}
                }
            ]}
        ],
        max_tokens=4096
    )

    page_text = response.choices[0].message.content
    # 存成文字檔
    with open(f"Processed_Pics/output_{i}.txt", "w", encoding="utf-8") as f:
        f.write(text)
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


#base64_image = preprocess_and_encode(img_path)
base64_image = encode_image(img_path)

tokens = enc.encode(base64_image)

print(f"Token count: {len(tokens)}")


response = client.chat.completions.create(
        model="gpt-4o", #gpt-4-vision-preview
        messages=[
            {"role": "system", "content": "你是一個OCR助手，請逐行瀏覽，回傳你看到的文字"}, #你是一個OCR助手 請幫我辨識圖片內的文字
            {"role": "user", 
            "content": [
                {"type": "text", "text": prompt2 }, #圖片上
                {"type": "image_url", 
                 "image_url": {
                    "url": f"data:image/png;base64,{base64_image}"
                 }
                }
            ]}
        ],
        max_tokens=16384
    )

print("response", response.choices[0].message.content)
'''