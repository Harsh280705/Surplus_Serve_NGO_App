// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// ============================================
// 🚀 TRIGGER: New Donation Created
// ============================================
exports.onDonationCreated = functions.firestore
  .document('donations/{donationId}')
  .onCreate(async (snap, context) => {
    try {
      const donation = snap.data();
      const donationId = context.params.donationId;
      
      // Only process pending donations
      if (donation.status !== 'pending') {
        console.log('Donation not pending, skipping notification');
        return null;
      }
      
      const donorLocation = donation.location; // GeoPoint
      const donationTitle = donation.itemName || 'Food Donation';
      
      if (!donorLocation) {
        console.error('Donation has no location');
        return null;
      }
      
      // Get all NGOs
      const ngosSnapshot = await db.collection('users')
        .where('userType', '==', 'ngo')
        .where('notificationsEnabled', '==', true)
        .get();
      
      const notifications = [];
      const tokens = [];
      
      for (const ngoDoc of ngosSnapshot.docs) {
        const ngoData = ngoDoc.data();
        const ngoId = ngoDoc.id;
        const ngoLocation = ngoData.location; // GeoPoint
        const fcmToken = ngoData.fcmToken;
        
        if (!ngoLocation) continue;
        
        // Calculate distance
        const distance = calculateDistance(
          donorLocation.latitude,
          donorLocation.longitude,
          ngoLocation.latitude,
          ngoLocation.longitude
        );
        
        const distanceStr = distance < 1 ? '<1' : distance.toFixed(1);
        
        // Create in-app notification
        notifications.push(
          db.collection('notifications').add({
            userId: ngoId,
            type: 'new_donation',
            title: '🍽️ New Donation Available!',
            body: `"${donationTitle}" is available ${distanceStr} km away from your location`,
            donationId: donationId,
            distance: distance,
            read: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          })
        );
        
        // Prepare push notification
        if (fcmToken && fcmToken.trim() !== '') {
          tokens.push({
            token: fcmToken,
            notification: {
              title: '🍽️ New Donation Available!',
              body: `"${donationTitle}" is ${distanceStr} km away`,
            },
            data: {
              type: 'new_donation',
              donationId: donationId,
              distance: distanceStr,
            },
            android: {
              priority: 'high',
              notification: {
                channelId: 'donation_channel',
                sound: 'default',
                priority: 'high',
              },
            },
            apns: {
              payload: {
                aps: {
                  sound: 'default',
                  badge: 1,
                },
              },
            },
          });
        }
      }
      
      // Save all in-app notifications
      await Promise.all(notifications);
      
      // Send push notifications in batches
      if (tokens.length > 0) {
        const batchSize = 500;
        for (let i = 0; i < tokens.length; i += batchSize) {
          const batch = tokens.slice(i, i + batchSize);
          try {
            const response = await messaging.sendEach(batch);
            console.log(`Sent ${response.successCount}/${batch.length} notifications`);
            
            // Handle failed tokens
            response.responses.forEach((resp, idx) => {
              if (!resp.success) {
                console.error(`Failed to send to token ${idx}:`, resp.error);
                // Optionally remove invalid tokens
                if (resp.error.code === 'messaging/invalid-registration-token' ||
                    resp.error.code === 'messaging/registration-token-not-registered') {
                  // You could add logic here to remove invalid tokens from users
                }
              }
            });
          } catch (error) {
            console.error('Batch send error:', error);
          }
        }
      }
      
      console.log(`✅ Notified ${ngosSnapshot.size} NGOs about donation ${donationId}`);
      return null;
    } catch (error) {
      console.error('Error in onDonationCreated:', error);
      return null;
    }
  });

