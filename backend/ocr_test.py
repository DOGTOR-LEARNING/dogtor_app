import pytesseract
from pdf2image import convert_from_path
from PIL import Image
import base64

# 設定 Tesseract 路徑
pytesseract.pytesseract.tesseract_cmd = "/opt/homebrew/bin/tesseract"

# 轉換 PDF 每一頁為圖片
#pdf_path = "/Users/bowen/Desktop/NTU/Grade2-2/DOGTOR/國二社會/5.112上康軒社會2上A卷_答案.pdf"
#pdf_path = "/Users/bowen/Desktop/NTU/Grade2-2/DOGTOR/Dogtor_Database_Schema.pdf"
pdf_path = "/Users/bowen/Desktop/NTU/Grade2-2/人工智慧/B12705014_hw1_written.pdf"
img_path = "/Users/bowen/Desktop/Screenshots/small.png"

#pdf_path = "/Users/bowen/Downloads/hello2.pdf"

'''
def encode_image(image_path):
    with open(image_path, "rb") as img_file:  # 读取图片为字节流
        img_bytes = img_file.read()
    return base64.b64encode(img_bytes).decode("utf-8")  # 编码为 base64 字符串

img = encode_image(img_path)

#img = img.resize((img.width // 4, img.height // 4))  # 縮小圖片大小

text = pytesseract.image_to_string(img, lang="chi_tra")  # 繁體中文OCR
print("-----辨識結果--------")
print(text)
'''

images = convert_from_path(pdf_path)
print("images:", images)
# OCR 辨識每一頁文字
text = ""
for i, img in enumerate(images):
    print("hi, page", i)
    page_text = pytesseract.image_to_string(img, lang="eng")  # 繁體中文OCR chi_tra
    text += f"\n--- Page {i+1} ---\n" + page_text

# 顯示或儲存結果
print(text)

# 存成文字檔
with open("output.txt", "w", encoding="utf-8") as f:
    f.write(text)
