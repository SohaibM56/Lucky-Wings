// Mocked tests for account deletion (no network).
const test = require("node:test");
const assert = require("node:assert");
const { assertRecentSignIn, deleteAccountData } = require("../account");

function makeDb(seed) {
  const store = JSON.parse(JSON.stringify(seed));
  const col = (name) => {
    store[name] = store[name] || {};
    const query = (filters) => ({
      where: (f, op, v) => query([...filters, [f, v]]),
      get: async () => ({
        docs: Object.entries(store[name])
          .filter(([, d]) => filters.every(([f, v]) => d[f] === v))
          .map(([id]) => ({
            id,
            data: () => store[name][id],
            ref: {
              delete: async () => { delete store[name][id]; },
              update: async (u) => Object.assign(store[name][id], u),
            },
          })),
      }),
    });
    return {
      ...query([]),
      doc: (id) => ({
        get: async () => ({ exists: id in store[name] }),
        delete: async () => { delete store[name][id]; },
      }),
    };
  };
  return { db: { collection: col }, store };
}

const seed = () => ({
  users: { u1: { email: "a@x.com" }, u2: { email: "b@x.com" } },
  monthly_records: {
    u1_2026_10: { userId: "u1" }, u1_2026_09: { userId: "u1" }, u2_2026_10: { userId: "u2" },
  },
  used_sessions: { u1_s1: { userId: "u1" }, u2_s1: { userId: "u2" } },
  raffle_winners: { w1: { userId: "u1", prizeName: "Phone" }, w2: { userId: "u2", prizeName: "TV" } },
});

test("deletes the player's profile, records and session ids; keeps other players untouched", async () => {
  const { db, store } = makeDb(seed());
  const deleted = [];
  const auth = { deleteUser: async (uid) => deleted.push(uid) };
  const FieldValue = { serverTimestamp: () => "TS" };
  const r = await deleteAccountData({ db, auth, FieldValue }, "u1");
  assert.deepStrictEqual(r, { user: 1, records: 2, sessions: 1, winnersKept: 1 });
  assert.strictEqual(store.users.u1, undefined);
  assert.deepStrictEqual(Object.keys(store.monthly_records), ["u2_2026_10"]);
  assert.deepStrictEqual(Object.keys(store.used_sessions), ["u2_s1"]);
  assert.ok(store.users.u2 && store.raffle_winners.w2.userDeleted === undefined);
  assert.deepStrictEqual(deleted, ["u1"]);
});

test("winner history is kept but flagged userDeleted", async () => {
  const { db, store } = makeDb(seed());
  await deleteAccountData({ db, auth: { deleteUser: async () => {} },
    FieldValue: { serverTimestamp: () => "TS" } }, "u1");
  assert.strictEqual(store.raffle_winners.w1.prizeName, "Phone");
  assert.strictEqual(store.raffle_winners.w1.userDeleted, true);
  assert.strictEqual(store.raffle_winners.w1.userDeletedAt, "TS");
});

test("works when the profile doc is already gone (retry after a partial run)", async () => {
  const s = seed(); delete s.users.u1;
  const { db } = makeDb(s);
  const r = await deleteAccountData({ db, auth: { deleteUser: async () => {} },
    FieldValue: { serverTimestamp: () => "TS" } }, "u1");
  assert.strictEqual(r.user, 0);
  assert.strictEqual(r.records, 2);
});

test("the Auth user is deleted last: a failure leaves data deleted but retryable", async () => {
  const { db } = makeDb(seed());
  await assert.rejects(deleteAccountData({ db,
    auth: { deleteUser: async () => { throw new Error("boom"); } },
    FieldValue: { serverTimestamp: () => "TS" } }, "u1"), /boom/);
});

test("recent sign-in: <= 5 minutes passes, older asks to re-authenticate", () => {
  const now = 1_800_000_000;
  assert.doesNotThrow(() => assertRecentSignIn({ auth_time: now - 299, firebase: { sign_in_provider: "password" } }, now));
  assert.throws(() => assertRecentSignIn({ auth_time: now - 301, firebase: { sign_in_provider: "google.com" } }, now),
    (e) => e.code === "reauth-required");
  assert.throws(() => assertRecentSignIn({ firebase: { sign_in_provider: "password" } }, now),
    (e) => e.code === "reauth-required");
});

test("guests (anonymous) are exempt from the recent sign-in check", () => {
  assert.doesNotThrow(() => assertRecentSignIn({ auth_time: 1, firebase: { sign_in_provider: "anonymous" } }, 1_800_000_000));
});
