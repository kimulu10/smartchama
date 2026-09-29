/**
 * Firebase ID token verification and chama membership checks.
 */

function createAuthMiddleware(db, admin) {
  async function verifyFirebaseToken(req, res, next) {
    const authHeader = req.headers.authorization || "";
    const match = authHeader.match(/^Bearer\s+(.+)$/i);
    if (!match) {
      return res.status(401).json({
        success: false,
        error: "Missing or invalid Authorization header.",
      });
    }

    try {
      const decoded = await admin.auth().verifyIdToken(match[1]);
      req.user = decoded;
      return next();
    } catch (err) {
      console.error("Auth verification failed:", err.message);
      return res.status(401).json({
        success: false,
        error: "Invalid or expired authentication token.",
      });
    }
  }

  async function verifyStkPushAccess(req, res, next) {
    const { userId, organizationId, chamaId } = req.body;

    if (userId !== req.user.uid) {
      return res.status(403).json({
        success: false,
        error: "userId must match authenticated user.",
      });
    }

    try {
      const memberSnap = await db
        .collection("organizations")
        .doc(organizationId)
        .collection("chamas")
        .doc(chamaId)
        .collection("members")
        .where("userId", "==", req.user.uid)
        .limit(1)
        .get();

      if (memberSnap.empty) {
        return res.status(403).json({
          success: false,
          error: "You are not a member of this chama.",
        });
      }

      return next();
    } catch (err) {
      console.error("Membership check failed:", err.message);
      return res.status(500).json({
        success: false,
        error: "Failed to verify chama membership.",
      });
    }
  }

  async function verifyTransactionStatusAccess(req, res, next) {
    const { checkoutRequestID } = req.params;

    try {
      const snapshot = await db
        .collection("mpesa_transactions")
        .where("checkoutRequestID", "==", checkoutRequestID)
        .limit(1)
        .get();

      if (snapshot.empty) {
        return res.status(404).json({ status: "not_found" });
      }

      const transaction = snapshot.docs[0].data();
      if (transaction.userId !== req.user.uid) {
        return res.status(403).json({
          success: false,
          error: "You cannot view this transaction.",
        });
      }

      req.mpesaTransaction = transaction;
      req.mpesaTransactionDoc = snapshot.docs[0];
      return next();
    } catch (err) {
      console.error("Transaction access check failed:", err.message);
      return res.status(500).json({
        error: "Failed to verify transaction access.",
      });
    }
  }

  return {
    verifyFirebaseToken,
    verifyStkPushAccess,
    verifyTransactionStatusAccess,
  };
}

module.exports = { createAuthMiddleware };
