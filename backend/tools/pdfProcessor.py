import os
from PyPDF2 import PdfReader

# 設定PDF檔案所在的資料夾
pdf_folder = "/Users/bowen/Desktop/NTU/Grade2-2/DOGTOR/國二社會"

# 瀏覽資料夾內的所有PDF檔案
for filename in os.listdir(pdf_folder):
    if filename.endswith(".pdf"):
        pdf_path = os.path.join(pdf_folder, filename)
        
        # 讀取PDF檔案
        with open(pdf_path, "rb") as file:
            reader = PdfReader(file)
            text = ""
            
            # 讀取每一頁的內容
            for page in reader.pages:
                text += page.extract_text()
                
            print(f"內容來自檔案：{filename}")
            print(text[:500])  # 輸出前500個字元來檢查
            print("-" * 80)
