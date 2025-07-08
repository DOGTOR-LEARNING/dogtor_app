import firebase_admin
from firebase_admin import messaging, credentials

#cred = firebase_admin.get_app().credential
#print("Using service account:", cred.service_account_email)


cred = credentials.Certificate("/Users/bowen/Desktop/NTU/Grade2-2/DOGTOR/dogtor-c33d4-firebase-adminsdk-fbsvc-40a982dc0f.json")
firebase_admin.initialize_app(cred) #cred

message = messaging.Message(
    notification=messaging.Notification(
        title="Hello!",
        body="這是從後端送出的通知",
    ),
    token="dDIHevR0Bkfam7vDZq5iuT:APA91bFQZGnWbpvGAKctWiLQ2x397bmmPsdXujuy4feADRuoUl7QUJ3ufLSK_iair-TIyoOUYb7oZ_HFUfjTfgeVCWHuvnVc-UjhPbfOBRrAfNMAS0V1oPA",
)

response = messaging.send(message)
print("Successfully sent message:", response)
