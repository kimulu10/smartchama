// =========================
// server.js - SmartChama M-Pesa Integration (FULL UPGRADE)
// =========================

const express = require("express");
const axios = require("axios");
const bodyParser = require("body-parser");
const cors = require("cors");
require("dotenv").config();

// 🔥 FIREBASE ADMIN
const admin = require("firebase-admin");
const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH || "./smart-chama-5ecaf-firebase-adminsdk-fbsvc-467347eff7.json";
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

const app = express();
app.use(bodyParser.json());
app.use(cors());

// =========================
// 🔐 DARAJA CREDENTIALS (SANDBOX)
// =========================
const consumerKey = process.env.MPESA_CONSUMER_KEY;
const consumerSecret = process.env.MPESA_CONSUMER_SECRET;
const shortCode = process.env.MPESA_SHORT_CODE || "174379";
const passKey = process.env.MPESA_PASS_KEY;
const callbackURL = process.env.MPESA_CALLBACK_URL;

if (!consumerKey || !consumerSecret || !passKey || !callbackURL) {
  throw new Error(
    "Missing required M-Pesa environment variables. Set MPESA_CONSUMER_KEY, MPESA_CONSUMER_SECRET, MPESA_PASS_KEY, and MPESA_CALLBACK_URL."
  );
}

// =========================
// 🔑 GET ACCESS TOKEN
// =========================
async function getAccessToken() {
  try {
    const auth = Buffer.from(`${consumerKey}:${consumerSecret}`).toString("base64");
    const response = await axios.get(
      "https://sandbox.safaricom.co.ke/oauth/v1/generate?grant_type=client_credentials",
      { headers: { Authorization: `Basic ${auth}` } }
    );
    return response.data.access_token;
  } catch (err) {
    console.error("❌ Error fetching access token:", err.message);
    throw err;
  }
}

