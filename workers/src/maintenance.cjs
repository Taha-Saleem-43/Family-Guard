// Split maintenance across signed HTTP invocations, not a paid queue/service.
const recoveryIds = Object.freeze(["sosFanout", "placeFanout", "sosPending", "sosStalled", "placePending", "placeStalled", "accountsPending", "accountsStalled"]);
// Accept already-signed requests from the preceding deployment during rollout.
const legacyRecoveryIds = Object.freeze(["sosDeliveries", "placeDeliveries", "accounts"]);
const cleanupCollections = Object.freeze(["sosPushDeliveries", "placePushDeliveries", "pushDevices", "accountDeletions",
  "inviteAttempts", "circleInvites", "placePresence", "placeEvents", "sos_alerts", "points"]);
const historyPages = 4;
const historyPageSize = 50;

function createMaintenance({ db, Timestamp, dispatch }) {
  async function recover(id, env) {
    if (legacyRecoveryIds.includes(id)) {
      const prefix = id === "accounts" ? "accounts" : id === "sosDeliveries" ? "sos" : "place";
      await recover(prefix + "Pending", env);
      await recover(prefix + "Stalled", env);
      return;
    }
    if (!recoveryIds.includes(id)) throw new Error("Unknown recovery partition");
    if (id.endsWith("Fanout")) {
      const sos = id === "sosFanout";
      const cutoff = Date.now() - 15 * 60000;
      const docs = await db.collection(sos ? "sos_alerts" : "placeEvents")
        .where("timestamp", ">=", sos ? new Date(cutoff).toISOString() : Timestamp.fromMillis(cutoff))
        .where("pushFanoutPending", "==", true).limit(4).get();
      for (const doc of docs.docs) await dispatch(env, sos ? "enqueueSosPush" : "enqueuePlacePush", doc.id);
      return;
    }
    const account = id.startsWith("accounts"), pending = id.endsWith("Pending");
    const [collection, trigger, limit] = account ? ["accountDeletions", "processAccountDeletion", 1]
      : id.startsWith("sos") ? ["sosPushDeliveries", "deliverSosPush", 6] : ["placePushDeliveries", "deliverPlacePush", 6];
    let query = db.collection(collection).where("status", "==", pending ? "pending" : "processing");
    if (!pending || !account) query = query.where(pending ? "nextAttemptAt" : "leaseUntil", "<=", Timestamp.now());
    const due = await query.limit(limit).get();
    for (const doc of due.docs) await dispatch(env, trigger, doc.id).catch(() => {});
  }

  async function cleanup(collection) {
    if (!cleanupCollections.includes(collection)) throw new Error("Unknown cleanup partition");
    const query = collection === "points" ? db.collectionGroup(collection) : db.collection(collection);
    const docs = await query.where(collection === "circleInvites" ? "expiresAt" : "expireAt", "<=", Timestamp.now())
      .limit(collection === "points" ? historyPageSize : 10).get();
    if (docs.empty) return;
    const batch = db.batch();
    for (const doc of docs.docs) batch.delete(doc.ref);
    await batch.commit();
  }

  async function sweep(env, cleanupOnly) {
    const partitions = cleanupOnly ? [...cleanupCollections, ...Array(historyPages - 1).fill("points")] : recoveryIds;
    // A failed partition must not prevent other categories from being attempted.
    // Each signed child rechecks current state. Repeated/overlapping sweeps are safe.
    let failed = false;
    for (const id of partitions) {
      try { await dispatch(env, cleanupOnly ? "cleanupExpired" : "recoverMaintenance", id); }
      catch (_) { failed = true; }
    }
    if (failed) throw new Error("Maintenance partitions remain pending");
  }
  return { recover, cleanup, sweep };
}
module.exports = { createMaintenance, recoveryIds, legacyRecoveryIds, cleanupCollections, historyPages, historyPageSize };
