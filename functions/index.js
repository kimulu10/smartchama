const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();

exports.processContribution = functions.firestore
  .document('organizations/{organizationId}/chamas/{chamaId}/contributions/{contributionId}')
  .onCreate(async (snap, context) => {
    const contribution = snap.data();
    const { organizationId, chamaId } = context.params;

    try {
      await db.collection('organizations').doc(organizationId)
        .collection('chamas').doc(chamaId)
        .collection('transactions').add({
          userId: contribution.userId || '',
          chamaId: chamaId,
          organizationId: organizationId,
          amount: contribution.amount || 0,
          type: 'contribution',
          description: contribution.description || 'Contribution',
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          status: contribution.status || 'completed',
          paymentMethod: contribution.paymentMethod || 'manual',
        });

      if (contribution.status === 'completed') {
        await sendToTopic(chamaId, {
          title: 'Contribution Received',
          body: `KES ${(contribution.amount || 0).toLocaleString()} contribution received`,
        });
      }

      console.log('Contribution processed successfully');
    } catch (error) {
      console.error('Error processing contribution:', error);
    }
  });

exports.processLoanRequest = functions.firestore
  .document('organizations/{organizationId}/chamas/{chamaId}/loans/{loanId}')
  .onCreate(async (snap, context) => {
    const loan = snap.data();
    const { organizationId, chamaId } = context.params;

    try {
      const membersSnapshot = await db.collection('organizations').doc(organizationId)
        .collection('chamas').doc(chamaId)
        .collection('members')
        .where('role', 'in', ['admin', 'chairman', 'treasurer'])
        .get();

      const tokens = [];
      membersSnapshot.forEach(doc => {
        const member = doc.data();
        if (member.fcmToken) {
          tokens.push(member.fcmToken);
        }
      });

      if (tokens.length > 0) {
        await admin.messaging().sendMulticast({
          tokens: tokens,
          notification: {
            title: 'New Loan Request',
            body: `${loan.memberName || 'A member'} requested KES ${(loan.amount || 0).toLocaleString()}`,
          },
          data: {
            type: 'loan_request',
            chamaId: chamaId,
            loanId: context.params.loanId,
          },
        });
      }

      console.log('Loan request notification sent');
    } catch (error) {
      console.error('Error processing loan request:', error);
    }
  });

exports.processLoanStatusChange = functions.firestore
  .document('organizations/{organizationId}/chamas/{chamaId}/loans/{loanId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const { organizationId, chamaId } = context.params;

    if (before.status !== after.status && (after.status === 'approved' || after.status === 'rejected')) {
      try {
        const userDoc = await db.collection('users').doc(after.userId).get();
        const userData = userDoc.data();

        if (userData && userData.fcmToken) {
          await admin.messaging().send({
            token: userData.fcmToken,
            notification: {
              title: after.status === 'approved' ? 'Loan Approved' : 'Loan Rejected',
              body: after.status === 'approved'
                ? `Your loan of KES ${(after.amount || 0).toLocaleString()} has been approved`
                : `Your loan of KES ${(after.amount || 0).toLocaleString()} has been rejected`,
            },
            data: {
              type: 'loan_status',
              chamaId: chamaId,
              loanId: context.params.loanId,
              status: after.status,
            },
          });
        }

        console.log('Loan status notification sent');
      } catch (error) {
        console.error('Error sending loan status notification:', error);
      }
    }
  });

exports.scheduledFraudScan = functions.pubsub
  .schedule('every 6 hours')
  .onRun(async (context) => {
    try {
      const orgsSnapshot = await db.collection('organizations').get();

      for (const orgDoc of orgsSnapshot.docs) {
        const chamasSnapshot = await orgDoc.reference.collection('chamas').get();

        for (const chamaDoc of chamasSnapshot.docs) {
          await performFraudScan(orgDoc.id, chamaDoc.id);
        }
      }

      console.log('Scheduled fraud scan completed');
    } catch (error) {
      console.error('Error in scheduled fraud scan:', error);
    }
  });

