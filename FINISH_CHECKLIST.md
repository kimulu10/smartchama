# SmartChama — finish checklist

Run these in order from the project folder (`c:\Users\ADMN\Downloads\smartchama`).

## 1. GitHub (required)

```powershell
.\scripts\push-to-github.ps1
```

Then open: https://github.com/kimulu10/smartchama/actions → wait for **Build Android APK** → download **smartchama-release-apk**.

If push is blocked again, rotate the Firebase service account key in Firebase Console, then re-run the script.

## 2. Android APK (local alternative)

```powershell
.\scripts\build-apk.ps1
```

Output: `releases\smartchama-release.apk` (install on any Android phone).

## 3. M-Pesa backend (Render)

1. Render dashboard → your **stk-push-api** service → **Environment**
2. Set variables (from your local `mpesa-backend/.env`, **do not commit .env**):
   - `MPESA_CONSUMER_KEY`
   - `MPESA_CONSUMER_SECRET`
   - `MPESA_PASS_KEY`
   - `MPESA_CALLBACK_URL` = `https://stk-push-api-4flq.onrender.com/callback`
   - `MPESA_ENV` = `sandbox`
   - `FIREBASE_SERVICE_ACCOUNT_JSON` = entire contents of your Firebase JSON file (one line)
3. Redeploy → visit https://stk-push-api-4flq.onrender.com/health → `"ok": true`

## 4. Test M-Pesa in the app

1. Log in → create or join a chama
2. **Add Contribution** → amount e.g. `10` → phone `254708374149` (sandbox)
3. Approve STK on the test line

## 5. iOS (Mac only)

See `BUILD_RELEASE.md` → Xcode Archive → export IPA.

---

## Done when

- [ ] Code on https://github.com/kimulu10/smartchama
- [ ] APK downloaded (Actions or `releases/`)
- [ ] `/health` returns OK
- [ ] Test STK contribution succeeds
- [ ] Firebase service account key rotated (if it was ever pushed to git)
