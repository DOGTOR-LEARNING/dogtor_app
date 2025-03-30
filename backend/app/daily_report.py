import smtplib
from email.mime.text import MIMEText
from datetime import datetime, timedelta
import requests
from dotenv import load_dotenv
import os

# === 填入資訊 ===
load_dotenv()
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
DEEPSEEK_API_KEY = os.getenv("DEEPSEEK_API_KEY")
GMAIL_ADDRESS = os.getenv("GMAIL_ADDRESS")
APP_PASSWORD = os.getenv("APP_PASSWORD")
RECEIVERS = os.getenv("RECEIVERS").split(",")

# === 查詢 OpenAI 使用量 ===
def get_openai_usage():
    headers = {"Authorization": f"Bearer {OPENAI_API_KEY}"}
    today = datetime.now(datetime.UTC).date()
    yesterday = today - timedelta(days=1)
    start_of_month = today.replace(day=1)
    
    # 獲取當月總使用量
    monthly_url = f"https://api.openai.com/v1/dashboard/billing/usage?start_date={start_of_month}&end_date={today + timedelta(days=1)}"
    monthly_res = requests.get(monthly_url, headers=headers)
    monthly_usage = monthly_res.json().get("total_usage", 0) / 100
    
    # 獲取昨天的使用量
    daily_url = f"https://api.openai.com/v1/dashboard/billing/usage?start_date={yesterday}&end_date={today}"
    daily_res = requests.get(daily_url, headers=headers)
    daily_usage = daily_res.json().get("total_usage", 0) / 100
    
    # 獲取餘額
    balance_url = "https://api.openai.com/v1/dashboard/billing/subscription"
    balance_res = requests.get(balance_url, headers=headers)
    balance_data = balance_res.json()
    
    # 提取餘額信息
    total_granted = balance_data.get("hard_limit_usd", 0)
    total_used = balance_data.get("total_usage", 0)
    remaining_balance = total_granted - total_used
    
    return {
        "monthly_usage": round(monthly_usage, 2),
        "daily_usage": round(daily_usage, 2),
        "total_granted": round(total_granted, 2),
        "remaining_balance": round(remaining_balance, 2)
    }

# === 查詢 DeepSeek 使用量 ===
def get_deepseek_usage():
    headers = {"Authorization": f"Bearer {DEEPSEEK_API_KEY}"}
    today = datetime.now(datetime.UTC).date()
    yesterday = today - timedelta(days=1)
    start_of_month = today.replace(day=1)
    
    try:
        # 獲取當月總使用量
        monthly_url = f"https://api.deepseek.com/v1/dashboard/billing/usage?start_date={start_of_month}&end_date={today + timedelta(days=1)}"
        monthly_res = requests.get(monthly_url, headers=headers)
        monthly_usage = monthly_res.json().get("total_usage", 0) / 100
        
        # 獲取昨天的使用量
        daily_url = f"https://api.deepseek.com/v1/dashboard/billing/usage?start_date={yesterday}&end_date={today}"
        daily_res = requests.get(daily_url, headers=headers)
        daily_usage = daily_res.json().get("total_usage", 0) / 100
        
        # 獲取餘額
        balance_url = "https://api.deepseek.com/v1/dashboard/billing/subscription"
        balance_res = requests.get(balance_url, headers=headers)
        balance_data = balance_res.json()
        
        # 提取餘額信息
        total_granted = balance_data.get("hard_limit_usd", 0)
        total_used = balance_data.get("total_usage", 0)
        remaining_balance = total_granted - total_used
        
        return {
            "monthly_usage": round(monthly_usage, 2),
            "daily_usage": round(daily_usage, 2),
            "total_granted": round(total_granted, 2),
            "remaining_balance": round(remaining_balance, 2)
        }
    except Exception as e:
        print(f"獲取 DeepSeek 使用量時出錯: {e}")
        return {
            "monthly_usage": 0,
            "daily_usage": 0,
            "total_granted": 0,
            "remaining_balance": 0,
            "error": str(e)
        }

# === 寄送 Gmail 通知 ===
def send_email(subject, body):
    msg = MIMEText(body, "plain", "utf-8")
    msg["Subject"] = subject
    msg["From"] = GMAIL_ADDRESS
    msg["To"] = ", ".join(RECEIVERS)

    with smtplib.SMTP_SSL("smtp.gmail.com", 465) as server:
        server.login(GMAIL_ADDRESS, APP_PASSWORD)
        server.sendmail(GMAIL_ADDRESS, RECEIVERS, msg.as_string())

# === 主程式 ===
def main():
    openai_data = get_openai_usage()
    deepseek_data = get_deepseek_usage()
    today = datetime.now().strftime("%Y-%m-%d")
    subject = f"【Dogtor 每日報告】{today}"
    
    body = f"""API 使用報告 ({today})：

【OpenAI API】
昨日使用金額：${openai_data['daily_usage']} USD
本月累計使用：${openai_data['monthly_usage']} USD
剩餘餘額：${openai_data['remaining_balance']} USD
總額度：${openai_data['total_granted']} USD

【DeepSeek API】
昨日使用金額：${deepseek_data['daily_usage']} USD
本月累計使用：${deepseek_data['monthly_usage']} USD
剩餘餘額：${deepseek_data['remaining_balance']} USD
總額度：${deepseek_data['total_granted']} USD

請組員留意 API 使用量哦！
"""
    
    send_email(subject, body)

if __name__ == "__main__":
    main()