# 🐶 Dogtor — Your Smart Study Buddy

Dogtor is a cross-platform AI-powered learning app designed for junior and senior high school students!
It generates personalized quizzes, tracks student progress, and sends smart reminders to optimize learning efficiency.

📱 Available on **iOS & Android** | 🧠 Built with **Flutter + FastAPI**

---

## 🚀 Features

- 🧠 **AI-driven Quiz Generation** — Tailored questions based on curriculum tags (單元/章節)
- 📈 **Learning Progress Tracking** — Visualize what you’ve mastered and what needs more work
- ⏰ **Smart Reminders** — Automatically prompt review based on memory decay
- 🔐 **Google Sign-In + Firebase Auth** — Seamless and secure login
- 🌐 **FastAPI Backend** — RESTful API for quiz, history, and performance data
- ☁️ **Deployed on GCP** — Includes Cloud Run, Cloud SQL, and Cloud Storage
- 🔄 **CI/CD Pipeline** — Auto-deploy via GitHub + GCP Cloud Build

---

## 🛠️ Tech Stack

| Layer        | Tech                                       |
|--------------|--------------------------------------------|
| Frontend     | Flutter (Dart)                             |
| Backend      | FastAPI (Python)                           |
| Database     | Cloud SQL (MySQL)                          |
| Auth         | Firebase Authentication + Google Sign-In   |
| Hosting      | Google Cloud Run                           |
| Storage      | Google Cloud Storage                       |
| CI/CD        | GitHub Actions + GCP Cloud Build           |

---

## 📸 Screenshots (Coming Soon)

> 🧪 Sample question  
> 📊 Progress dashboard  
> 🐾 Friendly onboarding flow

---

## 🌍 中文簡介

Dogtor 是一款支援 iOS / Android 的跨平台 AI 學習 App，專為國高中學生設計，提供：

- 📚 個人化題目練習
- 📈 學習進度分析
- 🔔 智慧提醒功能

後端使用 FastAPI，資料儲存於 GCP Cloud SQL，並透過 CI/CD 自動部署至 Cloud Run，結合 Firebase 登入系統，讓學習過程智慧又順暢。

---

## � Version Management

This project follows [Semantic Versioning (SemVer)](https://semver.org/) starting from version 0.1.0.

### Current Version
- **App**: 0.3.0+3 (Ready for testing)
- **Backend**: v2.0.0 (Modularized architecture)

### Quick Commands
```bash
# Check current version status
./scripts/status.sh

# Bump version (patch/minor/major)
./scripts/version.sh patch

# View version history
cat CHANGELOG.md
```

For detailed release information, see [CHANGELOG.md](CHANGELOG.md) and [Version Info](docs/VERSION_INFO.md).

---

## �👨‍💻 Author

Created with ❤️ by [Pierre Chen](https://github.com/ntupierre)  
Founder @ Superb Education | B.B.A in Information Management, NTU

---

> 🎯 Empowering students, one smart quiz at a time.