// ============================================
// ✅ TRIGGER: Donation Accepted by NGO
// ============================================
exports.onDonationAccepted = functions.firestore
  .document('donations/{donationId}')
  .onUpdate(async (change, context) => {
    try {
      const before = change.before.data();
      const after = change.after.data();
      const donationId = context.params.donationId;

      // Trigger only when status changes TO 'accepted'
      if (before.status === 'accepted' || after.status !== 'accepted') {
        console.log('Donation not newly accepted, skipping notification');
        return null;
      }

      const ngoId = after.acceptedBy;
      const eventManagerId = after.createdBy;
      const donationTitle = after.itemName || 'Food Donation';

      if (!ngoId || !eventManagerId) {
        console.error('Missing NGO or Event Manager ID');
        return null;
      }

      // Fetch both users in parallel
      const [ngoDoc, emDoc] = await Promise.all([
        db.collection('users').doc(ngoId).get(),
        db.collection('users').doc(eventManagerId).get(),
      ]);

      if (!emDoc.exists) {
        console.log('Event Manager not found');
        return null;
      }

      const ngoData = ngoDoc.exists ? ngoDoc.data() : { name: 'An NGO' };
      const emData = emDoc.data();
      const emFcmToken = emData.fcmToken;
      const notificationsEnabled = emData.notificationsEnabled !== false;

      if (!notificationsEnabled) {
        console.log('Event Manager has notifications disabled');
        return null;
      }

      // Create in-app notification
      await db.collection('notifications').add({
        userId: eventManagerId,
        type: 'donation_accepted',
        title: '🤝 Donation Accepted!',
        body: `${ngoData.name} has accepted your "${donationTitle}" donation.`,
        donationId: donationId,
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Send push notification
      if (emFcmToken && emFcmToken.trim() !== '') {
        const chatId = [ngoId, eventManagerId].sort().join('_');

        try {
          await messaging.send({
            token: emFcmToken,
            notification: {
              title: '🤝 Donation Accepted!',
              body: `${ngoData.name} accepted your "${donationTitle}" donation.`,
            },
            data: {
              type: 'donation_accepted',
              donationId: donationId,
              chatId: chatId,
            },
            android: {
              priority: 'high',
              notification: {
                channelId: 'donation_channel',
                sound: 'default',
              },
            },
            apns: {
              payload: {
                aps: {
                  sound: 'default',
                  badge: 1,
                },
              },
            },
          });
          console.log('✅ Acceptance notification sent to Event Manager');
        } catch (error) {
          console.error('Error sending acceptance push notification:', error);
        }
      }

      return null;
    } catch (error) {
      console.error('Error in onDonationAccepted:', error);
      return null;
    }
  });

// ============================================
// 🎉 TRIGGER: Donation Confirmed
// ============================================
exports.onDonationConfirmed = functions.firestore
  .document('donations/{donationId}')
  .onUpdate(async (change, context) => {
    try {
      const before = change.before.data();
      const after = change.after.data();
      const donationId = context.params.donationId;
      
      // Check if status changed to 'confirmed'
      if (before.status !== 'confirmed' && after.status === 'confirmed') {
        const ngoId = after.acceptedBy;
        const donationTitle = after.itemName || 'Food Donation';
        
        if (!ngoId) {
          console.log('No NGO to notify');
          return null;
        }
        
        // Get NGO data
        const ngoDoc = await db.collection('users').doc(ngoId).get();
        if (!ngoDoc.exists) {
          console.log('NGO not found');
          return null;
        }
        
        const ngoData = ngoDoc.data();
        const fcmToken = ngoData.fcmToken;
        
        // Create in-app notification
        await db.collection('notifications').add({
          userId: ngoId,
          type: 'donation_confirmed',
          title: '✅ Donation Confirmed!',
          body: `The donation "${donationTitle}" has been confirmed as delivered by the event manager.`,
          donationId: donationId,
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        
        // Send push notification
        if (fcmToken && fcmToken.trim() !== '') {
          try {
            await messaging.send({
              token: fcmToken,
              notification: {
                title: '✅ Donation Confirmed!',
                body: `"${donationTitle}" delivery confirmed!`,
              },
              data: {
                type: 'donation_confirmed',
                donationId: donationId,
              },
              android: {
                priority: 'high',
                notification: {
                  channelId: 'donation_channel',
                  sound: 'default',
                },
              },
              apns: {
                payload: {
                  aps: {
                    sound: 'default',
                    badge: 1,
                  },
                },
              },
            });
            console.log('✅ Confirmation notification sent to NGO');
          } catch (error) {
            console.error('Error sending confirmation push:', error);
          }
        }
      }
      
      return null;
    } catch (error) {
      console.error('Error in onDonationConfirmed:', error);
      return null;
    }
  });

// ============================================
// 💬 TRIGGER: New Chat Message
// ============================================
exports.onNewChatMessage = functions.firestore
  .document('chat_rooms/{chatRoomId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    try {
      const message = snap.data();
      const chatRoomId = context.params.chatRoomId;
      const receiverId = message.receiverId;
      const senderName = message.senderName || 'Someone';
      const messageText = message.message || '';
      
      if (!receiverId) {
        console.log('No receiver specified');
        return null;
      }
      
      // Get receiver data
      const receiverDoc = await db.collection('users').doc(receiverId).get();
      if (!receiverDoc.exists) {
        console.log('Receiver not found');
        return null;
      }
      
      const receiverData = receiverDoc.data();
      const fcmToken = receiverData.fcmToken;
      const notificationsEnabled = receiverData.notificationsEnabled !== false;
      
      if (!notificationsEnabled) {
        console.log('Notifications disabled for receiver');
        return null;
      }
      
      // Send push notification
      if (fcmToken && fcmToken.trim() !== '') {
        try {
          await messaging.send({
            token: fcmToken,
            notification: {
              title: `💬 ${senderName}`,
              body: messageText.substring(0, 100),
            },
            data: {
              type: 'chat',
              chatRoomId: chatRoomId,
              senderId: message.senderId,
            },
            android: {
              priority: 'high',
              notification: {
                channelId: 'chat_channel',
                sound: 'default',
                tag: chatRoomId, // Group notifications by chat
              },
            },
            apns: {
              payload: {
                aps: {
                  sound: 'default',
                  badge: 1,
                  threadId: chatRoomId, // Group notifications
                },
              },
            },
          });
          console.log('✅ Chat notification sent');
        } catch (error) {
          console.error('Error sending chat notification:', error);
        }
      }
      
      return null;
    } catch (error) {
      console.error('Error in onNewChatMessage:', error);
      return null;
    }
  });

// ============================================
// 📊 HELPER: Calculate Distance (Haversine)
// ============================================
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371; // Earth radius in km
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  
  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function toRad(degrees) {
  return degrees * (Math.PI / 180);
}

// ============================================
// 🧹 CLEANUP: Delete old notifications (optional)
// ============================================
exports.cleanupOldNotifications = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    
    const oldNotifications = await db.collection('notifications')
      .where('createdAt', '<', thirtyDaysAgo)
      .limit(500)
      .get();
    
    const batch = db.batch();
    oldNotifications.docs.forEach((doc) => {
      batch.delete(doc.ref);
    });
    
    await batch.commit();
    console.log(`Deleted ${oldNotifications.size} old notifications`);
    return null;
  });