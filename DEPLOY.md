# Deploy SmartChama for real users

## A. M-Pesa backend (Render) — do this first

1. Go to [Render Dashboard](https://dashboard.render.com) → service **stk-push-api-4flq** (or create from `mpesa-backend/render.yaml`)
2. **Environment** → add:

| Variable | Value |
|----------|--------|
| `MPESA_CONSUMER_KEY` | From Daraja portal |
| `MPESA_CONSUMER_SECRET` | From Daraja portal |
| `MPESA_PASS_KEY` | Sandbox passkey |
| `MPESA_SHORT_CODE` | `174379` (sandbox) |
| `MPESA_CALLBACK_URL` | `https://stk-push-api-4flq.onrender.com/callback` |
| `MPESA_ENV` | `sandbox` (or `production` when live) |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | Paste full Firebase service account JSON (one line) |

3. **Manual Deploy** → wait until live
4. Test: open `https://stk-push-api-4flq.onrender.com/health` → `{"ok":true,...}`

## B. Firebase (app data)

1. [Firebase Console](https://console.firebase.google.com/) → project **smart-chama-5ecaf**
2. Enable **Authentication** (Email/Password)
3. Enable **Firestore** — start in test mode, then add rules:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /organizations/{orgId}/{document=**} {
      allow read, write: if request.auth != null;
    }
    match /mpesa_transactions/{id} {
      allow read: if request.auth != null;
      allow write: if false;
    }
  }
}
```

4. Add Android app with package `com.example.smartchama` (or your final package name)

## C. Android APK (distribute to members)

**Option 1 — GitHub (recommended)**

```powershell
git push origin main
```

Then: https://github.com/kimulu10/smartchama/actions → **Build Android APK** → download **smartchama-release-apk**

**Option 2 — Local**

```powershell
.\scripts\build-apk.ps1
```

Share `releases\smartchama-release.apk` via WhatsApp, Drive, or your website. Users enable **Install unknown apps**.

**Option 3 — Google Play**

```powershell
flutter build appbundle --release
```

Upload `build/app/outputs/bundle/release/app-release.aab` to Play Console.

## D. iOS (optional)

Mac + Xcode only → see `BUILD_RELEASE.md`.

## E. Verify the app works

1. Install APK
2. Sign up / log in
3. Create or join a chama (invite code)
4. **Add Contribution** → M-Pesa STK (sandbox: `254708374149`)
5. Check Firestore for `contributions` and `transactions`

## Production checklist

- [ ] Rotate Firebase key if it was ever in git
- [ ] Daraja **production** credentials + `MPESA_ENV=production`
- [ ] Change `applicationId` from `com.example.smartchama` before Play Store
- [ ] Firestore rules tightened for your org structure
