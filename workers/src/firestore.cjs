const { randomBytes } = require("node:crypto");

class Timestamp {
  constructor(milliseconds) {
    this.milliseconds = milliseconds;
  }
  static now() {
    return new Timestamp(Date.now());
  }
  static fromMillis(value) {
    return new Timestamp(value);
  }
  toMillis() {
    return this.milliseconds;
  }
  toDate() {
    return new Date(this.milliseconds);
  }
}
const sentinel = (kind, values) => ({ __transform: kind, values });
const FieldValue = {
  delete: () => sentinel("delete"),
  increment: (n) => sentinel("increment", n),
  arrayUnion: (...values) => sentinel("appendMissingElements", values),
};
function encode(value) {
  if (value === null) return { nullValue: null };
  if (value instanceof Timestamp || value instanceof Date)
    return {
      timestampValue: (value instanceof Date
        ? value
        : value.toDate()
      ).toISOString(),
    };
  if (typeof value === "string") return { stringValue: value };
  if (typeof value === "boolean") return { booleanValue: value };
  if (typeof value === "number" && Number.isFinite(value))
    return Number.isSafeInteger(value)
      ? { integerValue: String(value) }
      : { doubleValue: value };
  if (Array.isArray(value))
    return { arrayValue: { values: value.map(encode) } };
  if (value && typeof value === "object")
    return {
      mapValue: {
        fields: Object.fromEntries(
          Object.entries(value).map(([k, v]) => [k, encode(v)]),
        ),
      },
    };
  throw new Error("Unsupported Firestore value");
}
function decode(value) {
  if ("nullValue" in value) return null;
  if ("timestampValue" in value)
    return Timestamp.fromMillis(Date.parse(value.timestampValue));
  if ("integerValue" in value) return Number(value.integerValue);
  if ("doubleValue" in value) return value.doubleValue;
  if ("stringValue" in value) return value.stringValue;
  if ("booleanValue" in value) return value.booleanValue;
  if ("arrayValue" in value) return (value.arrayValue.values || []).map(decode);
  if ("mapValue" in value)
    return Object.fromEntries(
      Object.entries(value.mapValue.fields || {}).map(([k, v]) => [
        k,
        decode(v),
      ]),
    );
  throw new Error("Unsupported Firestore response");
}
const fieldPath = (field) =>
  "`" + field.replace(/\\/g, "\\\\").replace(/`/g, "\\`") + "`";
class Snapshot {
  constructor(ref, document) {
    this.ref = ref;
    this.id = ref.id;
    this.exists = !!document;
    this.document = document;
  }
  data() {
    return this.exists
      ? Object.fromEntries(
          Object.entries(this.document.fields || {}).map(([k, v]) => [
            k,
            decode(v),
          ]),
        )
      : undefined;
  }
}
class Query {
  constructor(db, path, filters = [], max = 200, allDescendants = false) {
    this.db = db;
    this.path = path;
    this.filters = filters;
    this.max = max;
    this.allDescendants = allDescendants;
  }
  where(field, op, value) {
    return new Query(
      this.db,
      this.path,
      [...this.filters, { field, op, value }],
      this.max,
      this.allDescendants,
    );
  }
  limit(max) {
    if (!Number.isInteger(max) || max < 1 || max > 1000)
      throw new Error("Invalid query limit");
    return new Query(
      this.db,
      this.path,
      this.filters,
      max,
      this.allDescendants,
    );
  }
  async get(transaction) {
    const parts = this.path.split("/"),
      collectionId = parts.pop();
    const parent = this.db.root + (parts.length ? "/" + parts.join("/") : "");
    const operators = {
      "==": "EQUAL",
      "<=": "LESS_THAN_OR_EQUAL",
      ">": "GREATER_THAN",
      in: "IN",
      "<": "LESS_THAN",
      ">=": "GREATER_THAN_OR_EQUAL",
    };
    const filters = this.filters.map((f) => {
      if (!operators[f.op]) throw new Error("Unsupported query operator");
      return {
        fieldFilter: {
          field: { fieldPath: fieldPath(f.field) },
          op: operators[f.op],
          value: encode(f.value),
        },
      };
    });
    const structuredQuery = {
      from: [
        {
          collectionId,
          ...(this.allDescendants ? { allDescendants: true } : {}),
        },
      ],
      limit: this.max,
    };
    if (filters.length)
      structuredQuery.where =
        filters.length === 1
          ? filters[0]
          : { compositeFilter: { op: "AND", filters } };
    const rows = await this.db.request(parent + ":runQuery", {
      structuredQuery,
      ...(transaction ? { transaction } : {}),
    });
    const docs = rows
      .filter((r) => r.document)
      .map(
        (r) =>
          new Snapshot(
            this.db.doc(r.document.name.slice(this.db.root.length + 1)),
            r.document,
          ),
      );
    return { docs, empty: docs.length === 0, size: docs.length };
  }
}
class Collection extends Query {
  get id() {
    return this.path.split("/").pop();
  }
  get parent() {
    const p = this.path.split("/");
    p.pop();
    return p.length ? this.db.doc(p.join("/")) : null;
  }
  doc(id = randomBytes(15).toString("hex")) {
    if (typeof id !== "string" || !id || id.includes("/"))
      throw new Error("Invalid document ID");
    return this.db.doc(this.path + "/" + id);
  }
}
class Document {
  constructor(db, path) {
    this.db = db;
    this.path = path;
  }
  get id() {
    return this.path.split("/").pop();
  }
  get parent() {
    const p = this.path.split("/");
    p.pop();
    return this.db.collection(p.join("/"));
  }
  get name() {
    return this.db.root + "/" + this.path;
  }
  collection(id) {
    return this.db.collection(this.path + "/" + id);
  }
  async get(transaction) {
    return (await this.db.getAll([this], transaction))[0];
  }
  set(data, options) {
    return this.db.batch().set(this, data, options).commit();
  }
  update(data) {
    return this.db.batch().update(this, data).commit();
  }
  delete() {
    return this.db.batch().delete(this).commit();
  }
}
function write(ref, data, mode, merge = false) {
  if (mode === "delete") return { delete: ref.name };
  const fields = {},
    masks = [],
    transforms = [];
  for (const [key, value] of Object.entries(data)) {
    const path = fieldPath(key);
    if (value?.__transform) {
      if (value.__transform === "delete") masks.push(path);
      else
        transforms.push({
          fieldPath: path,
          [value.__transform]:
            value.__transform === "increment"
              ? encode(value.values)
              : { values: value.values.map(encode) },
        });
    } else {
      fields[key] = encode(value);
      masks.push(path);
    }
  }
  const result = { update: { name: ref.name, fields } };
  if (mode === "update" || merge) result.updateMask = { fieldPaths: masks };
  if (mode === "create") result.currentDocument = { exists: false };
  if (mode === "update") result.currentDocument = { exists: true };
  if (transforms.length) result.updateTransforms = transforms;
  return result;
}
class Writes {
  constructor(db, transaction) {
    this.db = db;
    this.transaction = transaction;
    this.writes = [];
    this.created = [];
  }
  get(ref) {
    if (this.writes.length)
      throw new Error("Transaction reads must precede writes");
    return ref.get(this.transaction);
  }
  getAll(...refs) {
    if (this.writes.length)
      throw new Error("Transaction reads must precede writes");
    return this.db.getAll(refs, this.transaction);
  }
  create(ref, data) {
    this.writes.push(write(ref, data, "create"));
    this.created.push(ref.path);
    return this;
  }
  set(ref, data, options) {
    this.writes.push(write(ref, data, "set", options?.merge));
    return this;
  }
  update(ref, data) {
    this.writes.push(write(ref, data, "update"));
    return this;
  }
  delete(ref) {
    this.writes.push(write(ref, null, "delete"));
    return this;
  }
  async commit() {
    if (this.writes.length > 500)
      throw new Error("Too many transaction writes");
    if (this.writes.length || this.transaction)
      await this.db.request(this.db.root + ":commit", {
        writes: this.writes,
        ...(this.transaction ? { transaction: this.transaction } : {}),
      });
    this.db.onCommit?.(this.created);
  }
}
class Firestore {
  constructor(projectId, request, onCommit) {
    this.root = `projects/${projectId}/databases/(default)/documents`;
    this.request = request;
    this.onCommit = onCommit;
  }
  doc(path) {
    if (
      typeof path !== "string" ||
      path.split("/").length % 2 ||
      path.split("/").some((p) => !p)
    )
      throw new Error("Invalid document path");
    return new Document(this, path);
  }
  collection(path) {
    if (
      typeof path !== "string" ||
      path.split("/").length % 2 !== 1 ||
      path.split("/").some((p) => !p)
    )
      throw new Error("Invalid collection path");
    return new Collection(this, path);
  }
  collectionGroup(id) {
    if (typeof id !== "string" || !id || id.includes("/"))
      throw new Error("Invalid collection group");
    return new Query(this, id, [], 200, true);
  }
  batch() {
    return new Writes(this);
  }
  async getAll(refs, transaction) {
    if (!refs.length) return [];
    const rows = await this.request(this.root + ":batchGet", {
      documents: refs.map((r) => r.name),
      ...(transaction ? { transaction } : {}),
    });
    const docs = new Map(
      rows.map((row) => [row.found?.name || row.missing, row.found]),
    );
    return refs.map((ref) => new Snapshot(ref, docs.get(ref.name)));
  }
  async runTransaction(callback) {
    let retryTransaction;
    for (let attempt = 0; attempt < 5; attempt++) {
      const { transaction } = await this.request(
        this.root + ":beginTransaction",
        {
          options: { readWrite: retryTransaction ? { retryTransaction } : {} },
        },
      );
      const tx = new Writes(this, transaction);
      try {
        const result = await callback(tx);
        await tx.commit();
        return result;
      } catch (error) {
        await this.request(this.root + ":rollback", { transaction }).catch(
          () => {},
        );
        if (error.code !== "aborted" || attempt === 4) throw error;
        retryTransaction = transaction;
        await new Promise((r) =>
          setTimeout(r, 1000 * 1.5 ** attempt * (0.5 + Math.random())),
        );
      }
    }
  }
  async recursiveDelete(ref) {
    let token;
    do {
      const page = await this.request(ref.name + ":listCollectionIds", {
        pageSize: 100,
        pageToken: token,
      });
      for (const collection of page.collectionIds || []) {
        let cursor;
        do {
          const docs = await this.request(
            ref.name +
              "/" +
              collection +
              "?pageSize=100&showMissing=true" +
              (cursor ? "&pageToken=" + encodeURIComponent(cursor) : ""),
            undefined,
            "GET",
          );
          for (const doc of docs.documents || [])
            await this.recursiveDelete(
              this.doc(doc.name.slice(this.root.length + 1)),
            );
          cursor = docs.nextPageToken;
        } while (cursor);
      }
      token = page.nextPageToken;
    } while (token);
    await ref.delete();
  }
}
module.exports = { Firestore, Timestamp, FieldValue, encode, decode, write };
