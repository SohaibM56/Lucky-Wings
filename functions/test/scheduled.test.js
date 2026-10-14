// Mocked tests for the scheduled functions (plan section 8). No network:
// firebase-admin is replaced with an in-memory Firestore + FCM recorder.
const test = require("node:test");
const assert = require("node:assert");
const Module = require("module");

let store, sent, multicasts, added;
const reset = () => { store = {}; sent = []; multicasts = []; added = []; };

const matches = (d, [f, op, v]) => {
  const x = d[f];
  if (op === "==") return x === v;
  if (op === ">") return x > v;
  if (op === "<") return (x instanceof Date ? x.getTime() : x) < (v instanceof Date ? v.getTime() : v);
  throw new Error("op " + op);
};
const snapOf = (rows) => ({
  empty: rows.length === 0,
  docs: rows.map(([id, d, col]) => ({
    id, data: () => d,
    ref: { update: async (u) => Object.assign(store[col][id], u) },
  })),
});
const fakeDb = {
  collection: (col) => {
    store[col] = store[col] || {};
    const q = (filters) => ({
      where: (f, op, v) => q([...filters, [f, op, v]]),
      get: async () => snapOf(Object.entries(store[col])
        .filter(([, d]) => filters.every((fl) => matches(d, fl)))
        .map(([id, d]) => [id, d, col])),
    });
    return {
      ...q([]),
      doc: (id) => ({
        get: async () => ({ exists: id in store[col], data: () => store[col][id] }),
        set: async (d) => { store[col][id] = d; },
      }),
      add: async (d) => { const id = "w" + (added.length + 1); added.push(id); store[col][id] = d; return { id }; },
    };
  },
};
const fakeAdmin = {
  initializeApp() {},
  auth: () => ({}),
  firestore: Object.assign(() => fakeDb, { FieldValue: { serverTimestamp: () => "TS" } }),
  messaging: () => ({
    send: async (m) => { sent.push(m); },
    sendEachForMulticast: async (m) => { multicasts.push(m); },
  }),
};
const origLoad = Module._load;
Module._load = function (req, ...r) { return req === "firebase-admin" ? fakeAdmin : origLoad.call(this, req, ...r); };
const fns = require("../index.js");
Module._load = origLoad;

const prevKey = () => {
  const n = new Date(), p = new Date(n.getFullYear(), n.getMonth() - 1, 1);
  return `${p.getFullYear()}-${String(p.getMonth() + 1).padStart(2, "0")}`;
};
const run = (fn) => fns[fn].run({}, {});
const rec = (uid, entries) => ({ userId: uid, monthKey: prevKey(), totalEntries: entries });

test("8.1 draw writes an unclaimed winner with a 7-day deadline, weighted by entries", async () => {
  reset();
  store.monthly_records = { a: rec("heavy", 30), b: rec("light", 1) };
  store.raffle_config = { [prevKey()]: { prize: "Phone" } };
  const wins = { heavy: 0, light: 0 };
  for (let i = 0; i < 300; i++) {
    store.raffle_winners = {}; added.length = 0;
    await run("monthlyRaffleDraw");
    const w = Object.values(store.raffle_winners)[0];
    wins[w.userId]++;
    assert.strictEqual(w.claimed, false);
    assert.strictEqual(w.prizeName, "Phone");
    const days = (w.claimDeadline - Date.now()) / 86400000;
    assert.ok(days > 6.99 && days <= 7, "deadline ~7 days, got " + days);
  }
  assert.ok(wins.heavy > wins.light * 5, JSON.stringify(wins)); // 30:1 weighting
});

test("8.1 no entries -> no winner, no crash", async () => {
  reset();
  store.monthly_records = { a: rec("zero", 0) };
  await run("monthlyRaffleDraw");
  assert.deepStrictEqual(store.raffle_winners || {}, {});
});

test("8.2 winner with fcmToken gets the push; without token is a graceful no-op", async () => {
  reset();
  store.monthly_records = { a: rec("u1", 3) };
  store.users = { u1: { fcmToken: "tok" } };
  await run("monthlyRaffleDraw");
  assert.strictEqual(sent.length, 1);
  assert.strictEqual(sent[0].token, "tok");
  assert.strictEqual(sent[0].data.type, "winner");

  reset();
  store.monthly_records = { a: rec("u2", 3) };
  store.users = { u2: {} };
  await run("monthlyRaffleDraw");
  assert.strictEqual(sent.length, 0);
  assert.strictEqual(Object.keys(store.raffle_winners).length, 1);

  reset(); // user doc missing entirely
  store.monthly_records = { a: rec("u3", 3) };
  await run("monthlyRaffleDraw");
  assert.strictEqual(sent.length, 0);
});

test("8.3 expiry marks only unclaimed past-deadline wins", async () => {
  reset();
  const past = new Date(Date.now() - 86400000), future = new Date(Date.now() + 86400000);
  store.raffle_winners = {
    stale: { claimed: false, claimDeadline: past },
    claimedInTime: { claimed: true, claimDeadline: past },
    stillOpen: { claimed: false, claimDeadline: future },
  };
  await run("expireUnclaimedWins");
  assert.strictEqual(store.raffle_winners.stale.expired, true);
  assert.strictEqual(store.raffle_winners.claimedInTime.expired, undefined);
  assert.strictEqual(store.raffle_winners.stillOpen.expired, undefined);
});

test("8.4 reminders go only to entrants with a token, batched at 500", async () => {
  reset();
  store.monthly_records = {}; store.users = {};
  for (let i = 0; i < 1200; i++) {
    store.monthly_records["r" + i] = rec("u" + i, 1);
    if (i % 12 !== 0) store.users["u" + i] = { fcmToken: "t" + i }; // 100 without token
  }
  store.monthly_records.noEntries = rec("nobody", 0);
  store.users.nobody = { fcmToken: "tx" };
  await run("sendDrawDayReminder");
  const total = multicasts.reduce((n, m) => n + m.tokens.length, 0);
  assert.strictEqual(total, 1100);
  assert.deepStrictEqual(multicasts.map((m) => m.tokens.length), [500, 500, 100]);
  assert.ok(multicasts.every((m) => m.tokens.length <= 500));
  assert.ok(!multicasts.some((m) => m.tokens.includes("tx")));
});
