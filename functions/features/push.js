const { createHash, randomUUID } = require('node:crypto');
const { Timestamp, FieldValue } = require('firebase-admin/firestore');
const { HttpsError } = require('firebase-functions/v2/https');
const { authenticated } = require('../auth');

const registrationDays = 30;
const deliveryWindowMs = 15 * 60000;
function installation(data) {
  if (typeof data?.installationId !== 'string' || !/^[a-f0-9]{32}$/.test(data.installationId) ||
      !Number.isSafeInteger(data.version) || data.version < 1) {
    throw new HttpsError('invalid-argument', 'A valid device registration is required.');
  }
  return data.installationId;
}
function installationProof(data) {
  const id = installation(data);
  if (typeof data.installationSecret !== 'string' || !/^[a-f0-9]{64}$/.test(data.installationSecret)) {
    throw new HttpsError('invalid-argument', 'A valid device proof is required.');
  }
  const hash = createHash('sha256').update(data.installationSecret).digest('hex');
  if (hash.slice(0, 32) !== id) throw new HttpsError('invalid-argument', 'Device proof does not match this installation.');
  return { id, hash };
}
const validId = (value) => typeof value === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(value);
const deliveryId = (alertId, deviceId) => createHash('sha256').update(`${alertId}:${deviceId}`).digest('hex');
const ms = (value) => value?.toMillis?.() ?? 0;
const permanentErrors = new Set(['messaging/registration-token-not-registered', 'messaging/invalid-registration-token']);

