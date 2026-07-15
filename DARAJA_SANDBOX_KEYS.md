# Daraja Sandbox — fix Passkey & Short Code (N/A)

Your **Consumer Key** and **Consumer Secret** are correct on the app page.  
**Passkey** and **Short Code** show **N/A** until you add the STK Push product.

## Step 1 — Add STK product on Daraja

1. Go to **https://developer.safaricom.co.ke**
2. Open your app **Smart Chama** (Sandbox)
3. Go to **Products** (or **APIs** in the menu)
4. Add / subscribe to:
   - **Lipa Na M-Pesa Online** (sandbox), or  
   - **M-Pesa Express (STK Push)** sandbox
5. Save — after a few minutes, **Short Code** and **Passkey** may appear on the app page.

## Step 2 — If still N/A, use official sandbox test values

Safaricom sandbox STK Push almost always uses:

| Setting | Value |
|---------|--------|
| **Short Code** | `174379` |
| **Passkey** | `bfb279f9aa9bdbcf158e97dd71a467cd2e0c89305bbf21595ca0cf22a1a2d2e3` |

Get the same from: **APIs → M-Pesa Express Simulate → Test Credentials** on Daraja.

## Step 3 — Put these in Render (not GitHub)

Open **Render** → service **stk-push-api-4flq** → **Environment**:

```
MPESA_CONSUMER_KEY=<your Consumer Key from Daraja>
MPESA_CONSUMER_SECRET=<your Consumer Secret from Daraja>
MPESA_SHORT_CODE=174379
MPESA_PASS_KEY=bfb279f9aa9bdbcf158e97dd71a467cd2e0c89305bbf21595ca0cf22a1a2d2e3
MPESA_CALLBACK_URL=https://stk-push-api-4flq.onrender.com/callback
MPESA_ENV=sandbox
FIREBASE_SERVICE_ACCOUNT_JSON=<paste full Firebase service account JSON>
```

Then **Save** → **Manual Deploy**.

## Step 4 — Test

1. Browser: https://stk-push-api-4flq.onrender.com/health → `"ok": true`
2. App → Add Contribution → phone **254708374149** → amount **10** → STK Push

## Sandbox test phone

| Field | Value |
|-------|--------|
| Phone | `254708374149` |
| PIN | Use Daraja simulator PIN (often `174379` in docs — check **M-Pesa Express Simulate** page) |

## Security

You shared your Consumer Secret in chat. After everything works, **regenerate** Consumer Secret in Daraja and update Render.
