# Changelog

All notable changes to Dogtor (Superb Learning Platform) will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Backend API modularization with FastAPI routers
- Improved Swagger UI documentation with Pydantic models
- Health check endpoints

### Changed
- Refactored monolithic main.py into 9 functional modules
- Enhanced API documentation and type safety

## [0.3.0] - 2025-07-08

### Added
- Delete mistake book API functionality
- Synchronization logic for mistake book (local and cloud)
- Backend refactoring for improved maintainability

### Fixed
- Mistake book local and cloud synchronization logic
- UI/UX improvements for add mistake page

## [0.2.0] - 2025-06-28

### Added
- Enhanced onboarding flow with time management
- Question bank database updates
- Home page UI modifications
- iOS build artifacts optimization

### Fixed
- Onboarding timing issues
- Merge conflicts resolution for Podfile.lock
- Various UI/UX improvements

## [0.1.0] - 2025-04-16

### Added
- Core AI-powered quiz generation system
- Learning progress tracking functionality
- Smart reminder system with Firebase push notifications
- Google Sign-In authentication
- FastAPI backend with RESTful APIs
- Friend system for collaborative learning
- Heart system for gamification
- Mistake book feature for review
- Chat history functionality
- Knowledge point scoring system
- Subject abilities analysis
- Weekly and monthly progress reports
- GCP deployment with Cloud Run, Cloud SQL, and Cloud Storage

### Features
- **AI Integration**: GPT-4 powered chat and quiz analysis
- **Authentication**: Firebase Auth with Google Sign-In
- **Database**: Cloud SQL (MySQL) for data persistence
- **Notifications**: Firebase Cloud Messaging for push notifications
- **File Storage**: Google Cloud Storage for images
- **Analytics**: Learning progress and performance tracking
- **Social Features**: Friend requests, learning reminders
- **Gamification**: Heart system, streak tracking, achievements

### Technical Stack
- **Frontend**: Flutter (iOS & Android)
- **Backend**: FastAPI (Python)
- **Database**: Cloud SQL (MySQL)
- **Authentication**: Firebase Authentication
- **Hosting**: Google Cloud Run
- **Storage**: Google Cloud Storage
- **CI/CD**: GitHub Actions + GCP Cloud Build

---

## Version Numbering

This project follows [Semantic Versioning](https://semver.org/):

- **MAJOR** version when making incompatible API changes
- **MINOR** version when adding functionality in a backwards compatible manner  
- **PATCH** version when making backwards compatible bug fixes

### Build Numbers

For mobile app releases:
- **iOS**: Uses `CFBundleVersion` for build number
- **Android**: Uses `versionCode` for build number
- Build numbers increment with each release to app stores

### Release Process

1. Update version in `pubspec.yaml` 
2. Update this CHANGELOG.md
3. Create git tag: `git tag v0.3.0`
4. Build and deploy to app stores
5. Update production environment

### Current Versions

- **App Version**: 1.0.0+1 (Ready for App Store submission)
- **Backend API**: v2.0.0 (Modularized architecture)
- **Database Schema**: v1.2.0 (With sync support)

---

## Pre-Release Checklist

Before app store submission:

- [ ] Version number updated in `pubspec.yaml`
- [ ] Build number incremented
- [ ] CHANGELOG.md updated  
- [ ] All features tested on both iOS and Android
- [ ] Backend API deployed to production
- [ ] Database migrations completed
- [ ] Performance testing completed
- [ ] Security review completed
- [ ] App store metadata prepared
- [ ] Screenshots and promotional materials ready

---

*For detailed commit history, see the project's git log.*
