import firebase_admin
from firebase_admin import credentials, messaging

cred = credentials.Certificate("dogtor-454402-09807cebb0d5.json")
firebase_admin.initialize_app(cred)

def send_push_notification(token: str, title: str, body: str) -> str:
    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            token=token,
        )
        response = messaging.send(message)
        print(f"✅ 已送出推播：{token[:10]}... → {response}")
        return response
    except Exception as e:
        print(f"❌ 發送失敗：{e}")
        return "error"
