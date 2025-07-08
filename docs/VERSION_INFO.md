# 📱 Dogtor App Version Configuration

# This file contains version information for all components of the Dogtor app
# Update this file when releasing new versions

## Current Release
CURRENT_VERSION="0.3.0"
CURRENT_BUILD="3"
RELEASE_DATE="2025-07-08"
RELEASE_CODENAME="Refactor"

## Version History

### v0.3.0 "Refactor" (2025-07-08)
- Backend API modularization with FastAPI routers
- Improved Swagger UI documentation
- Enhanced mistake book synchronization
- UI/UX improvements for onboarding

### v0.2.0 "Enhancement" (2025-06-28)  
- Enhanced onboarding flow
- Question bank updates
- Home page UI modifications
- iOS build optimization

### v0.1.0 "Foundation" (2025-04-16)
- Initial release with core features
- AI-powered quiz generation
- Learning progress tracking
- Firebase authentication
- Heart system and gamification

## Component Versions

### Frontend (Flutter App)
- **Current**: 0.3.0+3
- **Minimum iOS**: 12.0
- **Minimum Android**: API 21 (Android 5.0)
- **Flutter SDK**: ^3.6.0

### Backend (FastAPI)
- **API Version**: v2.0.0
- **Python**: 3.9+
- **FastAPI**: 0.115.6+
- **Database Schema**: v1.2.0

### Infrastructure
- **GCP Cloud Run**: Production ready
- **Cloud SQL**: MySQL 8.0
- **Firebase**: Latest SDK
- **Cloud Storage**: v1

## Deployment Information

### Production Environment
- **Backend URL**: https://your-app.run.app
- **Database**: Cloud SQL (production)
- **Storage**: GCS bucket (production)
- **Firebase Project**: dogtor-production

### Staging Environment  
- **Backend URL**: https://staging-your-app.run.app
- **Database**: Cloud SQL (staging)
- **Storage**: GCS bucket (staging)
- **Firebase Project**: dogtor-staging

## App Store Information

### iOS App Store
- **Bundle ID**: com.superb.dogtor
- **Team ID**: [Your Apple Team ID]
- **App Store ID**: [Pending submission]
- **Minimum iOS**: 12.0
- **Current Status**: Development

### Google Play Store
- **Package Name**: com.superb.dogtor
- **Developer Account**: [Your Google Play Developer Account]
- **App ID**: [Pending submission]  
- **Minimum Android**: API 21
- **Current Status**: Development

## Release Notes Templates

### App Store Description (English)
Dogtor is your smart study buddy! 🐶

📚 Personalized AI-powered quizzes tailored to Taiwan's curriculum
📈 Track your learning progress and identify areas for improvement  
⏰ Smart reminders to optimize your study schedule
👥 Study with friends and share progress
💎 Gamified learning with hearts and achievements

Perfect for junior and senior high school students looking to ace their exams!

### Key Features:
• AI-generated questions based on your curriculum
• Comprehensive progress tracking and analytics
• Social learning with friends
• Mistake book for focused review
• Offline study capability
• Clean, intuitive design

### Play Store Description (繁體中文)
Dogtor 是你的智慧學習夥伴！🐶

📚 根據台灣課綱量身打造的 AI 智慧題庫
📈 追蹤學習進度，找出需要加強的地方
⏰ 智慧提醒，優化你的讀書時間
👥 與朋友一起學習，分享學習成果
💎 遊戲化學習，讓讀書變有趣

專為國高中學生設計，幫助你輕鬆應對各種考試！

### 主要功能：
• 依據課綱生成的 AI 智慧題目
• 完整的學習進度分析
• 好友功能，一起學習更有動力
• 錯題本，針對弱點複習
• 離線學習功能
• 簡潔直覺的介面設計

## Marketing Information

### App Category
- **Primary**: Education
- **Secondary**: Productivity  

### Keywords (App Store)
學習, 教育, AI, 題庫, 國中, 高中, 考試, 複習, study, education, quiz, exam, taiwan, curriculum

### Target Audience
- **Primary**: Students (ages 12-18)
- **Secondary**: Parents and educators
- **Geographic**: Taiwan (primary), other Chinese-speaking regions

### Content Rating
- **Age Rating**: 4+ (iOS) / Everyone (Android)
- **Content**: Educational content only, no objectionable material

## Technical Specifications

### Performance Requirements
- **App Launch Time**: < 3 seconds
- **API Response Time**: < 500ms
- **Memory Usage**: < 100MB active
- **Storage**: < 50MB installation size
- **Battery**: Optimized for minimal drain

### Supported Languages
- **Primary**: Traditional Chinese (Taiwan)
- **Secondary**: English (planned)

### Accessibility
- **VoiceOver/TalkBack**: Supported
- **Dynamic Type**: Supported
- **High Contrast**: Supported
- **Reduced Motion**: Respected

## Contact Information

### Development Team
- **Lead Developer**: Pierre Chen
- **Organization**: Superb Education
- **Email**: [Your contact email]
- **GitHub**: https://github.com/pierrechen2001/dogtor_app

### Support
- **User Support**: [Support email]
- **Technical Issues**: [Technical support email]
- **Privacy Concerns**: [Privacy email]

---

*Last Updated: 2025-07-08*
*Document Version: 1.0*
