const test = require("node:test");
const assert = require("node:assert");
const { makeAdminHandlers, makeBootstrap, requireAdmin, pickWinner } = require("../admin");
const { makeDb } = require("./fakedb");

const NOW = new Date("2026-10-14T12:00:00Z");
const adminCtx = { auth: { uid: "admin1", token: { admin: true, email: "boss@x.com" } } };
const userCtx = { auth: { uid: "u1", token: {} } };

function setup(seed = {}, over = {}) {
  const { db, store } = makeDb(seed);
  const pushes = [], deleted = [], disabled = [];
  const auth = {
    deleteUser: async (u) => deleted.push(u),
    updateUser: async (u, p) => disabled.push([u, p]),
    getUser: async () => ({ disabled: false }),
  };
  const messaging = { send: async (m) => pushes.push(m) };
  const h = makeAdminHandlers({ db, auth, messaging, FieldValue: { serverTimestamp: () => "TS" },
    now: () => NOW, rand: () => 0, ...over });
  return { h, store, pushes, deleted, disabled };
}
const code = (c) => (e) => e.code === c;
const none = (store, col) => !store[col] || Object.keys(store[col]).length === 0;

test("every admin function refuses non-admins and anonymous callers", async () => {
  const { h } = setup();
  for (const [name, fn] of Object.entries(h)) {
    await assert.rejects(fn({}, userCtx), code("permission-denied"), name);
    await assert.rejects(fn({}, {}), code("permission-denied"), name);
    await assert.rejects(fn({}, { auth: { uid: "x", token: { admin: "true" } } }), code("permission-denied"), name);
  }
  assert.throws(() => requireAdmin({ auth: { token: {} } }), code("permission-denied"));
});

test("dashboard: counts, prize and missing-next-month warning", async () => {
  const { h } = setup({
    users: { a: { createdAt: new Date("2026-10-12") }, b: { createdAt: new Date("2026-01-01") } },
    monthly_records: { a_2026_10: { monthKey: "2026-10", totalEntries: 3, dailyActiveSeconds: { "2026-10-14": 60 } } },
    raffle_config: { "2026-10": { prize: "Phone" } },
    raffle_winners: {
      w1: { claimed: false, claimDeadline: new Date("2026-10-15T00:00:00Z") },
      w2: { claimed: true }, w3: { claimed: false, expired: true },
    },
  });
  const d = await h.adminGetDashboard({}, adminCtx);
  assert.strictEqual(d.players.total, 2);
  assert.strictEqual(d.players.newThisWeek, 1);
  assert.strictEqual(d.activeToday, 1);
  assert.strictEqual(d.entriesThisMonth, 3);
  assert.strictEqual(d.currentPrize, "Phone");
  assert.strictEqual(d.unclaimedWins, 1);
  assert.strictEqual(d.expiringWins, 1);
  assert.match(d.warnings[0], /2026-11/);
});

test("setPrize: creates, audits, blocks past months and bad input", async () => {
  const { h, store } = setup();
  await h.adminSetPrize({ month: "2026-11", prize: " Console " }, adminCtx);
  assert.strictEqual(store.raffle_config["2026-11"].prize, "Console");
  const a = Object.values(store.admin_audit);
  assert.strictEqual(a.length, 1);
  assert.strictEqual(a[0].action, "setPrize");
  assert.strictEqual(a[0].actorEmail, "boss@x.com");
  await assert.rejects(h.adminSetPrize({ month: "2026-09", prize: "x" }, adminCtx), code("failed-precondition"));
  await assert.rejects(h.adminSetPrize({ month: "nope", prize: "x" }, adminCtx), code("invalid-argument"));
  await assert.rejects(h.adminSetPrize({ month: "2026-11", prize: "" }, adminCtx), code("invalid-argument"));
  await assert.rejects(h.adminSetPrize({ month: "2026-11", prize: "x", imageUrl: "http://a" }, adminCtx), code("invalid-argument"));
});

test("listPrizes flags a missing next month", async () => {
  const { h } = setup({ raffle_config: { "2026-10": { prize: "A" } } });
  assert.strictEqual((await h.adminListPrizes({}, adminCtx)).nextMonthMissing, true);
});

