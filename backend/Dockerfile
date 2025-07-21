# 使用輕量級 Python 映像
FROM python:3.10-slim

# 設定 container 內的工作目錄
WORKDIR /app

# 安裝 Python 套件
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 複製 app 目錄下所有檔案到 container /app
COPY ./app/ /app/

# 設定環境變數與暴露 port
ENV PORT=8080
EXPOSE ${PORT}

# 設定 PYTHONPATH
ENV PYTHONPATH=/app

# 啟動 FastAPI
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]