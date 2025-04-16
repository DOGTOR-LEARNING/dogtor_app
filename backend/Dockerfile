# 使用輕量級 Python 映像
FROM python:3.10-slim

# 設定工作目錄
WORKDIR /app

# 首先複製 requirements.txt 以利用 Docker 的緩存機制
COPY requirements.txt .

# 安裝 pip 套件
RUN pip install --no-cache-dir -r requirements.txt

# 複製所有專案檔案到容器內
COPY . .

# 建立 Qpics 資料夾（避免容器啟動出錯）
RUN mkdir -p /app/Qpics

# 設定容器執行時的 Port
ENV PORT=8080
EXPOSE ${PORT}

# 使用 uvicorn 啟動應用
CMD exec uvicorn main:app --host 0.0.0.0 --port ${PORT} --timeout-keep-alive 75