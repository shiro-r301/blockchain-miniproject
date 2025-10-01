const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json'); // replace with your key path

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

module.exports = db;
