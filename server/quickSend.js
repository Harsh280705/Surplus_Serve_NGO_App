// quickSend.js
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const messaging = admin.messaging();

const message = {
  notification: { title: 'Test', body: 'Hello all_users' },
  data: { type: 'test', foo: 'bar' },
  topic: 'all_users'
};

messaging.send(message).then(r => console.log('sent', r)).catch(e => console.error(e));
