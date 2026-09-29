// SmartChama M-Pesa Integration backend entry point.

require("dotenv").config();

const axios = require("axios");
const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");
const { createApp } = require("./app");

function loadServiceAccount() {
  if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    return JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
  }
  const serviceAccountPath =
    process.env.FIREBASE_SERVICE_ACCOUNT_PATH ||
    path.join(__dirname, "serviceAccountKey.json");
  if (!fs.existsSync(serviceAccountPath)) {
    throw new Error(
      "Firebase credentials missing. Set FIREBASE_SERVICE_ACCOUNT_JSON or FIREBASE_SERVICE_ACCOUNT_PATH."
    );
  }
  return JSON.parse(fs.readFileSync(serviceAccountPath, "utf8"));
}

admin.initializeApp({
  credential: admin.credential.cert(loadServiceAccount()),
});

const db = admin.firestore();

const consumerKey = process.env.MPESA_CONSUMER_KEY;
const consumerSecret = process.env.MPESA_CONSUMER_SECRET;
const shortCode = process.env.MPESA_SHORT_CODE || "174379";
const passKey = process.env.MPESA_PASS_KEY;
const callbackURL = process.env.MPESA_CALLBACK_URL;
const mpesaEnv = (process.env.MPESA_ENV || "sandbox").toLowerCase();
const mpesaBaseUrl =
  mpesaEnv === "production"
    ? "https://api.safaricom.co.ke"
    : "https://sandbox.safaricom.co.ke";

if (!consumerKey || !consumerSecret || !passKey || !callbackURL) {
  throw new Error(
    "Missing required M-Pesa environment variables. Set MPESA_CONSUMER_KEY, MPESA_CONSUMER_SECRET, MPESA_PASS_KEY, and MPESA_CALLBACK_URL."
  );
}

async function getAccessToken() {
  const auth = Buffer.from(`${consumerKey}:${consumerSecret}`).toString("base64");
  const response = await axios.get(
    `${mpesaBaseUrl}/oauth/v1/generate?grant_type=client_credentials`,
    { headers: { Authorization: `Basic ${auth}` } }
  );
  return response.data.access_token;
}

const app = createApp({
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
});

const PORT = process.env.PORT || 3000;

if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`SmartChama MPESA Server running on port ${PORT}`);
  });
}

module.exports = { app, createApp, db, admin, getAccessToken };