const drawSeed = () => ({
  users: { u1: { email: "a@x.com", fcmToken: "t1" }, u2: { email: "b@x.com" } },
  monthly_records: {
    u1_2026_09: { userId: "u1", monthKey: "2026-09", totalEntries: 2 },
    u2_2026_09: { userId: "u2", monthKey: "2026-09", totalEntries: 1 },
  },
  raffle_config: { "2026-09": { prize: "Phone" } },
});

test("pickWinner is weighted by entries and handles an empty pool", () => {
  const recs = [{ userId: "a", totalEntries: 2 }, { userId: "b", totalEntries: 1 }];
  assert.strictEqual(pickWinner(recs, () => 0).winner.userId, "a");
  assert.strictEqual(pickWinner(recs, () => 0.99).winner.userId, "b");
  assert.strictEqual(pickWinner(recs, () => 0.5).poolSize, 3);
  assert.strictEqual(pickWinner([]).winner, null);
});

test("previewDraw writes nothing", async () => {
  const { h, store } = setup(drawSeed());
  const p = await h.adminPreviewDraw({ month: "2026-09" }, adminCtx);
  assert.strictEqual(p.poolSize, 3);
  assert.strictEqual(p.candidate.userId, "u1");
  assert.strictEqual(p.prizeName, "Phone");
  assert.ok(none(store, "raffle_winners"));
  assert.ok(none(store, "admin_audit"));
});

test("runDraw writes the winner, pushes, audits; a second draw for the month is refused", async () => {
  const { h, store, pushes } = setup(drawSeed());
  const r = await h.adminRunDraw({ month: "2026-09" }, adminCtx);
  assert.strictEqual(r.userId, "u1");
  assert.strictEqual(store.raffle_winners[r.id].prizeName, "Phone");
  assert.strictEqual(store.raffle_winners[r.id].claimed, false);
  assert.strictEqual(pushes.length, 1);
  assert.strictEqual(Object.values(store.admin_audit)[0].action, "runDraw");
  await assert.rejects(h.adminRunDraw({ month: "2026-09" }, adminCtx), code("already-exists"));
  assert.strictEqual(Object.keys(store.raffle_winners).length, 1);
});

test("runDraw with no entrants fails cleanly", async () => {
  const { h } = setup();
  await assert.rejects(h.adminRunDraw({ month: "2026-09" }, adminCtx), code("failed-precondition"));
});

test("redraw: needs a reason, only after expiry/disqualification, keeps old win flagged, skips old winner", async () => {
  const { h, store } = setup(drawSeed());
  const first = await h.adminRunDraw({ month: "2026-09" }, adminCtx);
  await assert.rejects(h.adminRunDraw({ month: "2026-09", redraw: true, reason: "x" }, adminCtx), code("failed-precondition"));
  store.raffle_winners[first.id].expired = true;
  await assert.rejects(h.adminRunDraw({ month: "2026-09", redraw: true }, adminCtx), code("invalid-argument"));
  const second = await h.adminRunDraw({ month: "2026-09", redraw: true, reason: "no response" }, adminCtx);
  assert.strictEqual(second.userId, "u2");
  assert.strictEqual(store.raffle_winners[first.id].disqualified, true);
  assert.strictEqual(store.raffle_winners[first.id].disqualifiedReason, "no response");
  assert.strictEqual(store.raffle_winners[second.id].disqualified, undefined);
  await assert.rejects(h.adminRunDraw({ month: "2026-09", redraw: true, reason: "again" }, adminCtx), code("failed-precondition"));
});

test("a claimed win cannot be redrawn; a disqualified one can", async () => {
  const { h, store } = setup(drawSeed());
  const first = await h.adminRunDraw({ month: "2026-09" }, adminCtx);
  store.raffle_winners[first.id].claimed = true;
  await assert.rejects(h.adminRunDraw({ month: "2026-09", redraw: true, reason: "x" }, adminCtx), code("failed-precondition"));
  store.raffle_winners[first.id].claimed = false;
  await h.adminUpdateWinner({ id: first.id, patch: { disqualify: true, reason: "cheating" } }, adminCtx);
  const second = await h.adminRunDraw({ month: "2026-09", redraw: true, reason: "cheating" }, adminCtx);
  assert.strictEqual(second.userId, "u2");
});

test("disqualified monthly records are excluded from the pool", async () => {
  const s = drawSeed();
  s.monthly_records.u1_2026_09.disqualified = true;
  const { h } = setup(s);
  assert.strictEqual((await h.adminPreviewDraw({ month: "2026-09" }, adminCtx)).candidate.userId, "u2");
});

