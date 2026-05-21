# SmartChama

Flutter app for managing chama groups: contributions, loans, M-Pesa payments, and dashboards.

**Repository:** [github.com/kimulu10/smartchama](https://github.com/kimulu10/smartchama)

## Download the app

| Platform | How to get the file |
|----------|---------------------|
| **Android APK** | After `flutter build apk --release`, open `build/app/outputs/flutter-apk/app-release.apk` |
| **Android (Play Store)** | Build App Bundle: `flutter build appbundle --release` → `build/app/outputs/bundle/release/app-release.aab` |
| **iOS** | Requires **macOS + Xcode**. See [BUILD_RELEASE.md](BUILD_RELEASE.md). IPA is created via Xcode **Product → Archive**. |

## Finish setup (APK + GitHub + M-Pesa)

See **[FINISH_CHECKLIST.md](FINISH_CHECKLIST.md)** — run `scripts\push-to-github.ps1` and `scripts\build-apk.ps1`.

## Quick start (developers)

```bash
flutter pub get
flutter run
```

### M-Pesa payments

1. Deploy `mpesa-backend/` to [Render](https://render.com) or run locally: `cd mpesa-backend && npm install && node server.js`
2. Set Daraja credentials in `mpesa-backend/.env` (copy from `.env.example`)
3. Set `MPESA_CALLBACK_URL` to `https://YOUR-BACKEND-URL/callback`
4. Default app backend URL: `https://stk-push-api-4flq.onrender.com` (override with `--dart-define=MPESA_BASE_URL=...`)

Sandbox test phone: use Daraja simulator `254708374149` with PIN from [Safaricom Daraja](https://developer.safaricom.co.ke/).

## Android release build

See [BUILD_RELEASE.md](BUILD_RELEASE.md).

```bash
flutter build apk --release
```

## Project structure

- `lib/` — Flutter UI and services
- `mpesa-backend/` — Express server for STK Push + Firestore callbacks
- `android/` / `ios/` — Native project files

## Security

- Never commit `android/keystore.properties`, `mpesa-backend/.env`, or Firebase service account JSON files.
- M-Pesa consumer key/secret live only on the backend.
