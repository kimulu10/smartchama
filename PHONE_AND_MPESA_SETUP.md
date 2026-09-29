# SmartChama — install on your phone + M-Pesa setup

Follow these steps in order.

---

## Part 1: Install the app on your Android phone

### Method A — Download APK from GitHub (best if PC build failed)

1. On your **phone**, open Chrome and go to:  
   **https://github.com/kimulu10/smartchama/actions**
2. Tap the **top green** workflow run (**Build Android APK**).
3. Scroll down to **Artifacts** → tap **smartchama-release-apk** → download.
4. Open the downloaded file → **Install**.
5. If blocked: **Settings → Security → Install unknown apps** → allow Chrome (or Files).

### Method B — Install while developing (USB cable)

1. On phone: **Settings → Developer options → USB debugging** ON.
2. Connect phone to PC with USB.
3. On PC, in project folder:
   ```powershell
   cd c:\Users\ADMN\Downloads\smartchama
   flutter devices
   flutter run
   ```
4. App installs and opens on the phone automatically.

### Method C — Send APK from PC to phone

1. On PC, after a successful build, copy:  
   `build\app\outputs\flutter-apk\app-release.apk`
2. Send to your phone via **WhatsApp** (to yourself), **email**, or **USB**.
3. Open the file on the phone and install.

---

## Part 2: Firebase (login & chama data)

1. Open **https://console.firebase.google.com** → project **smart-chama-5ecaf**
2. **Build → Authentication → Sign-in method** → enable **Email/Password** → Save.
3. **Build → Firestore Database** → Create database (if not created).
4. **Rules** tab → paste rules from `firestore.rules` in the project → **Publish**.
5. In the app: **Sign up** with your email and password.

---

## Part 3: M-Pesa backend on Render (payments)

Your app talks to: **https://stk-push-api-4flq.onrender.com**

### Step 1 — Daraja (Safaricom sandbox)

1. Go to **https://developer.safaricom.co.ke**
2. Log in → **My Apps** → your sandbox app.
3. Copy:
   - **Consumer Key**
   - **Consumer Secret**
   - **Passkey** (Lipa Na M-Pesa sandbox)

### Step 2 — Firebase JSON for the server

1. Firebase Console → **Project settings** (gear) → **Service accounts**.
2. **Generate new private key** → download JSON file.
3. Open the file in Notepad — you will paste **all of it** into Render (one line).

### Step 3 — Render environment variables

1. **https://dashboard.render.com** → open service **stk-push-api-4flq** (or your M-Pesa service).
2. **Environment** → add each variable:

| Key | Value |
|-----|--------|
| `MPESA_CONSUMER_KEY` | Your Daraja consumer key |
| `MPESA_CONSUMER_SECRET` | Your Daraja consumer secret |
| `MPESA_PASS_KEY` | Your sandbox passkey |
| `MPESA_SHORT_CODE` | `174379` |
| `MPESA_CALLBACK_URL` | `https://stk-push-api-4flq.onrender.com/callback` |
| `MPESA_ENV` | `sandbox` |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | Paste **entire** JSON file content (one line) |

3. Click **Save Changes** → **Manual Deploy** → wait until **Live**.

### Step 4 — Wake up the server (free Render sleeps)

On your phone or PC browser, open:

**https://stk-push-api-4flq.onrender.com/health**

Wait 30–60 seconds. You should see something like:

```json
{"ok":true,"mpesaEnv":"sandbox",...}
```

If the page errors, wait and refresh once — then redeploy on Render if it still fails.

---

## Part 4: Test M-Pesa in the app

1. Open SmartChama on your phone.
2. **Log in** → **Create chama** OR **Join** with invite code (you must be in a chama).
3. Tap **Add Money** / **Add Contribution**.
4. Enter:
   - **Amount:** e.g. `10`
   - **Phone (sandbox test):** `254708374149`  
     (Safaricom sandbox test number — not your real number for testing)
5. Tap **Send STK Push**.
6. On the test flow, use sandbox PIN from Daraja docs when prompted.
7. Wait for **Payment successful**.

**Real phone number (sandbox):** you can also use `0712345678` format — the app converts to `2547...`.

---

## Part 5: If M-Pesa fails

| Problem | What to do |
|---------|------------|
| "Cannot reach M-Pesa server" | Open `/health` URL first; redeploy Render |
| "Join or create a chama first" | Create or join a chama before paying |
| STK never arrives | Wrong phone; use sandbox number `254708374149` |
| Payment stays pending | Check `MPESA_CALLBACK_URL` ends with `/callback` |
| Render 502 / timeout | Free tier sleeping — open health URL, retry |

---

## Part 6: Going live (real money)

1. Apply for **production** Daraja credentials on Safaricom.
2. On Render: `MPESA_ENV=production`, production shortcode, production passkey.
3. Update callback URL to your production server URL.
4. Rebuild APK and redistribute to members.

---

## Quick checklist

- [ ] App installed on phone
- [ ] Firebase Email login works
- [ ] Created or joined a chama
- [ ] Render `/health` shows `"ok": true`
- [ ] Test STK with `254708374149` succeeds
