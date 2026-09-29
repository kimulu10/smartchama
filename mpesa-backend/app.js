const express = require("express");
const axios = require("axios");
const bodyParser = require("body-parser");
const cors = require("cors");
const { createAuthMiddleware } = require("./middleware/auth");

function parseAllowedOrigins() {
  const raw = process.env.ALLOWED_ORIGINS || "";
  return raw
    .split(",")
    .map((origin) => origin.trim())
    .filter(Boolean);
}

function createApp({
  db,
  admin,
  getAccessToken,
  consumerKey,
  consumerSecret,
  shortCode,
  passKey,
  callbackURL,
  mpesaBaseUrl,
  mpesaEnv,
}) {
  const app = express();
  app.use(bodyParser.json());

  const allowedOrigins = parseAllowedOrigins();
  app.use(
    cors({
      origin(origin, callback) {
        if (!origin || allowedOrigins.length === 0 || allowedOrigins.includes(origin)) {
          callback(null, true);
          return;
        }
        callback(new Error("Not allowed by CORS"));
      },
    })
  );

  const {
    verifyFirebaseToken,
    verifyStkPushAccess,
    verifyTransactionStatusAccess,
  } = createAuthMiddleware(db, admin);

  app.get("/health", (_req, res) => {
    res.json({ ok: true, env: mpesaEnv });
  });

  app.post(
    "/stkpush",
    verifyFirebaseToken,
    verifyStkPushAccess,
    async (req, res) => {
      try {
        const { phone, amount, userId, organizationId, chamaId, type, loanId } =
          req.body;

        if (!phone || !amount || !userId || !organizationId || !chamaId || !type) {
          return res.status(400).json({
            success: false,
            error:
              "Missing required fields: phone, amount, userId, organizationId, chamaId, type",
          });
        }

        const token = await getAccessToken();
        const timestamp = new Date()
          .toISOString()
          .replace(/[-:.TZ]/g, "")
          .slice(0, 14);
        const password = Buffer.from(shortCode + passKey + timestamp).toString(
          "base64"
        );

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
          TransactionDesc:
            type === "loan_repayment" ? "Loan Repayment" : "Chama Contribution",
        };

        const responseMpesa = await axios.post(
          `${mpesaBaseUrl}/mpesa/stkpush/v1/processrequest`,
          stkPushData,
          {
            headers: {
              Authorization: `Bearer ${token}`,
              "Content-Type": "application/json",
            },
          }
        );

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
          type,
          status: "pending",
          source: "mpesa",
          paymentMethod: "mpesa",
          loanId: loanId || null,
          checkoutRequestID: responseMpesa.data.CheckoutRequestID,
          description:
            type === "loan_repayment"
              ? "Loan repayment via M-Pesa"
              : "Contribution via M-Pesa",
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
          transactionDocId: transactionRef.id,
          mpesaTransactionId: mpesaRef.id,
        });
      } catch (error) {
        console.error("STK Push Error:", error.response?.data || error.message);
        res.status(500).json({
          success: false,
          error: error.response?.data || error.message,
        });
      }
    }
  );

  app.post("/callback", async (req, res) => {
    try {
      const stkCallback = req.body.Body?.stkCallback;
      if (!stkCallback) {
        return res.json({ ResultCode: 0, ResultDesc: "No callback data" });
      }

      const { ResultCode, CheckoutRequestID } = stkCallback;

      const snapshot = await db
        .collection("mpesa_transactions")
        .where("checkoutRequestID", "==", CheckoutRequestID)
        .get();

      if (snapshot.empty) {
        return res.json({ ResultCode: 0, ResultDesc: "Accepted" });
      }

      const doc = snapshot.docs[0];
      const transaction = doc.data();

      if (ResultCode === 0) {
        const metadata = stkCallback.CallbackMetadata.Item;
        const amount = metadata.find((i) => i.Name === "Amount")?.Value || 0;
        const mpesaCode =
          metadata.find((i) => i.Name === "MpesaReceiptNumber")?.Value || "";

        await doc.ref.update({
          status: "success",
          mpesaCode,
          amount,
          updatedAt: new Date(),
        });

        if (
          transaction.transactionDocId &&
          transaction.organizationId &&
          transaction.chamaId
        ) {
          await db
            .collection("organizations")
            .doc(transaction.organizationId)
            .collection("chamas")
            .doc(transaction.chamaId)
            .collection("transactions")
            .doc(transaction.transactionDocId)
            .set(
              {
                status: "success",
                mpesaCode,
                amount,
                updatedAt: new Date(),
                timestamp: new Date(),
              },
              { merge: true }
            );
        }

        if (
          transaction.type === "contribution" &&
          transaction.organizationId &&
          transaction.chamaId
        ) {
          const contributionsRef = db
            .collection("organizations")
            .doc(transaction.organizationId)
            .collection("chamas")
            .doc(transaction.chamaId)
            .collection("contributions");

          const pendingSnap = await contributionsRef
            .where("checkoutRequestID", "==", CheckoutRequestID)
            .limit(1)
            .get();

          if (!pendingSnap.empty) {
            await pendingSnap.docs[0].ref.update({
              status: "completed",
              mpesaCode,
              amount,
              updatedAt: new Date(),
            });
          } else {
            await contributionsRef.add({
              userId: transaction.userId,
              chamaId: transaction.chamaId,
              organizationId: transaction.organizationId,
              amount,
              description: "Contribution via M-Pesa",
              date: new Date(),
              paymentMethod: "mpesa",
              mpesaCode,
              checkoutRequestID: CheckoutRequestID,
              status: "completed",
              createdAt: new Date(),
            });
          }
        } else if (
          transaction.type === "loan_repayment" &&
          transaction.organizationId &&
          transaction.chamaId
        ) {
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
        await doc.ref.update({ status: "failed", updatedAt: new Date() });
        if (
          transaction.transactionDocId &&
          transaction.organizationId &&
          transaction.chamaId
        ) {
          await db
            .collection("organizations")
            .doc(transaction.organizationId)
            .collection("chamas")
            .doc(transaction.chamaId)
            .collection("transactions")
            .doc(transaction.transactionDocId)
            .set(
              {
                status: "failed",
                updatedAt: new Date(),
                timestamp: new Date(),
              },
              { merge: true }
            );
        }
      }
    } catch (err) {
      console.error("Callback Error:", err);
    }

    res.json({ ResultCode: 0, ResultDesc: "Accepted" });
  });

  app.get(
    "/transaction-status/:checkoutRequestID",
    verifyFirebaseToken,
    verifyTransactionStatusAccess,
    (req, res) => {
      res.json({ status: req.mpesaTransaction.status });
    }
  );

  return app;
}

module.exports = { createApp, parseAllowedOrigins };
