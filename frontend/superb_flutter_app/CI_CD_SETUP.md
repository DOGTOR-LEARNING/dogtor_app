# Flutter CI/CD 設置指南

## 📋 需要設置的 GitHub Secrets

### Android 相關 Secrets
在 GitHub Repository Settings > Secrets and variables > Actions 中添加以下 secrets：

1. **ANDROID_KEYSTORE**: Android 簽名檔案的 base64 編碼
   ```bash
   base64 android/app/keystore.jks | pbcopy
   ```

2. **ANDROID_KEY_ALIAS**: 簽名別名（如：key）

3. **ANDROID_STORE_PASSWORD**: Keystore 密碼

4. **ANDROID_KEY_PASSWORD**: Key 密碼

5. **GOOGLE_PLAY_JSON_KEY**: Google Play Console API JSON 密鑰（整個 JSON 內容）

### iOS 相關 Secrets
1. **MATCH_PASSWORD**: Fastlane Match 密碼

2. **APP_STORE_CONNECT_API_KEY**: App Store Connect API 密鑰

## 🔧 本地設置步驟

### 1. 安裝 Fastlane
```bash
cd frontend/superb_flutter_app
sudo gem install fastlane
bundle install
```

### 2. 設置 Android 簽名
```bash
# 生成 keystore（如果還沒有的話）
keytool -genkey -v -keystore android/app/keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias key

# 創建 key.properties 檔案
cat > android/key.properties << EOF
storePassword=your_store_password
keyPassword=your_key_password
keyAlias=key
storeFile=keystore.jks
EOF
```

### 3. 設置 iOS 簽名（使用 Match）
```bash
cd ios
fastlane match init
fastlane match development
fastlane match appstore
```

### 4. 修改 Appfile 配置
編輯以下檔案並替換為你的實際值：
- `ios/fastlane/Appfile`
- `android/fastlane/Appfile`
- `fastlane/Appfile`

### 5. 更新 Android 建構配置
在 `android/app/build.gradle` 中添加簽名配置：

```gradle
android {
    ...
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile file(keystoreProperties['storeFile'])
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

## 🚀 使用方式

### 本地測試
```bash
cd frontend/superb_flutter_app

# 測試 iOS beta 部署
bundle exec fastlane ios beta

# 測試 Android 內部測試
bundle exec fastlane android internal
```

### 自動部署
- 推送到 `main` 分支：自動觸發生產部署
- 推送到 `develop` 分支：自動觸發測試建構
- 建立 Pull Request：自動觸發測試

## 📱 部署目標

### Android
- **Internal Testing**: 內部測試（自動）
- **Beta**: Beta 測試（手動觸發）
- **Production**: 正式發布（手動觸發）

### iOS
- **TestFlight**: Beta 測試（自動）
- **App Store**: 正式發布（需要手動審核）

## ⚠️ 注意事項

1. 首次設置需要手動配置各種簽名和密鑰
2. 確保所有 secrets 都正確設置在 GitHub 中
3. iOS 部署需要有效的 Apple Developer Program 會員資格
4. Android 部署需要在 Google Play Console 中設置 API 訪問權限

## 🔍 疑難排解

如果部署失敗，請檢查：
1. GitHub Secrets 是否正確設置
2. 簽名憑證是否有效
3. App Store Connect / Google Play Console 權限是否正確
4. Fastlane 配置檔案是否正確

需要協助時，請檢查 GitHub Actions 的詳細日誌。
