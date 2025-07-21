# 題目知識點匹配程式使用說明

## 功能介紹

此程式使用 Gemini-2.5-Flash AI 模型來判斷 question bank 中的題目屬於哪個知識點。程式會自動：

1. 載入知識點清單和題庫資料
2. 對每道題目判斷是否需要跳過（如包含圖片相關內容）
3. 使用 AI 來匹配題目與對應的知識點
4. 即時儲存處理結果，支援斷點續傳
5. 生成處理結果和刪除建議報告

## 檔案說明

- `6_question_knowledge_point_matching.py` - 主程式檔案
- `question_knowledge_point_matching_results.csv` - 處理結果（即時更新）
- `questions_to_delete.txt` - 需要刪除的題目清單（執行後生成）

## 使用方式

### 1. 安裝必要套件

```bash
pip install pandas vertexai google-cloud-aiplatform
```

### 2. 設定環境變數

確保您的 Google Cloud 認證已正確設定：

```bash
export GOOGLE_APPLICATION_CREDENTIALS="path/to/your/service-account-key.json"
```

### 3. 執行程式

```bash
cd backend/app
python 6_question_knowledge_point_matching.py
```

## 斷點續傳功能

程式支援中斷和繼續處理：

1. **自動檢查進度**：
   - 啟動時會檢查是否有已處理的結果檔案
   - 自動載入已處理的結果
   - 只處理尚未處理的題目

2. **即時儲存**：
   - 每處理完一題就立即儲存結果
   - 不會遺失已處理的進度

3. **安全中斷**：
   - 可以使用 Ctrl+C 安全地中斷處理
   - 中斷時會保存當前進度
   - 下次執行時自動從中斷處繼續

## 程式處理邏輯

### 跳過條件

程式會跳過以下類型的題目：

1. **包含圖片相關內容的題目**
   - 關鍵詞：圖、圖片、圖表、示意圖、下圖、右圖、左圖、如圖、圖中、圖示、附圖
   
2. **題目內容太短的題目**
   - 少於 10 個字元的題目

### 知識點匹配流程

1. **根據章節和節次找到相關知識點**
   - 支援所有科目的題目
   - 使用模糊匹配來找到相關的知識點

2. **使用 Gemini AI 判斷**
   - 將題目內容和知識點清單傳給 AI
   - AI 從清單中選擇一個最相關的知識點
   - 如果無法匹配則回覆「無匹配」

3. **結果驗證**
   - 確保 AI 回覆的知識點在清單中
   - 支援模糊匹配來處理輕微的文字差異

## 輸出檔案說明

### 處理結果檔案 (question_knowledge_point_matching_results.csv)

包含以下欄位：
- `ques_no`: 題目編號
- `subject`: 科目
- `chapter_name`: 章節名稱
- `section_name`: 節次名稱
- `question_text`: 題目內容（前100字）
- `matched_knowledge_point`: 匹配到的知識點
- `status`: 處理狀態
- `reason`: 跳過或無法匹配的原因

### 狀態說明

- `matched`: 成功匹配到知識點
- `skipped`: 因包含圖片或內容太短而跳過
- `no_knowledge_points`: 找不到相關的知識點清單
- `no_match`: AI 判斷無匹配的知識點

### 刪除報告檔案 (questions_to_delete.txt)

按刪除原因分組列出需要刪除的題目編號，包括：
- 各種刪除原因
- 每個原因的題目數量
- 具體的題目編號清單
- 總計需要刪除的題目數

## 調整參數

### 批次大小

可以在 `main()` 函數中調整 `batch_size` 參數來控制 API 呼叫頻率：

```python
matcher.process_questions(batch_size=5)  # 每 5 題暫停一次
```

### API 重試次數

可以在 `call_gemini_api()` 方法中調整 `max_retries` 參數：

```python
matched_kp = self.call_gemini_api(question_text, knowledge_points, max_retries=3)
```

## 注意事項

1. **API 限制**：程式包含暫停機制以避免觸發 API 限制
2. **網路連線**：需要穩定的網路連線來呼叫 Gemini API
3. **處理時間**：6500+ 道題目可能需要數小時處理完成
4. **費用考量**：使用 Gemini API 可能產生費用，請注意用量
5. **中斷處理**：可以隨時使用 Ctrl+C 安全地中斷處理
6. **續傳功能**：重新執行程式時會自動從上次中斷處繼續

## 錯誤處理

程式包含完整的錯誤處理機制：
- API 呼叫失敗時自動重試
- 資料載入失敗時會顯示錯誤訊息
- 個別題目處理失敗不會影響整體進度
- 即時儲存確保不會遺失處理進度

## 建議使用流程

1. 先執行小批次測試（修改批次大小為較小值）
2. 檢查結果是否符合預期
3. 調整參數後執行完整批次
4. 如需中斷，使用 Ctrl+C 安全地停止處理
5. 需要時可以重新執行程式，會自動從中斷處繼續
6. 完成後檢查生成的刪除報告
7. 根據報告決定是否要刪除相應的題目 