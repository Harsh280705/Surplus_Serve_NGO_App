// listenAndNotify.js
// Run: node listenAndNotify.js
// Listens for new donations and sends an FCM broadcast to 'all_users' topic.

const admin = require('firebase-admin');
const path = require('path');

const serviceAccountPath = path.join(__dirname, 'serviceAccountKey.json'); // your key file
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();
const messaging = admin.messaging();

console.log('🔔 Firestore listener starting...');

let firstSnapshotSeen = false;

// Listen to donations collection (only new pending donations)
db.collection('donations')
  .orderBy('createdAt', 'desc')
  .limit(50) // initial query size
  .onSnapshot(
    (snapshot) => {
      // On first snapshot we don't want to notify existing docs.
      if (!firstSnapshotSeen) {
        console.log('ℹ️ First snapshot loaded, skipping existing docs notifications.');
        firstSnapshotSeen = true;
        return;
      }

      snapshot.docChanges().forEach(async (change) => {
        try {
          if (change.type === 'added') {
            const doc = change.doc.data();
            const donationId = change.doc.id;
            // Only notify for pending donations (you might have different logic)
            const status = doc.status || '';
            if (status !== 'pending') return;

            // Build notification payload
            const title = doc.itemName || 'New donation available';
            const body = doc.description || `${title} near you`;

            const dataPayload = {
              donationId: donationId,
              type: 'donation',
              title: title,
              body: body,
              createdBy: doc.createdBy || '',
            };

            const message = {
              topic: 'all_users',
              notification: {
                title: title,
                body: body,
              },
              data: dataPayload,
              android: {
                priority: 'high',
                notification: {
                  channelId: 'donation_channel',
                  defaultVibrateTimings: true,
                },
              },
              apns: {
                headers: {
                  'apns-priority': '10',
                },
              },
            };

            const resp = await messaging.send(message);
            console.log(`✅ Sent FCM for donation ${donationId}: ${resp}`);
          }
        } catch (err) {
          console.error('❌ Error processing change:', err);
        }
      });
    },
    (err) => {
      console.error('❌ Firestore listener error:', err);
      console.log('🕒 Will try to reconnect in 5 seconds...');
      setTimeout(() => {
        process.exit(1); // let an external supervisor restart it, or you can implement reconnect here
      }, 5000);
    }
  );
