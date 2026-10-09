const { HttpsError } = require('firebase-functions/v2/https');

function authenticated(request) {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Please sign in first.');
  // Older clients omitted this fence. New clients bind actions to the account
  // that initiated them, even if SDK token retrieval races an account switch.
  if (request.data?.expectedUid !== undefined && request.data.expectedUid !== uid) {
    throw new HttpsError('failed-precondition', 'Your account changed. Please try again.');
  }
  return uid;
}
module.exports = { authenticated };