test("updateWinner: delivery status sets timestamps, extend resets expiry, validation", async () => {
  const { h, store } = setup({ raffle_winners: { w1: { userId: "u1", claimDeadline: new Date("2026-10-10"), expired: true } } });
  await h.adminUpdateWinner({ id: "w1", patch: { deliveryStatus: "contacted", deliveryNote: "emailed" } }, adminCtx);
  assert.strictEqual(store.raffle_winners.w1.contactedAt, "TS");
  await h.adminUpdateWinner({ id: "w1", patch: { deliveryStatus: "delivered" } }, adminCtx);
  assert.strictEqual(store.raffle_winners.w1.deliveredAt, "TS");
  await h.adminUpdateWinner({ id: "w1", patch: { extendDays: 3 } }, adminCtx);
  assert.strictEqual(store.raffle_winners.w1.expired, false);
  assert.strictEqual(store.raffle_winners.w1.claimDeadline.getTime(), NOW.getTime() + 3 * 86400000);
  await assert.rejects(h.adminUpdateWinner({ id: "w1", patch: { deliveryStatus: "bogus" } }, adminCtx), code("invalid-argument"));
  await assert.rejects(h.adminUpdateWinner({ id: "w1", patch: { extendDays: 99 } }, adminCtx), code("invalid-argument"));
  await assert.rejects(h.adminUpdateWinner({ id: "nope", patch: { deliveryNote: "x" } }, adminCtx), code("not-found"));
  await assert.rejects(h.adminUpdateWinner({ id: "w1", patch: {} }, adminCtx), code("invalid-argument"));
});

test("resend push: only for pending wins with a token", async () => {
  const { h, pushes } = setup({
    users: { u1: { fcmToken: "t" }, u2: {} },
    raffle_winners: {
      w1: { userId: "u1", prizeName: "P" }, w2: { userId: "u2", prizeName: "P" },
      w3: { userId: "u1", claimed: true },
    },
  });
  assert.deepStrictEqual(await h.adminResendWinnerPush({ id: "w1" }, adminCtx), { sent: true });
  assert.strictEqual(pushes.length, 1);
  assert.strictEqual((await h.adminResendWinnerPush({ id: "w2" }, adminCtx)).sent, false);
  await assert.rejects(h.adminResendWinnerPush({ id: "w3" }, adminCtx), code("failed-precondition"));
});

test("listWinners filters by month/status and attaches the player's email", async () => {
  const { h } = setup({
    users: { u1: { email: "a@x.com", username: "ann" } },
    raffle_winners: {
      w1: { userId: "u1", monthKey: "2026-09", prizeName: "P" },
      w2: { userId: "u1", monthKey: "2026-08", prizeName: "P", expired: true },
    },
  });
  assert.strictEqual((await h.adminListWinners({ filter: { month: "2026-09" } }, adminCtx)).winners.length, 1);
  const pending = (await h.adminListWinners({ filter: { status: "pending" } }, adminCtx)).winners;
  assert.deepStrictEqual(pending.map((w) => w.id), ["w1"]);
  assert.strictEqual(pending[0].email, "a@x.com");
});

test("entrants list sorted by entries", async () => {
  const { h } = setup(drawSeed());
  const r = await h.adminListEntrants({ month: "2026-09" }, adminCtx);
  assert.deepStrictEqual(r.entrants.map((e) => e.userId), ["u1", "u2"]);
});

test("players: search by email/username/uid, detail, disable", async () => {
  const { h, disabled } = setup({
    users: { u1: { email: "Ann@x.com", username: "ann" }, u2: { email: "b@x.com", username: "bob" } },
    monthly_records: { u1_2026_09: { userId: "u1", monthKey: "2026-09", totalEntries: 2 } },
  });
  assert.strictEqual((await h.adminSearchUsers({ query: "ann@X" }, adminCtx)).users[0].uid, "u1");
  assert.strictEqual((await h.adminSearchUsers({ query: "bob" }, adminCtx)).users[0].uid, "u2");
  assert.strictEqual((await h.adminSearchUsers({ query: "u2" }, adminCtx)).users[0].uid, "u2");
  const d = await h.adminGetUser({ uid: "u1" }, adminCtx);
  assert.strictEqual(d.records[0].totalEntries, 2);
  await assert.rejects(h.adminGetUser({ uid: "zz" }, adminCtx), code("not-found"));
  await h.adminSetUserDisabled({ uid: "u1", disabled: true }, adminCtx);
  assert.deepStrictEqual(disabled, [["u1", { disabled: true }]]);
  await assert.rejects(h.adminSetUserDisabled({ uid: "admin1", disabled: true }, adminCtx), code("failed-precondition"));
  await assert.rejects(h.adminSetUserDisabled({ uid: "u1", disabled: "yes" }, adminCtx), code("invalid-argument"));
});

