# 🚀 Superb App 開發環境設置指南

## 📋 目錄
- [快速開始](#快速開始)
- [基礎環境](#基礎環境)
- [Git Hooks 設置](#git-hooks-設置)
- [Flutter 開發環境](#flutter-開發環境)
- [Python 後端環境](#python-後端環境)
- [Commit 規範](#commit-規範)
- [常見問題](#常見問題)

---

## 🎯 快速開始

```bash
# 1. Clone 專案
git clone https://github.com/pierrechen2001/dogtor_app.git
cd superb_app

# 2. 安裝基礎工具
brew install lefthook node

# 3. 安裝專案依賴
npm install

# 4. 設置 Git hooks
lefthook install

# 5. 驗證安裝
lefthook run pre-commit
```

---

## 🛠️ 基礎環境

### **必須安裝**

#### **1. Node.js & npm**
```bash
# macOS
brew install node

# 驗證安裝
node --version  # 應該 >= 18.0.0
npm --version
```

#### **2. Lefthook (Git Hooks 管理)**
```bash
# macOS (推薦)
brew install lefthook

# 或使用 npm
npm install -g @arkweid/lefthook

# 驗證安裝
lefthook version
```

### **專案初始化**
```bash
# 進入專案根目錄
cd /path/to/superb_app

# 安裝 Node.js 依賴 (包含 commitlint)
npm install

# 設置 Git hooks
lefthook install

# 驗證設置
lefthook dump
```

---

## 🔨 Git Hooks 設置

我們使用 **Lefthook** 來自動執行代碼品質檢查。

### **自動檢查項目**

#### **Pre-commit (提交前)**
- ✅ Flutter 代碼格式化檢查
- ✅ Flutter 靜態分析
- ✅ Python 代碼格式化檢查

#### **Pre-push (推送前)**
- ✅ Flutter 單元測試
- ✅ Python 測試

#### **Commit-msg (提交訊息)**
- ✅ Commit message 格式檢查

### **驗證安裝**
```bash
# 測試 pre-commit 檢查
lefthook run pre-commit

# 檢查配置
lefthook dump

# 查看已安裝的 hooks
ls -la .git/hooks/
```

---

## 📱 Flutter 開發環境

### **安裝 Flutter**
```bash
# macOS
brew install --cask flutter

# 或下載官方安裝包
# https://docs.flutter.dev/get-started/install

# 驗證安裝
flutter doctor
```

### **Flutter 專案設置**
```bash
# 進入 Flutter 專案目錄
cd frontend/superb_flutter_app

# 安裝依賴
flutter pub get

# 驗證環境
flutter analyze
flutter test
```

### **必要的 Flutter 版本**
- **Flutter**: `3.32.8` (與 CI/CD 保持一致)
- **Dart**: 自動包含在 Flutter 中

### **IDE 推薦設置**

#### **VS Code**
安裝擴展：
- Flutter
- Dart
- GitLens

#### **Android Studio**
安裝插件：
- Flutter
- Dart

---

## 🐍 Python 後端環境

### **安裝 Python**
```bash
# macOS
brew install python@3.10

# 驗證安裝
python3 --version  # 應該 >= 3.10
```

### **虛擬環境設置**
```bash
# 進入後端目錄
cd backend

# 創建虛擬環境
python3 -m venv venv

# 啟用虛擬環境
source venv/bin/activate  # macOS/Linux
# 或
venv\Scripts\activate     # Windows

# 安裝依賴
pip install -r requirements.txt

# 安裝開發工具
pip install black flake8 pytest pytest-asyncio
```

### **數據庫設置**
```bash
# 安裝 MySQL (如果使用本地開發)
brew install mysql

# 啟動 MySQL 服務
brew services start mysql

# 創建數據庫 (參考 create.sql)
mysql -u root -p < create.sql
```

---

## 📝 Commit 規範

我們採用 **Conventional Commits** 格式。

### **格式**
```
<type>: <description>

[optional body]

[optional footer]
```

### **允許的類型**
- `feat`: 新功能
- `fix`: 修復 bug
- `docs`: 文檔更新
- `style`: 代碼格式（不影響功能）
- `refactor`: 重構代碼
- `test`: 測試相關
- `chore`: 建構工具、依賴更新
- `ci`: CI/CD 配置
- `perf`: 性能優化
- `revert`: 回退變更

### **範例**

#### **✅ 正確格式**
```bash
git commit -m "feat: 新增用戶好友系統"
git commit -m "fix: 修復愛心顯示錯誤"
git commit -m "docs: 更新 API 文檔"
git commit -m "style: 格式化 Flutter 代碼"
git commit -m "refactor: 重構用戶認證邏輯"
git commit -m "test: 新增好友功能單元測試"
git commit -m "chore: 更新 Flutter 版本至 3.32.8"
git commit -m "ci: 優化 GitHub Actions 建構流程"
```

#### **❌ 錯誤格式**
```bash
git commit -m "fix bugs"           # 缺少冒號
git commit -m "update code"        # type 不在允許範圍
git commit -m "Fix: 修復bug"       # type 首字母應小寫
git commit -m "feat:"              # 缺少描述
```

---

## 🚨 常見問題

### **Q1: Lefthook 檢查失敗怎麼辦？**

```bash
# 查看具體錯誤
lefthook run pre-commit

# Flutter 格式化問題
cd frontend/superb_flutter_app
dart format .
git add .

# Python 格式化問題
cd backend
black .
git add .
```

### **Q2: 緊急情況需要跳過檢查？**

```bash
# 跳過 pre-commit 檢查
git commit -m "fix: 緊急修復" --no-verify

# 跳過 pre-push 檢查
git push --no-verify
```

⚠️ **注意**: 請謹慎使用 `--no-verify`，並在之後補充相關檢查。

### **Q3: Flutter 環境問題**

```bash
# 檢查 Flutter 環境
flutter doctor

# 常見解決方案
flutter clean
flutter pub get
flutter pub upgrade
```

### **Q4: Python 環境問題**

```bash
# 重新創建虛擬環境
rm -rf venv
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### **Q5: Git hooks 沒有執行？**

```bash
# 重新安裝 hooks
lefthook install

# 檢查 hooks 權限
ls -la .git/hooks/
chmod +x .git/hooks/pre-commit
chmod +x .git/hooks/pre-push
chmod +x .git/hooks/commit-msg
```

### **Q6: 如何檢查特定檔案？**

```bash
# 只檢查 Flutter
cd frontend/superb_flutter_app
flutter analyze
dart format --set-exit-if-changed .

# 只檢查 Python
cd backend
flake8 .
black --check .
```

---

## 🔧 故障排除

### **重置環境**

```bash
# 1. 清理 Node.js
rm -rf node_modules package-lock.json
npm install

# 2. 重新安裝 Lefthook
lefthook uninstall
lefthook install

# 3. 清理 Flutter
cd frontend/superb_flutter_app
flutter clean
flutter pub get

# 4. 重新創建 Python 環境
cd backend
rm -rf venv
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### **環境變數設置**

在你的 shell 配置檔案 (`.zshrc`, `.bash_profile`) 中：

```bash
# Flutter
export PATH="$PATH:/path/to/flutter/bin"

# Python
export PATH="/opt/homebrew/bin/python3:$PATH"

# Node.js
export PATH="/opt/homebrew/bin/node:$PATH"
```

---

## 📞 獲得幫助

### **文檔資源**
- [Flutter 官方文檔](https://docs.flutter.dev/)
- [Lefthook GitHub](https://github.com/evilmartians/lefthook)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [FastAPI 文檔](https://fastapi.tiangolo.com/)

### **團隊支援**
1. 檢查 [GitHub Issues](https://github.com/pierrechen2001/dogtor_app/issues)
2. 團隊討論群組
3. 技術負責人聯絡

---

## ✅ 設置完成檢查清單

安裝完成後，請確認以下項目：

- [ ] `node --version` 顯示正確版本
- [ ] `flutter doctor` 無錯誤
- [ ] `python3 --version` 顯示 Python 3.10+
- [ ] `lefthook version` 顯示版本信息
- [ ] `lefthook dump` 顯示配置內容
- [ ] `npm test` 通過 (如果有測試)
- [ ] `flutter analyze` 在 Flutter 專案中正常執行
- [ ] 嘗試 commit 會觸發相關檢查
- [ ] Commit message 格式檢查正常工作

---

## 🎉 完成！

恭喜！你已經完成了開發環境的設置。

現在你可以開始愉快地開發了！每次 commit 和 push 時，系統會自動幫你檢查代碼品質，確保專案維持高標準。

**記住**: 保持代碼整潔，遵循 commit 規範，讓我們一起建立優秀的產品！ 🚀
