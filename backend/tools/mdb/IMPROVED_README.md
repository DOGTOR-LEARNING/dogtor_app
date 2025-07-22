# 改進版 MDB to CSV 轉換器

## 新功能

### 1. 智慧 MIME 類型檢測
- 使用 `python-magic` 套件精確識別 Word 欄位中的檔案類型
- 支援 ZIP、文字檔、PDF、Word 文件、圖片等多種格式的自動識別

### 2. 進階 ZIP 解壓縮
- 自動偵測 ZIP 格式的壓縮資料
- 遞迴解壓縮 ZIP 檔案中的所有文字檔案
- 支援多種字元編碼 (UTF-8, Big5, GBK, CP1252, Latin1)
- 詳細記錄每個解壓縮檔案的資訊

### 3. 檔案保存功能
- 自動將 Word 欄位中的壓縮檔案另外保存
- 根據 MIME 類型自動分配正確的副檔名
- 統一存放在 `extracted_files` 目錄中
- 每個檔案都有唯一的命名規則：`{table_name}_{record_id}.{extension}`

### 4. 完善的錯誤處理
- 對於無法解析的檔案提供詳細的錯誤資訊
- 跳過損壞的 ZIP 檔案但繼續處理其他資料
- 記錄所有處理過程的詳細日誌

## 安裝需求

```bash
# macOS 系統依賴
brew install mdbtools libmagic

# Python 套件
pip3 install pandas tqdm chardet python-magic
```

## 使用方式

### 基本轉換
```bash
python3 mdb_to_csv_converter.py --input_dir ./hphy_mdbs --output_dir ./csv_output
```

### 進階選項
```bash
python3 mdb_to_csv_converter.py \
    --input_dir ./hphy_mdbs \
    --output_dir ./csv_output \
    --max_workers 2 \
    --chunk_size 5000
```

### 測試改進功能
```bash
python3 test_improved_converter.py
```

## 輸出結構

```
csv_output/
├── extracted_files/          # 解壓縮的檔案
│   ├── table1_row_1.zip
│   ├── table1_row_2.txt
│   └── table2_row_5.bin
├── pa1/                      # MDB 檔案對應的目錄
│   ├── Questions.csv
│   └── Metadata.csv
└── pa2/
    └── Questions.csv
```

## Word 欄位處理示例

### 輸入資料
Word 欄位包含壓縮的二進位資料

### 處理結果
```csv
Code,Word,LessonID
"Q001","[test.txt]: 這是解壓縮後的文字內容\n[readme.txt]: 說明檔案內容","L001"
"Q002","[二進位檔案: application/octet-stream, 1024 bytes]","L002"
"Q003","純文字內容 - 直接解碼","L003"
```

### 同時保存的檔案
- `extracted_files/Questions_row_1.zip` - 原始壓縮檔案
- `extracted_files/Questions_row_2.bin` - 二進位檔案  
- (純文字不另外保存)

## 轉換摘要示例

```
=== 轉換摘要 ===
總共產生 15 個 CSV 檔案
總大小: 25.3 MB
  📁 pa1: 3 個檔案, 8.2 MB
  📁 pa2: 5 個檔案, 12.1 MB
  📁 pa3WordAndPic: 7 個檔案, 5.0 MB

=== 解壓縮檔案摘要 ===
總共解壓縮 1247 個檔案
解壓縮檔案總大小: 156.8 MB
檔案類型分佈:
  .zip: 1024 個檔案
  .txt: 187 個檔案
  .bin: 36 個檔案
```

## 改進重點

1. **準確的檔案類型識別**：不再依賴檔案標頭猜測，使用 libmagic 精確識別
2. **完整的內容提取**：ZIP 檔案中的所有文字檔案都會被解壓縮和讀取
3. **原始檔案保存**：研究人員可以直接存取原始的壓縮檔案
4. **更好的中文支援**：支援多種中文編碼格式
5. **詳細的處理報告**：清楚了解每個檔案的處理結果

## 故障排除

### Magic 套件問題
```bash
# 如果出現 magic 相關錯誤
brew reinstall libmagic
pip3 uninstall python-magic
pip3 install python-magic
```

### 記憶體不足
```bash
# 減少併發數和分塊大小
python3 mdb_to_csv_converter.py --max_workers 1 --chunk_size 1000
```

### 編碼問題
轉換器會自動嘗試多種編碼，如果仍有問題，檢查原始 MDB 檔案的資料完整性。 