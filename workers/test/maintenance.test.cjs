const { test } = require("node:test");
const assert = require("node:assert/strict");
const { createMaintenance, recoveryIds, cleanupCollections, historyPages, historyPageSize } = require("../src/maintenance.cjs");
function fixture(rows = []) {
  const queries = [], deleted = [], dispatched = [];
  const db = {
    collection(name) { return query(name, false); },
    collectionGroup(name) { return query(name, true); },
    batch() { return { delete: (ref) => deleted.push(ref), commit: async () => {} }; },
  };
  function query(name, group) {
    const spec = { name, group, filters: [], limit: null };
    return {
      where(...args) { spec.filters.push(args); return this; },
      limit(limit) { spec.limit = limit; return this; },
      async get() { queries.push(spec); return { docs: rows.slice(0, spec.limit), empty: rows.length === 0 }; },
    };
  }
  const handlers = createMaintenance({ db, Timestamp: { now: () => 123, fromMillis: (n) => n },
    dispatch: async (_, name, id) => { dispatched.push({ name, id }); },
  });
  return { handlers, queries, deleted, dispatched, db };
}
test("cron coordinators only dispatch fixed partitions and preserve history throughput", async () => {
  const f = fixture();
  await f.handlers.sweep({}, false);
  assert.equal(f.queries.length, 0);
  assert.deepEqual(f.dispatched.map((x) => x.id), recoveryIds);
  f.dispatched.length = 0;
  await f.handlers.sweep({}, true);
  assert.equal(f.queries.length, 0);
  assert.equal(f.dispatched.length, 13);
  assert.equal(f.dispatched.filter((x) => x.id === "points").length, historyPages);
  assert.equal(48 * historyPages * historyPageSize, 9600);
});
test("recovery partitions keep the same filters, batch limits and dispatch targets", async () => {
  for (const id of recoveryIds) {
    const f = fixture([{ id: "pending" }]);
    await f.handlers.recover(id, {});
    assert.equal(f.queries.length, 1);
    if (id.endsWith("Fanout")) {
      assert.equal(f.queries.length, 1);
      assert.equal(f.queries[0].limit, 4);
      assert.deepEqual(f.queries[0].filters[1], ["pushFanoutPending", "==", true]);
    } else {
      const pending = id.endsWith("Pending"), account = id.startsWith("accounts");
      assert.deepEqual(f.queries[0].filters[0], ["status", "==", pending ? "pending" : "processing"]);
      assert.equal(f.queries[0].limit, account ? 1 : 6);
      if (!pending || !account) assert.deepEqual(f.queries[0].filters[1], [pending ? "nextAttemptAt" : "leaseUntil", "<=", 123]);
    }
  }
});
test("cleanup is expiry-only, bounded per invocation, and rejects unknown collections", async () => {
  for (const name of cleanupCollections) {
    const f = fixture(Array.from({ length: 200 }, (_, i) => ({ ref: `point-${i}` })));
    await f.handlers.cleanup(name);
    assert.equal(f.queries.length, 1);
    assert.deepEqual(f.queries[0].filters, [[name === "circleInvites" ? "expiresAt" : "expireAt", "<=", 123]]);
    assert.equal(f.deleted.length, name === "points" ? 50 : 10);
    assert.equal(f.queries[0].group, name === "points");
  }
  const f = fixture();
  await assert.rejects(f.handlers.cleanup("users"));
  await assert.rejects(f.handlers.recover("unknown", {}));
  assert.equal(f.queries.length, 0);
});
test("previously signed delivery partitions remain valid during rollout", async () => {
  for (const id of ["sosDeliveries", "placeDeliveries", "accounts"]) {
    const f = fixture();
    await f.handlers.recover(id, {});
    assert.equal(f.queries.length, 2);
    assert.deepEqual(f.queries.map((q) => q.filters[0][2]), ["pending", "processing"]);
  }
});
test("one failed dispatch does not starve later maintenance partitions", async () => {
  const attempted = [];
  const handlers = createMaintenance({ dispatch: async (_, name, id) => {
    attempted.push(id); if (id === recoveryIds[0]) throw new Error("temporary failure");
  } });
  await assert.rejects(handlers.sweep({}, false));
  assert.deepEqual(attempted, recoveryIds);
});
