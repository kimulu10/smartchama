# M-Pesa setup (SmartChama)

## Architecture

```
Flutter app  →  POST /stkpush  →  Render backend  →  Safaricom Daraja
                     ↑                                    ↓
              poll /transaction-status          POST /callback
```

Default backend URL in the app: `https://stk-push-api-4flq.onrender.com`

## 1. Safaricom Daraja (sandbox)

1. Register at [developer.safaricom.co.ke](https://developer.safaricom.co.ke/)
2. Create an app and copy **Consumer Key**, **Consumer Secret**, and **Passkey**
3. Sandbox paybill shortcode: **174379**

## 2. Backend environment (`mpesa-backend/.env`)

```env
MPESA_CONSUMER_KEY=your_key
MPESA_CONSUMER_SECRET=your_secret
MPESA_SHORT_CODE=174379
MPESA_PASS_KEY=your_passkey
MPESA_CALLBACK_URL=https://stk-push-api-4flq.onrender.com/callback
MPESA_ENV=sandbox
FIREBASE_SERVICE_ACCOUNT_PATH=./your-firebase-adminsdk.json
PORT=3000
```

**Critical:** `MPESA_CALLBACK_URL` must be the public HTTPS URL of your deployed server + `/callback`.

## 3. Deploy backend (Render)

1. Push `mpesa-backend/` to GitHub (or use existing Render service)
2. Set all env vars in Render dashboard
3. **Firebase on Render:** paste the full service account JSON into **`FIREBASE_SERVICE_ACCOUNT_JSON`** (one env var). Do not commit the JSON file to GitHub.
4. Locally you can use `FIREBASE_SERVICE_ACCOUNT_PATH=./serviceAccountKey.json` instead
5. Verify: open `https://stk-push-api-4flq.onrender.com/health` — should return `{"ok":true,...}`

## 4. Test STK Push

1. Log into the app and join/create a chama (must have `organizationId` + `chamaId`)
2. Go to **Add Contribution** → enter amount and phone **254708374149** (sandbox test number)
3. Approve STK on the simulator / test device
4. Payment status updates via callback → Firestore `mpesa_transactions` + `contributions`

## 5. Production

- Set `MPESA_ENV=production` and use production Daraja credentials and shortcode
- Update `MPESA_CALLBACK_URL` to production URL
- Rebuild app with: `flutter build apk --dart-define=MPESA_BASE_URL=https://your-prod-api.com`

## Troubleshooting

| Issue | Fix |
|-------|-----|
| "Cannot reach M-Pesa server" | Backend down or wrong URL — check `/health` |
| STK not received | Wrong phone format; use `07...` or `2547...` |
| Payment stays pending | Callback URL not reachable from Safaricom |
| "Missing organizationId" | User must be in a chama before paying |
