# Firebase 專案遷移指南
## 從 dogtor-c33d4 遷移到 dogtor-454402

### 📋 概述
將所有 Firebase 服務從獨立的 `dogtor-c33d4` 專案遷移到後端專案 `dogtor-454402`，統一管理所有服務。

### 🎯 遷移目標
- **舊 Firebase 專案**: `dogtor-c33d4` 
- **新 Firebase 專案**: `dogtor-454402`
- **Sender ID**: 將從 `426092249907` 變更為新的 Sender ID

---

## 🚀 執行步驟

### 第一步：在 GCP 上設置新的 Firebase 專案

```bash
# 1. 確保在正確的專案下
gcloud config set project dogtor-454402

# 2. 啟用 Firebase API 和相關服務
gcloud services enable firebase.googleapis.com
gcloud services enable firebasehosting.googleapis.com
gcloud services enable firestore.googleapis.com

# 3. 如果還沒有 Firebase CLI，先安裝
npm install -g firebase-tools

# 4. 登入 Firebase
firebase login

# 5. 將現有 GCP 專案添加為 Firebase 專案
firebase projects:addfirebase dogtor-454402

# 6. 確認專案已建立
firebase projects:list
```

### 第二步：重新配置 Flutter 應用

```bash
# 1. 進入 Flutter 專案目錄
cd frontend/superb_flutter_app

# 2. 安裝 FlutterFire CLI (如果還沒有)
dart pub global activate flutterfire_cli

# 3. 重新配置 Firebase
flutterfire configure --project=dogtor-454402

# 這會自動更新以下檔案：
# - lib/firebase_options.dart
# - ios/Runner/GoogleService-Info.plist
# - android/app/google-services.json
# - macos/Runner/GoogleService-Info.plist
# - firebase.json
```

### 第三步：驗證 Flutter 配置

執行 `flutterfire configure` 後，檢查以下檔案是否正確更新：

**檢查要點：**
- 所有 `projectId` 應該是 `dogtor-454402`
- 新的 `authDomain`: `dogtor-454402.firebaseapp.com`
- 新的 `storageBucket`: `dogtor-454402.appspot.com`
- 新的 Sender ID (會是不同的數字)

### 第四步：更新後端配置

後端程式碼已經修改為使用 `ApplicationDefault` 憑證，當部署到 `dogtor-454402` 專案時會自動使用該專案的 Firebase 服務。

**已完成的修改：**
- ✅ `backend/app/routers/notifications.py` - 已更新註釋
- ✅ 移除了之前的 Secret Manager 配置需求

### 第五步：部署並測試

```bash
# 1. 部署後端到 Cloud Run
gcloud run deploy superb-backend \
    --source=backend/ \
    --platform=managed \
    --region=asia-east1 \
    --allow-unauthenticated \
    --project=dogtor-454402

# 2. 測試推播通知功能
# 使用你的 API 測試端點，例如：
curl -X POST "https://your-backend-url/notifications/send_test_push" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test_user"}'
```

---

## 📱 需要用戶重新安裝的原因

由於 Firebase 專案和 Sender ID 改變，現有用戶的 FCM Token 會失效，因此：

### 對現有用戶的影響：
1. **推播通知會停止工作**：舊的 FCM Token 無法接收新專案的通知
2. **需要重新註冊 Token**：用戶需要重新開啟 App 來註冊新的 FCM Token

### 建議的處理方式：

**選項 1：強制更新 (推薦)**
```dart
// 在 Flutter App 中檢查並強制重新註冊 FCM Token
void checkAndUpdateFCMToken() async {
  final messaging = FirebaseMessaging.instance;
  
  // 清除舊 token (如果有的話)
  await messaging.deleteToken();
  
  // 取得新 token
  final newToken = await messaging.getToken();
  
  // 傳送到後端重新註冊
  await registerTokenToBackend(newToken);
}
```

**選項 2：版本檢查**
- 發布新版本 App
- 在後端 API 中檢查 App 版本
- 對舊版本返回「需要更新」訊息

---

## 🔄 回滾計劃（如果需要）

如果遷移過程中出現問題，可以快速回滾：

### 回滾 Flutter 配置：
```bash
# 恢復到舊的 Firebase 專案
flutterfire configure --project=dogtor-c33d4
```

### 回滾後端：
修改 `notifications.py` 使用 Secret Manager 配置（之前的方案）

---

## ✅ 遷移檢查清單

### 準備階段：
- [ ] 確認 `dogtor-454402` 專案有 Firebase API 權限
- [ ] 安裝 Firebase CLI 和 FlutterFire CLI
- [ ] 備份現有配置檔案

### 執行階段：
- [ ] 創建新的 Firebase 專案 (`dogtor-454402`)
- [ ] 重新配置 Flutter 應用
- [ ] 驗證所有配置檔案已更新
- [ ] 部署後端到 Cloud Run
- [ ] 測試推播通知功能

### 完成階段：
- [ ] 通知用戶需要更新 App 或重新登入
- [ ] 監控推播通知發送成功率
- [ ] 清理舊的 `dogtor-c33d4` 專案資源（如果不再需要）

---

## 📊 預期的新配置資訊

遷移完成後，你會獲得：

- **新的 Project ID**: `dogtor-454402`
- **新的 Sender ID**: (由 Firebase 自動生成)
- **新的 Auth Domain**: `dogtor-454402.firebaseapp.com`
- **新的 Storage Bucket**: `dogtor-454402.appspot.com`

這些資訊會在執行 `flutterfire configure` 時自動更新到你的 Flutter 專案中。
