// Test-only adapter injection. Never bundled or deployed with the Worker.
const Module = require("node:module");
const { Firestore, Timestamp, FieldValue } = require("../src/firestore.cjs");
const host = process.env.FIRESTORE_EMULATOR_HOST;
if (!/^127\.0\.0\.1:\d+$/.test(host || ""))
  throw new Error("A local demo Firestore emulator is required");
const db = new Firestore(
  "demo-family-guard",
  async (path, body, method = "POST") => {
    const response = await fetch(`http://${host}/v1/${path}`, {
      method,
      headers: {
        "Content-Type": "application/json",
        Authorization: "Bearer owner",
      },
      body: body ? JSON.stringify(body) : undefined,
    });
    const data = await response.json();
    if (!response.ok)
      throw Object.assign(new Error("Emulator request failed"), {
        code: (data.error?.status || "INTERNAL")
          .toLowerCase()
          .replaceAll("_", "-"),
      });
    return data;
  },
);
const original = Module._load;
Module._load = function (id, parent, isMain) {
  if (id === "firebase-admin/firestore")
    return { getFirestore: () => db, Timestamp, FieldValue };
  if (id === "firebase-admin/app")
    return {
      initializeApp: () => ({}),
      getApps: () => [],
      deleteApp: async () => {},
    };
  if (id === "firebase-admin/auth") return { getAuth: () => ({}) };
  if (id === "firebase-admin/messaging") return { getMessaging: () => ({}) };
  if (id === "firebase-functions/v2/https")
    return {
      HttpsError: class extends Error {
        constructor(code, message) {
          super(message);
          this.code = code;
        }
      },
      onCall: (_options, fn) => Object.assign(fn, { run: fn }),
    };
  if (id === "firebase-functions/v2/firestore")
    return { onDocumentCreated: (_options, fn) => fn };
  if (id === "firebase-functions/v2/scheduler")
    return { onSchedule: (_options, fn) => fn };
  return original.apply(this, arguments);
};
