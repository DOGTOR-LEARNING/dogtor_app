from google.auth import exceptions
from google.cloud import aiplatform

try:
    # 嘗試初始化 AI Platform 客戶端
    aiplatform.init(project="dogtor-454402", location="us-central1")
    print("成功初始化AI平台客戶端")
except exceptions.DefaultCredentialsError:
    print("未能找到有效的認證。請檢查您的憑證設置。")
except Exception as e:
    print(f"發生錯誤: {e}")