function createPushHandlers(db, messaging) {
  const devices = db.collection('pushDevices');
  const deliveries = db.collection('sosPushDeliveries');
  const handlers = {
    async register(request) {
      const uid = authenticated(request);
      const data = request.data ?? {};
      const { id, hash } = installationProof(data);
      if (typeof data.token !== 'string' || data.token.length < 20 || data.token.length > 4096 ||
          !/^[\x21-\x7E]+$/.test(data.token) || !['android', 'ios'].includes(data.platform)) {
        throw new HttpsError('invalid-argument', 'A valid push token and platform are required.');
      }
      return db.runTransaction(async (tx) => {
        const ref = devices.doc(id);
        const [current, profile, deletion, owned] = await Promise.all([
          tx.get(ref), tx.get(db.doc(`users/${uid}`)), tx.get(db.doc(`accountDeletions/${uid}`)),
          tx.get(devices.where('uid', '==', uid).where('enabled', '==', true)
            .where('expireAt', '>', Timestamp.now()).limit(10)),
        ]);
        if (!profile.exists || profile.data().deletionRequested || deletion.exists) {
          throw new HttpsError('failed-precondition', 'Your account is unavailable.');
        }
        const old = current.data();
        if (old && old.secretHash !== hash) throw new HttpsError('permission-denied', 'Device proof was not accepted.');
        if (old && data.version <= old.version) {
          if (data.version === old.version && old.uid === uid && old.token === data.token && old.enabled) {
            return { registered: true, version: old.version };
          }
          throw new HttpsError('aborted', 'A newer device session has replaced this request.');
        }
        const active = owned.docs.filter((doc) => doc.id !== id && doc.data().enabled && ms(doc.data().expireAt) > Date.now());
        if (active.length >= 10) throw new HttpsError('resource-exhausted', 'This account already has ten registered devices.');
        tx.set(ref, { uid, secretHash: hash, token: data.token, platform: data.platform, version: data.version, enabled: true,
          updatedAt: Timestamp.now(), expireAt: Timestamp.fromMillis(Date.now() + registrationDays * 86400000) });
        return { registered: true, version: data.version };
      });
    },
    async unregister(request) {
      const uid = authenticated(request);
      const { id, hash } = installationProof(request.data);
      return db.runTransaction(async (tx) => {
        const ref = devices.doc(id);
        const current = await tx.get(ref);
        if (!current.exists || current.data().secretHash !== hash || current.data().uid !== uid || current.data().version > request.data.version) {
          return { removed: false };
        }
        // Keep a version tombstone so an older delayed registration cannot return.
        tx.update(ref, { enabled: false, version: request.data.version, token: FieldValue.delete(), updatedAt: Timestamp.now() });
        return { removed: true };
      });
    },
    async enqueue(alertId) {
      if (!validId(alertId)) return;
      const alertRef = db.doc(`sos_alerts/${alertId}`);
      await db.runTransaction(async (tx) => {
        const alert = await tx.get(alertRef);
        const data = alert.data();
        if (!data || data.status !== 'active' || data.pushFanout || !validId(data.circleId) ||
            !Number.isFinite(Date.parse(data.timestamp)) || Date.parse(data.timestamp) > Date.now() + 30000 ||
            Date.now() - Date.parse(data.timestamp) > deliveryWindowMs) return;
        const circle = await tx.get(db.doc(`circles/${data.circleId}`));
        const ids = circle.data()?.memberIds;
        if (!Array.isArray(ids) || ids.length > 20 || !ids.includes(data.senderId)) return;
        const recipients = [...new Set(ids.filter((uid) => uid !== data.senderId && validId(uid)))];
        const profiles = recipients.length ? await tx.getAll(...recipients.map((uid) => db.doc(`users/${uid}`))) : [];
        const allowed = profiles.filter((profile) => profile.exists && profile.data().circleId === data.circleId &&
          !profile.data().deletionRequested).map((profile) => profile.id);
        const registered = allowed.length ? await tx.get(devices.where('uid', 'in', allowed).limit(200)) : null;
        const targets = (registered?.docs ?? []).filter((device) => device.data().enabled &&
          ms(device.data().expireAt) > Date.now() && typeof device.data().token === 'string');
        for (const device of targets) {
          tx.create(deliveries.doc(deliveryId(alertId, device.id)), {
            alertId, circleId: data.circleId, recipientUid: device.data().uid, installationId: device.id,
            registrationVersion: device.data().version, status: 'pending', nextAttemptAt: Timestamp.now(),
            createdAt: Timestamp.now(), leaseUntil: Timestamp.fromMillis(0),
            expireAt: Timestamp.fromMillis(Date.now() + 2 * 86400000),
          });
        }
        tx.update(alertRef, { pushFanout: { targetMembers: allowed.length, queuedDevices: targets.length,
          createdAt: Timestamp.now() } });
      });
    },
    async process(id) {
      const ref = deliveries.doc(id);
      const lease = randomUUID();
      const job = await db.runTransaction(async (tx) => {
        const snapshot = await tx.get(ref);
        const data = snapshot.data();
        if (!data || !['pending', 'processing'].includes(data.status) ||
            (data.status === 'processing' && ms(data.leaseUntil) > Date.now()) ||
            (data.status === 'pending' && ms(data.nextAttemptAt) > Date.now())) return null;
        tx.update(ref, { status: 'processing', lease, attempts: FieldValue.increment(1),
          leaseUntil: Timestamp.fromMillis(Date.now() + 3 * 60000) });
        return { ...data, attempts: (data.attempts ?? 0) + 1 };
      });
      if (!job) return;
      const finish = async (fields) => db.runTransaction(async (tx) => {
        const current = await tx.get(ref);
        if (current.data()?.lease !== lease) return;
        tx.update(ref, { ...fields, lease: FieldValue.delete(), leaseUntil: Timestamp.fromMillis(0) });
      });
      let sentVersion = job.registrationVersion;
      try {
        const [alert, circle, profile, device, deletion] = await Promise.all([
          db.doc(`sos_alerts/${job.alertId}`).get(), db.doc(`circles/${job.circleId}`).get(),
          db.doc(`users/${job.recipientUid}`).get(), devices.doc(job.installationId).get(),
          db.doc(`accountDeletions/${job.recipientUid}`).get(),
        ]);
        if (!alert.exists || alert.data().status !== 'active' || alert.data().circleId !== job.circleId ||
            !Number.isFinite(Date.parse(alert.data().timestamp)) || Date.parse(alert.data().timestamp) > Date.now() + 30000 ||
            Date.now() - Date.parse(alert.data().timestamp) > deliveryWindowMs) {
          await finish({ status: 'expired' }); return;
        }
        const token = device.data();
        if (!profile.exists || profile.data().deletionRequested || deletion.exists ||
            profile.data().circleId !== job.circleId || !circle.data()?.memberIds?.includes(job.recipientUid) ||
            !token?.enabled || token.uid !== job.recipientUid || token.version < job.registrationVersion ||
            ms(token.expireAt) <= Date.now()) {
          await finish({ status: 'cancelled' }); return;
        }
        sentVersion = token.version;
        const messageId = await messaging.send({ token: token.token,
          notification: { title: 'Family Guard', body: 'A family emergency needs your attention. Open the app to check.' },
          data: { type: 'sos', schemaVersion: '1', alertId: job.alertId, circleId: job.circleId,
            recipientUid: job.recipientUid, installationId: job.installationId, registrationVersion: String(token.version) },
          android: { priority: 'high', ttl: 5 * 60000, collapseKey: 'family_guard_sos',
            notification: { channelId: 'family_guard_sos', tag: job.alertId, icon: 'ic_stat_family_guard', visibility: 'private' } },
          apns: { headers: { 'apns-priority': '10', 'apns-collapse-id': job.alertId,
            'apns-expiration': String(Math.floor(Date.now() / 1000) + 300) }, payload: { aps: { sound: 'default' } } },
        });
        // FCM acceptance is not proof of receipt. Client acknowledgements are separate fields.
        await finish({ status: 'sent', acceptedAt: Timestamp.now(), acceptedRegistrationVersion: token.version,
          messageId, lastErrorCode: FieldValue.delete() });
      } catch (error) {
        const permanent = permanentErrors.has(error.code);
        if (permanent) {
          await db.runTransaction(async (tx) => {
            const device = await tx.get(devices.doc(job.installationId));
            if (device.data()?.uid === job.recipientUid && device.data()?.version === sentVersion) {
              tx.update(device.ref, { enabled: false, token: FieldValue.delete() });
            }
          });
        }
        await finish({ status: permanent ? 'failed' : 'pending',
          nextAttemptAt: Timestamp.fromMillis(Date.now() + Math.min(60000 * 2 ** Math.min(job.attempts - 1, 4), 15 * 60000)),
          lastErrorCode: typeof error.code === 'string' ? error.code.slice(0, 80) : 'internal' });
        if (!permanent) throw error;
      }
    },
    async retryPending() {
      const [pending, expired] = await Promise.all([
        deliveries.where('status', '==', 'pending').where('nextAttemptAt', '<=', Timestamp.now()).limit(50).get(),
        deliveries.where('status', '==', 'processing').where('leaseUntil', '<=', Timestamp.now()).limit(20).get(),
      ]);
      const jobs = [...pending.docs, ...expired.docs];
      for (let offset = 0; offset < jobs.length; offset += 5) {
        await Promise.all(jobs.slice(offset, offset + 5).map(async (job) => {
          try { await handlers.process(job.id); } catch (error) {
            console.error('Push delivery retry failed', { jobId: job.id, code: error.code ?? 'internal' });
          }
        }));
      }
    },
    async acknowledge(request) {
      const uid = authenticated(request);
      const data = request.data ?? {};
      const deviceId = installation({ ...data, version: data.registrationVersion });
      if (!validId(data.alertId) || !['received', 'opened'].includes(data.kind)) {
        throw new HttpsError('invalid-argument', 'A valid delivery acknowledgement is required.');
      }
      return db.runTransaction(async (tx) => {
        const ref = deliveries.doc(deliveryId(data.alertId, deviceId));
        const [job, device, profile, alert, deletion] = await Promise.all([
          tx.get(ref), tx.get(devices.doc(deviceId)), tx.get(db.doc(`users/${uid}`)),
          tx.get(db.doc(`sos_alerts/${data.alertId}`)), tx.get(db.doc(`accountDeletions/${uid}`)),
        ]);
        if (!job.exists || job.data().recipientUid !== uid || device.data()?.uid !== uid ||
            !device.data().enabled || device.data().version < data.registrationVersion || ms(device.data().expireAt) <= Date.now() ||
            !profile.exists || profile.data().deletionRequested || deletion.exists ||
            profile.data().circleId !== job.data().circleId || alert.data()?.circleId !== job.data().circleId) {
          throw new HttpsError('permission-denied', 'This delivery does not belong to your current account.');
        }
        const circle = await tx.get(db.doc(`circles/${job.data().circleId}`));
        if (!circle.data()?.memberIds?.includes(uid)) {
          throw new HttpsError('permission-denied', 'You no longer belong to this circle.');
        }
        const field = data.kind === 'opened' ? 'openedAt' : 'receivedAt';
        if (!job.data()[field]) tx.update(ref, { [field]: Timestamp.now() });
        return { acknowledged: true, active: alert.data().status === 'active', circleId: job.data().circleId };
      });
    },
  };
  return handlers;
}
module.exports = { createPushHandlers, deliveryId };