exports.sendContributionReminders = functions.pubsub
  .schedule('0 9 * * *')
  .timeZone('Africa/Nairobi')
  .onRun(async (context) => {
    try {
      const now = admin.firestore.Timestamp.now();
      const tomorrow = new Date();
      tomorrow.setDate(tomorrow.getDate() + 1);

      const chamasSnapshot = await db.collection('chamas')
        .where('rules.contributionDeadline', '<=', admin.firestore.Timestamp.fromDate(tomorrow))
        .where('rules.contributionDeadline', '>=', now)
        .get();

      for (const chamaDoc of chamasSnapshot.docs) {
        const chama = chamaDoc.data();
        const membersSnapshot = await chamaDoc.ref.collection('members').get();

        const tokens = [];
        membersSnapshot.forEach(doc => {
          const member = doc.data();
          if (member.fcmToken) {
            tokens.push(member.fcmToken);
          }
        });

        if (tokens.length > 0) {
          await admin.messaging().sendMulticast({
            tokens: tokens,
            notification: {
              title: 'Contribution Due Tomorrow',
              body: `Your ${chama.name || 'chama'} contribution of KES ${chama.rules?.contributionAmount || 0} is due tomorrow`,
            },
            data: {
              type: 'contribution_reminder',
              chamaId: chamaDoc.id,
            },
          });
        }
      }

      console.log('Contribution reminders sent');
    } catch (error) {
      console.error('Error sending contribution reminders:', error);
    }
  });

exports.cleanupOldNotifications = functions.pubsub
  .schedule('0 0 * * 0')
  .onRun(async (context) => {
    try {
      const thirtyDaysAgo = new Date();
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

      const oldNotifications = await db.collection('notification_queue')
        .where('createdAt', '<', admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
        .limit(500)
        .get();

      const batch = db.batch();
      oldNotifications.docs.forEach(doc => {
        batch.delete(doc.ref);
      });
      await batch.commit();

      console.log(`Cleaned up ${oldNotifications.size} old notifications`);
    } catch (error) {
      console.error('Error cleaning up old notifications:', error);
    }
  });

async function performFraudScan(organizationId, chamaId) {
  const alerts = [];

  const transactionsSnapshot = await db.collection('organizations').doc(organizationId)
    .collection('chamas').doc(chamaId)
    .collection('transactions')
    .orderBy('timestamp', 'asc')
    .get();

  const userAmounts = {};
  const userDailyTransactions = {};

  transactionsSnapshot.forEach(doc => {
    const data = doc.data();
    const amount = data.amount || 0;
    const userId = data.userId || '';
    const type = data.type || '';
    const status = data.status || '';
    const timestamp = data.timestamp;

    if (type === 'contribution' && (status === 'completed' || status === 'success')) {
      const key = `${userId}-${amount}`;
      userAmounts[key] = (userAmounts[key] || 0) + 1;

      if (timestamp) {
        const dayKey = timestamp.toDate().toISOString().split('T')[0];
        const dailyKey = `${userId}-${dayKey}`;
        userDailyTransactions[dailyKey] = (userDailyTransactions[dailyKey] || 0) + 1;

        if (userDailyTransactions[dailyKey] > 3) {
          alerts.push({
            id: `dup_${userId}_${dayKey}`,
            type: 'Duplicate Transaction',
            severity: 'medium',
            description: `User has ${userDailyTransactions[dailyKey]} transactions on ${dayKey}`,
            detectedAt: admin.firestore.FieldValue.serverTimestamp(),
            resolved: false,
          });
        }
      }
    }
  });

  if (alerts.length > 0) {
    await db.collection('organizations').doc(organizationId)
      .collection('chamas').doc(chamaId)
      .collection('fraud_alerts').add({
        alerts: alerts,
        scannedAt: admin.firestore.FieldValue.serverTimestamp(),
        alertCount: alerts.length,
      });
  }
}

async function sendToTopic(topic, { title, body }) {
  try {
    await admin.messaging().send({
      topic: topic,
      notification: { title, body },
    });
  } catch (error) {
    console.error('Error sending to topic:', error);
  }
}
