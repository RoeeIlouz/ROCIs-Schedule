# Developer Setup & Build Guide

This guide walks through setting up the local development environment, configuring Firebase and signing keys, running automated tests, and building release artifacts for **ROCIs Schedule**.

---

## 🛠️ Prerequisites

- **Flutter SDK**: 3.24.0 or higher
- **Dart SDK**: 3.5.0 or higher
- **Java JDK**: Version 17 (Zulu or OpenJDK)
- **Android SDK**: Build tools 34.0.0+

---

## ⚙️ Initial Setup

1. **Clone repository**:
   ```bash
   git clone https://github.com/RoeeIlouz/ROCIs-Schedule.git
   cd ROCIs-Schedule
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**:
   Place `google-services.json` inside `android/app/google-services.json`.

4. **Configure Release Keystore Signing** (Optional for debug, mandatory for Google Play):
   Copy `android/key.properties.example` to `android/key.properties` and provide your keystore credentials:
   ```properties
   storePassword=your-store-password
   keyPassword=your-key-password
   keyAlias=your-key-alias
   storeFile=../path/to/your/keystore.jks
   ```

---

## 🧪 Testing & Code Quality

- **Run unit and widget tests**:
  ```bash
  flutter test
  ```

- **Run static analyzer**:
  ```bash
  flutter analyze
  ```

---

## 📦 Building Artifacts

- **Android App Bundle (.aab)**:
  ```bash
  flutter build appbundle --release
  ```
  Output: `build/app/outputs/bundle/release/app-release.aab`

- **Android APK (.apk)**:
  ```bash
  flutter build apk --release
  ```
  Output: `build/app/outputs/flutter-apk/app-release.apk`
