# SmartChama — Release build guide

## Android APK / App Bundle

### 1. Create a release keystore (once)

```bash
keytool -genkey -v -keystore release.keystore -alias smartchama -keyalg RSA -keysize 2048 -validity 10000
```

Store the keystore outside the repo (e.g. `C:\Users\YOU\keystores\release.keystore`).

### 2. Configure signing

Copy `android/keystore.properties.example` to `android/keystore.properties` and set:

```properties
storeFile=C:/path/to/release.keystore
storePassword=your_store_password
keyAlias=smartchama
keyPassword=your_key_password
```

`keystore.properties` is gitignored — never commit it.

### 3. Build

```bash
flutter pub get
flutter build apk --release
# or for Play Store:
flutter build appbundle --release
```

Output:

- APK: `build/app/outputs/flutter-apk/app-release.apk`
- AAB: `build/app/outputs/bundle/release/app-release.aab`

Debug builds work without `keystore.properties`. Release signing is applied only when that file exists.

---

## iOS

### 1. Prerequisites

- macOS with Xcode
- Apple Developer account
- CocoaPods: `sudo gem install cocoapods`

### 2. Firebase

`ios/Runner/GoogleService-Info.plist` is included and matches `lib/firebase_options.dart`.

### 3. Open in Xcode

```bash
cd ios && pod install && cd ..
open ios/Runner.xcworkspace
```

In Xcode:

1. Select **Runner** → **Signing & Capabilities**
2. Set your **Team**
3. Set **Bundle Identifier** (default: `com.example.smartchama` — change before App Store)
4. Enable **Push Notifications** if you use FCM (entitlements file: `Runner.entitlements`)

### 4. Build

```bash
flutter build ios --release
```

Archive and upload via **Product → Archive** in Xcode.

---

## Security checklist

- [ ] Rotate Firebase / M-Pesa keys if they were ever committed
- [ ] Restrict Firebase API keys by app ID in [Google Cloud Console](https://console.cloud.google.com/)
- [ ] Enable Firestore security rules for `organizations/{orgId}/...`
- [ ] Run M-Pesa STK only through `mpesa-backend` (never embed Daraja secrets in the app)
- [ ] Do not store user passwords on device (app uses Firebase session + biometrics)
- [ ] Set `MPESA_BASE_URL` via `--dart-define=MPESA_BASE_URL=https://your-api.com` for production