// =========================
// 📲 STK PUSH - contributions & loans
// =========================
app.post("/stkpush", async (req, res) => {
  try {
    const { phone, amount, userId, organizationId, chamaId, type, loanId } = req.body;

    if (!phone || !amount || !userId || !chamaId || !type) {
      return res.status(400).json({ error: "Missing required fields" });
    }

    const token = await getAccessToken();
    const timestamp = new Date().toISOString().replace(/[-:.TZ]/g, "").slice(0, 14);
    const password = Buffer.from(shortCode + passKey + timestamp).toString("base64");

    const stkPushData = {
      BusinessShortCode: shortCode,
      Password: password,
      Timestamp: timestamp,
      TransactionType: "CustomerPayBillOnline",
      Amount: amount,
      PartyA: phone,
      PartyB: shortCode,
      PhoneNumber: phone,
      CallBackURL: callbackURL,
      AccountReference: "SmartChama",
      TransactionDesc: type === "loan_repayment" ? "Loan Repayment" : "Chama Contribution",
    };

    console.log("📤 Sending STK Push:", stkPushData);

    const responseMpesa = await axios.post(
      "https://sandbox.safaricom.co.ke/mpesa/stkpush/v1/processrequest",
      stkPushData,
      { headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" } }
    );

    console.log("📥 MPESA Response:", responseMpesa.data);

    // 🔥 SAVE TRANSACTION TO FIRESTORE (organization/chama structure)
    const transactionRef = db
      .collection("organizations")
      .doc(organizationId)
      .collection("chamas")
      .doc(chamaId)
      .collection("transactions")
      .doc();
    
    await transactionRef.set({
      userId,
      chamaId,
      organizationId,
      amount: Number(amount) || 0,
      type, // contribution | loan_repayment
      status: "pending",
      source: "mpesa",
      paymentMethod: "mpesa",
      loanId: loanId || null,
      checkoutRequestID: responseMpesa.data.CheckoutRequestID,
      description: type === "loan_repayment" ? "Loan repayment via M-Pesa" : "Contribution via M-Pesa",
      timestamp: new Date(),
      createdAt: new Date(),
      updatedAt: new Date(),
    });

    const mpesaRef = db.collection("mpesa_transactions").doc();
    await mpesaRef.set({
      userId,
      organizationId,
      chamaId,
      phone,
      amount,
      type,
      loanId: loanId || null,
      status: "pending",
      checkoutRequestID: responseMpesa.data.CheckoutRequestID,
      transactionDocId: transactionRef.id,
      createdAt: new Date(),
    });

    res.json({
      success: true,
      checkoutRequestID: responseMpesa.data.CheckoutRequestID,
      responseDescription: responseMpesa.data.ResponseDescription,
      transactionDocId: mpesaRef.id,
    });
  } catch (error) {
    console.error("❌ STK Push Error:", error.response?.data || error.message);
    res.status(500).json({ success: false, error: error.response?.data || error.message });
  }
});

// =========================
// 🔁 CALLBACK HANDLER
// =========================
app.post("/callback", async (req, res) => {
  console.log("📲 MPESA CALLBACK RECEIVED");

  try {
    const stkCallback = req.body.Body?.stkCallback;
    if (!stkCallback) return res.json({ ResultCode: 0, ResultDesc: "No callback data" });

    const { ResultCode, CheckoutRequestID } = stkCallback;

    const snapshot = await db.collection("mpesa_transactions")
      .where("checkoutRequestID", "==", CheckoutRequestID)
      .get();

    if (snapshot.empty) return res.json({ ResultCode: 0, ResultDesc: "Accepted" });

    const doc = snapshot.docs[0];
    const transaction = doc.data();

    if (ResultCode === 0) {
      const metadata = stkCallback.CallbackMetadata.Item;
      const amount = metadata.find((i) => i.Name === "Amount")?.Value || 0;
      const mpesaCode = metadata.find((i) => i.Name === "MpesaReceiptNumber")?.Value || "";

      console.log("✅ PAYMENT SUCCESS");

      await doc.ref.update({
        status: "success",
        mpesaCode,
        amount,
        updatedAt: new Date(),
      });

      // Update transaction in organization/chama structure
      if (transaction.transactionDocId && transaction.organizationId && transaction.chamaId) {
        await db
          .collection("organizations")
          .doc(transaction.organizationId)
          .collection("chamas")
          .doc(transaction.chamaId)
          .collection("transactions")
          .doc(transaction.transactionDocId)
          .set({
            status: "success",
            mpesaCode,
            amount,
            updatedAt: new Date(),
            timestamp: new Date(),
          }, { merge: true });
      }

      // Store in contributions or loan_repayments
      if (transaction.type === "contribution" && transaction.organizationId && transaction.chamaId) {
        await db
          .collection("organizations")
          .doc(transaction.organizationId)
          .collection("chamas")
          .doc(transaction.chamaId)
          .collection("contributions")
          .add({
          userId: transaction.userId,
          chamaId: transaction.chamaId,
          organizationId: transaction.organizationId,
          amount,
          description: "Contribution via M-Pesa",
          date: new Date(),
          paymentMethod: "mpesa",
          mpesaCode,
          status: "completed",
          createdAt: new Date(),
        });
      } else if (transaction.type === "loan_repayment" && transaction.organizationId && transaction.chamaId) {
        await db
          .collection("organizations")
          .doc(transaction.organizationId)
          .collection("chamas")
          .doc(transaction.chamaId)
          .collection("loan_repayments")
          .add({
          userId: transaction.userId,
          chamaId: transaction.chamaId,
          organizationId: transaction.organizationId,
          loanId: transaction.loanId,
          amount,
          date: new Date(),
          paymentMethod: "mpesa",
          mpesaCode,
          createdAt: new Date(),
        });
      }
    } else {
      console.log("❌ PAYMENT FAILED");
      await doc.ref.update({ status: "failed", updatedAt: new Date() });
      if (transaction.transactionDocId && transaction.organizationId && transaction.chamaId) {
        await db
          .collection("organizations")
          .doc(transaction.organizationId)
          .collection("chamas")
          .doc(transaction.chamaId)
          .collection("transactions")
          .doc(transaction.transactionDocId)
          .set({
            status: "failed",
            updatedAt: new Date(),
            timestamp: new Date(),
          }, { merge: true });
      }
    }
  } catch (err) {
    console.error("❌ Callback Error:", err);
  }

  res.json({ ResultCode: 0, ResultDesc: "Accepted" });
});

// =========================
// 🔹 TRANSACTION STATUS ENDPOINT
// =========================
app.get("/transaction-status/:checkoutRequestID", async (req, res) => {
  const { checkoutRequestID } = req.params;

  try {
    const snapshot = await db.collection("mpesa_transactions")
      .where("checkoutRequestID", "==", checkoutRequestID)
      .get();

    if (snapshot.empty) return res.status(404).json({ status: "not_found" });

    const transaction = snapshot.docs[0].data();
    res.json({ status: transaction.status });
  } catch (err) {
    console.error("❌ Transaction Status Error:", err);
    res.status(500).json({ error: "Failed to fetch transaction status" });
  }
});

// =========================
// 🚀 START SERVER
// =========================
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 SmartChama MPESA Server running on port ${PORT}`);
});