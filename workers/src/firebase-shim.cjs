const { current, db } = require("./state.cjs");
const { Timestamp, FieldValue } = require("./firestore.cjs");
class HttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}
const wrap = (kind, handler, options) =>
  Object.assign(handler, { kind, options });
module.exports = {
  initializeApp: () => {},
  getFirestore: () => db,
  Timestamp,
  FieldValue,
  HttpsError,
  getAuth: () => ({
    updateUser: (...a) => current().client.updateUser(...a),
    deleteUser: (...a) => current().client.deleteUser(...a),
  }),
  getMessaging: () => ({ send: (...a) => current().client.send(...a) }),
  onCall: (options, handler) => wrap("callable", handler, options),
  onDocumentCreated: (options, handler) => wrap("document", handler, options),
  onSchedule: (options, handler) => wrap("schedule", handler, options),
};
