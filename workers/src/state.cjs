const { AsyncLocalStorage } = require("node:async_hooks");
const { Firestore } = require("./firestore.cjs");
const scope = new AsyncLocalStorage();
const current = () => {
  const value = scope.getStore();
  if (!value) throw new Error("Backend scope is missing");
  return value;
};
const db = new Firestore(
  "familyguard-v2-app",
  (...args) => current().client.firestore(...args),
  (paths) => current().created.push(...paths),
);
module.exports = { scope, current, db };