test("deleteUser requires the typed uid, deletes data + auth, audits", async () => {
  const { h, store, deleted } = setup({
    users: { u1: { email: "a@x.com", username: "ann" } },
    monthly_records: { r1: { userId: "u1" } }, used_sessions: { s1: { userId: "u1" } },
  });
  await assert.rejects(h.adminDeleteUser({ uid: "u1" }, adminCtx), code("invalid-argument"));
  await assert.rejects(h.adminDeleteUser({ uid: "u1", confirmUid: "u2" }, adminCtx), code("invalid-argument"));
  assert.ok(store.users.u1);
  const r = await h.adminDeleteUser({ uid: "u1", confirmUid: "u1" }, adminCtx);
  assert.strictEqual(r.deleted, true);
  assert.strictEqual(store.users.u1, undefined);
  assert.deepStrictEqual(deleted, ["u1"]);
  const a = Object.values(store.admin_audit)[0];
  assert.strictEqual(a.action, "deleteUser");
  assert.strictEqual(a.before.email, "a@x.com");
});

test("audit list is newest first and limited", async () => {
  const { h } = setup({ admin_audit: {
    a: { action: "x", at: new Date("2026-10-01") },
    b: { action: "y", at: new Date("2026-10-03") },
    c: { action: "z", at: new Date("2026-10-02") },
  } });
  const r = await h.adminListAudit({ limit: 2 }, adminCtx);
  assert.deepStrictEqual(r.entries.map((e) => e.action), ["y", "z"]);
});

function bootstrapSetup(seed = {}, failClaims = false) {
  const { db, store } = makeDb(seed);
  const claims = [];
  const auth = {
    getUser: async () => ({ customClaims: { x: 1 } }),
    setCustomUserClaims: async (u, c) => { if (failClaims) throw new Error("boom"); claims.push([u, c]); },
  };
  const run = makeBootstrap({ db, auth, FieldValue: { serverTimestamp: () => "TS" }, allowedEmail: "Boss@x.com" });
  return { run, store, claims };
}
const ctxFor = (email, extra = {}) => ({ auth: { uid: "u9", token: { email, ...extra } } });

test("bootstrap: only the allowed email gets the claim, and only once", async () => {
  const { run, store, claims } = bootstrapSetup();
  await assert.rejects(run({}, {}), code("unauthenticated"));
  assert.deepStrictEqual(await run({}, ctxFor("other@x.com")), { granted: false });
  assert.strictEqual(claims.length, 0);
  assert.deepStrictEqual(await run({}, ctxFor("boss@X.com")), { granted: true });
  assert.deepStrictEqual(claims, [["u9", { x: 1, admin: true }]]);
  assert.strictEqual(Object.values(store.admin_audit)[0].action, "bootstrapAdmin");
  const again = await run({}, { auth: { uid: "u10", token: { email: "boss@x.com" } } });
  assert.strictEqual(again.reason, "already_bootstrapped");
  assert.strictEqual(claims.length, 1);
});

test("bootstrap: existing admins are left alone; a failed grant frees the slot", async () => {
  const a = bootstrapSetup();
  assert.strictEqual((await a.run({}, ctxFor("boss@x.com", { admin: true }))).reason, "already_admin");
  const b = bootstrapSetup({}, true);
  await assert.rejects(b.run({}, ctxFor("boss@x.com")), /boom/);
  assert.ok(!b.store.admin_config || !b.store.admin_config.bootstrap);
});

test("bootstrap: disabled when no allowed email is configured", async () => {
  const { db } = makeDb();
  const run = makeBootstrap({ db, auth: {}, FieldValue: {}, allowedEmail: undefined });
  assert.deepStrictEqual(await run({}, ctxFor("boss@x.com")), { granted: false });
});
