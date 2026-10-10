const {
  createPrivateKey,
  createSign,
  createPublicKey,
  verify,
} = require("node:crypto");
const keyCaches = new Map();
let completedOAuth;
const scopes =
  "https://www.googleapis.com/auth/datastore https://www.googleapis.com/auth/identitytoolkit https://www.googleapis.com/auth/firebase.messaging";
const b64 = (value) =>
  Buffer.from(
    typeof value === "string" ? value : JSON.stringify(value),
  ).toString("base64url");
class ApiError extends Error {
  constructor(code) {
    super("Backend operation failed");
    this.code = code;
  }
}
async function verifyJwt(token, url, validate, fetcher = fetch) {
  if (typeof token !== "string" || token.length > 16384)
    throw new ApiError("unauthenticated");
  const parts = token.split(".");
  if (parts.length !== 3) throw new ApiError("unauthenticated");
  let header, claims;
  try {
    header = JSON.parse(Buffer.from(parts[0], "base64url"));
    claims = JSON.parse(Buffer.from(parts[1], "base64url"));
  } catch (_) {
    throw new ApiError("unauthenticated");
  }
  const now = Date.now() / 1000;
  if (
    !header ||
    typeof header !== "object" ||
    Array.isArray(header) ||
    !claims ||
    typeof claims !== "object" ||
    Array.isArray(claims) ||
    header.alg !== "RS256" ||
    typeof header.kid !== "string" ||
    header.kid.length > 256 ||
    !Number.isFinite(claims.exp) ||
    claims.exp <= now ||
    !Number.isFinite(claims.iat) ||
    claims.iat > now + 30 ||
    (claims.nbf !== undefined &&
      (!Number.isFinite(claims.nbf) || claims.nbf > now + 30)) ||
    !validate(claims, now)
  )
    throw new ApiError("unauthenticated");
  let cached = keyCaches.get(url);
  if (
    !cached ||
    cached.until < Date.now() ||
    (!cached.keys.has(header.kid) && Date.now() - cached.fetchedAt > 60000)
  ) {
    // Workers must never reuse pending I/O owned by another invocation.
    cached = await (async () => {
        const response = await fetcher(url, {
          signal: AbortSignal.timeout(10000),
        });
        if (!response.ok) throw new ApiError("unavailable");
        const payload = await response.json();
        if (!Array.isArray(payload.keys) || payload.keys.length > 20)
          throw new ApiError("unavailable");
        const maxAge = Number(
          response.headers.get("Cache-Control")?.match(/max-age=(\d+)/)?.[1] ||
            3600,
        );
        const result = {
          keys: new Map(
            payload.keys
              .filter((k) => k.kty === "RSA" && k.kid)
              .map((k) => [k.kid, createPublicKey({ key: k, format: "jwk" })]),
          ),
          until: Date.now() + Math.min(maxAge, 3600) * 1000,
          fetchedAt: Date.now(),
        };
        keyCaches.set(url, result);
        return result;
      })();
  }
  const key = cached.keys.get(header.kid);
  if (
    !key ||
    !verify(
      "RSA-SHA256",
      Buffer.from(parts[0] + "." + parts[1]),
      key,
      Buffer.from(parts[2], "base64url"),
    )
  )
    throw new ApiError("unauthenticated");
  return claims;
}
async function verifyRequest(request, env) {
  const auth = request.headers.get("Authorization");
  if (!auth?.startsWith("Bearer ") || !request.headers.get("X-Firebase-AppCheck"))
    throw new ApiError("unauthenticated");
  const [claims, app] = await Promise.all([
    verifyJwt(
      auth.slice(7),
      "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com",
      (c, now) =>
        c.aud === env.FIREBASE_PROJECT_ID &&
        c.iss === `https://securetoken.google.com/${env.FIREBASE_PROJECT_ID}` &&
        typeof c.sub === "string" &&
        c.sub.length > 0 &&
        c.sub.length <= 128 &&
        Number.isFinite(c.auth_time) &&
        c.auth_time > 0 &&
        c.auth_time <= now + 30,
    ),
    verifyJwt(
      request.headers.get("X-Firebase-AppCheck"),
      "https://firebaseappcheck.googleapis.com/v1/jwks",
      (c) =>
        c.iss ===
          `https://firebaseappcheck.googleapis.com/${env.FIREBASE_PROJECT_NUMBER}` &&
        Array.isArray(c.aud) &&
        c.aud.includes(`projects/${env.FIREBASE_PROJECT_NUMBER}`) &&
        (env.FIREBASE_APP_IDS || "").split(",").includes(c.sub),
    ),
  ]);
  return { auth: { uid: claims.sub, token: claims }, app: { appId: app.sub } };
}
class GoogleClient {
  constructor(env, fetcher = fetch) {
    this.env = env;
    this.fetcher = (...args) => fetcher(...args);
    this.cachedToken = null;
    this.refresh = null;
  }
  async token() {
    if (completedOAuth?.key === this.env.GOOGLE_SERVICE_ACCOUNT &&
        completedOAuth.token.until > Date.now() + 60000)
      return completedOAuth.token.value;
    if (this.cachedToken?.until > Date.now() + 60000)
      return this.cachedToken.value;
    if (this.refresh) return this.refresh;
    this.refresh = this.issueToken().finally(() => (this.refresh = null));
    return this.refresh;
  }
  async issueToken() {
    const service = JSON.parse(this.env.GOOGLE_SERVICE_ACCOUNT || "{}");
    if (
      service.project_id !== this.env.FIREBASE_PROJECT_ID ||
      !service.client_email ||
      !service.private_key
    )
      throw new ApiError("failed-precondition");
    const now = Math.floor(Date.now() / 1000);
    const unsigned =
      b64({ alg: "RS256", typ: "JWT" }) +
      "." +
      b64({
        iss: service.client_email,
        scope: scopes,
        aud: "https://oauth2.googleapis.com/token",
        iat: now,
        exp: now + 3600,
      });
    const signer = createSign("RSA-SHA256");
    signer.update(unsigned);
    const assertion =
      unsigned +
      "." +
      signer.sign(createPrivateKey(service.private_key)).toString("base64url");
    const response = await this.fetcher("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion,
      }),
      signal: AbortSignal.timeout(15000),
    });
    if (!response.ok) throw new ApiError("unavailable");
    const data = await response.json();
    if (
      typeof data.access_token !== "string" ||
      !Number.isFinite(data.expires_in)
    )
      throw new ApiError("unavailable");
    this.cachedToken = {
      value: data.access_token,
      until: Date.now() + Math.min(data.expires_in, 3600) * 1000,
    };
    completedOAuth = {key: this.env.GOOGLE_SERVICE_ACCOUNT, token: this.cachedToken};
    return data.access_token;
  }
  async request(url, body, method = "POST") {
    const response = await this.fetcher(url, {
      method,
      headers: {
        Authorization: `Bearer ${await this.token()}`,
        "Content-Type": "application/json",
      },
      body: body ? JSON.stringify(body) : undefined,
      signal: AbortSignal.timeout(20000),
    });
    const data = await response.json();
    if (!response.ok) {
      const fcm = data.error?.details?.find((d) =>
        d["@type"]?.endsWith("FcmError"),
      )?.errorCode;
      if (fcm === "UNREGISTERED")
        throw new ApiError("messaging/registration-token-not-registered");
      const reason = data.error?.message;
      if (reason === "USER_NOT_FOUND")
        throw new ApiError("auth/user-not-found");
      const codes = {
        ABORTED: "aborted",
        ALREADY_EXISTS: "already-exists",
        FAILED_PRECONDITION: "failed-precondition",
        NOT_FOUND: "not-found",
        PERMISSION_DENIED: "permission-denied",
        RESOURCE_EXHAUSTED: "resource-exhausted",
        UNAUTHENTICATED: "unauthenticated",
        INVALID_ARGUMENT: "invalid-argument",
      };
      throw new ApiError(codes[data.error?.status] || "unavailable");
    }
    return data;
  }
  firestore(path, body, method) {
    return this.request(
      "https://firestore.googleapis.com/v1/" + path,
      body,
      method,
    );
  }
  updateUser(uid, { disabled }) {
    return this.request(
      `https://identitytoolkit.googleapis.com/v1/projects/${this.env.FIREBASE_PROJECT_ID}/accounts:update`,
      { localId: uid, disableUser: disabled },
    );
  }
  deleteUser(uid) {
    return this.request(
      `https://identitytoolkit.googleapis.com/v1/projects/${this.env.FIREBASE_PROJECT_ID}/accounts:delete`,
      { localId: uid },
    );
  }
  async send(message) {
    const android = message.android
      ? {
          ...message.android,
          ...(message.android.ttl === undefined
            ? {}
            : { ttl: `${message.android.ttl / 1000}s` }),
          ...(message.android.priority
            ? { priority: message.android.priority.toUpperCase() }
            : {}),
          ...(message.android.notification
            ? {
                notification: {
                  ...message.android.notification,
                  ...(message.android.notification.visibility
                    ? {
                        visibility:
                          message.android.notification.visibility.toUpperCase(),
                      }
                    : {}),
                },
              }
            : {}),
        }
      : undefined;
    const result = await this.request(
      `https://fcm.googleapis.com/v1/projects/${this.env.FIREBASE_PROJECT_ID}/messages:send`,
      { message: { ...message, ...(android ? { android } : {}) } },
    );
    return result.name;
  }
}
module.exports = { GoogleClient, ApiError, verifyJwt, verifyRequest };
