// sendNotification.js
// Place this in D:\surplus_serve\server
// Requires: npm install firebase-admin

const admin = require('firebase-admin');
const path = require('path');

// 1) Point to your service account JSON file (replace filename if needed)
const serviceAccount = require(path.join(__dirname, 'serviceAccountKey.json'));

// Initialize admin SDK
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});
const db = admin.firestore();
const messaging = admin.messaging();

console.log('🔥 Notification watcher starting...');

// Utility: build message payload (notification + data)
function buildDonationMessage(donationDoc) {
  const donation = donationDoc.data();
  const title = donation.itemName ? `New donation: ${donation.itemName}` : 'New donation';
  const body = donation.description || donation.itemName || 'A new donation is available';

  return {
    notification: { title, body },
    data: {
      type: 'donation',
      donationId: donationDoc.id,
      title: title,
      body: body,
      createdBy: donation.createdBy || '',
    }
  };
}

function buildChatMessage(chatDoc) {
  const chat = chatDoc.data();
  const title = chat.senderName ? `${chat.senderName}` : 'New message';
  const body = chat.text || 'You have a new message';

  return {
    notification: { title, body },
    data: {
      type: 'chat',
      chatId: chatDoc.id,
      text: chat.text || '',
      fromUid: chat.fromUid || '',
      toUid: chat.toUid || '',
    }
  };
}

// 2) Listen for new donations — send to topic 'all_users'
db.collection('donations')
  .orderBy('createdAt', 'desc')
  .onSnapshot((snap) => {
    snap.docChanges().forEach(async (change) => {
      if (change.type === 'added') {
        const doc = change.doc;
        // Avoid duplicates from initial snapshot by checking recent timestamp (optional)
        // If you want to ignore historical docs, add logic here comparing createdAt to Date.now()-N
        const msg = buildDonationMessage(doc);
        const payload = {
          ...msg,
          topic: 'all_users',
          android: {
            priority: 'high',
          },
        };
        try {
          const res = await messaging.send(payload);
          console.log(`✅ Donation notification sent (doc=${doc.id}) -> messageId: ${res}`);
        } catch (err) {
          console.error('❌ Donation send error:', err);
        }
      }
    });
  }, (err) => {
    console.error('Donation listener error:', err);
  });


// 3) Listen for new chat messages — prefer topic user_<toUid> if present, else use token stored in users collection
db.collection('chats')
  .orderBy('createdAt', 'desc')
  .onSnapshot((snap) => {
    snap.docChanges().forEach(async (change) => {
      if (change.type === 'added') {
        const doc = change.doc;
        const chat = doc.data();
        const toUid = chat.toUid;
        const msg = buildChatMessage(doc);

        // Prefer topic (user_<uid>) — you already subscribe client to user_<uid>.
        if (toUid) {
          const payload = {
            ...msg,
            topic: `user_${toUid}`,
            android: { priority: 'high' },
          };
          try {
            const res = await messaging.send(payload);
            console.log(`✅ Chat notification sent to topic user_${toUid} (chat=${doc.id}) -> ${res}`);
            return;
          } catch (err) {
            console.error('❌ Topic send failed, will attempt token fallback:', err);
          }
        }

        // Fallback: look up user's token in Firestore and send to token
        if (toUid) {
          try {
            const userDoc = await db.collection('users').doc(toUid).get();
            const token = userDoc.exists ? userDoc.data().fcmToken : null;
            if (token) {
              const payload = {
                ...msg,
                token: token,
                android: { priority: 'high' },
              };
              const res = await messaging.send(payload);
              console.log(`✅ Chat notification sent to token (chat=${doc.id}) -> ${res}`);
            } else {
              console.warn(`⚠️ No token for user ${toUid}, chat ${doc.id}`);
            }
          } catch (err) {
            console.error('❌ Token send fallback error:', err);
          }
        }
      }
    });
  }, (err) => {
    console.error('Chat listener error:', err);
  });

console.log('Listening for donations & chats. Keep this script running (node sendNotification.js).');
