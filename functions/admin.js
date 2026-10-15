// Admin panel callables (see ADMIN_PANEL_PLAN.md).
//
// Every handler is built by makeAdminHandlers(deps) so tests can inject an
// in-memory Firestore. Each one starts with requireAdmin(), validates its
// input, writes an admin_audit entry when it mutates, and returns plain JSON.

const { deleteAccountData } = require("./account");

const CLAIM_WINDOW_DAYS = 7;
const MONTH_RE = /^\d{4}-(0[1-9]|1[0-2])$/;
const DELIVERY_STATUSES = ["none", "contacted", "shipped", "delivered"];

class AdminError extends Error {
  constructor(code, message) { super(message); this.code = code; }
}
const fail = (code, msg) => { throw new AdminError(code, msg); };

function requireAdmin(context) {
  if (!context || !context.auth || !context.auth.token || context.auth.token.admin !== true) {
    fail("permission-denied", "Admin access required.");
  }
  return { uid: context.auth.uid, email: context.auth.token.email || null };
}

const monthKeyOf = (d) =>
  `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, "0")}`;
const nextMonthKey = (d) => monthKeyOf(new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + 1, 1)));
const prevMonthKey = (d) => monthKeyOf(new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() - 1, 1)));

function str(v, name, { max = 200, required = true } = {}) {
  if (v === undefined || v === null || v === "") {
    if (required) fail("invalid-argument", `${name} is required.`);
    return "";
  }
  if (typeof v !== "string") fail("invalid-argument", `${name} must be a string.`);
  const t = v.trim();
  if (required && !t) fail("invalid-argument", `${name} is required.`);
  if (t.length > max) fail("invalid-argument", `${name} is too long.`);
  return t;
}
function month(v) {
  const m = str(v, "month");
  if (!MONTH_RE.test(m)) fail("invalid-argument", "month must be YYYY-MM.");
  return m;
}
const toMillis = (v) => {
  if (!v) return null;
  if (typeof v.toMillis === "function") return v.toMillis();
  if (v instanceof Date) return v.getTime();
  return typeof v === "number" ? v : null;
};

// Weighted pick: each entry is one ticket. `rand` is injectable for tests.
function pickWinner(records, rand = Math.random) {
  const pool = [];
  for (const r of records) for (let i = 0; i < (r.totalEntries || 0); i++) pool.push(r);
  if (!pool.length) return { poolSize: 0, winner: null };
  return { poolSize: pool.length, winner: pool[Math.floor(rand() * pool.length)] };
}

function makeAdminHandlers({ db, auth, messaging, FieldValue, now = () => new Date(), rand = Math.random }) {
  async function audit(actor, action, target, before, after, extra) {
    await db.collection("admin_audit").add({
      actorUid: actor.uid, actorEmail: actor.email, action, target,
      before: before ?? null, after: after ?? null, ...(extra || {}),
      at: FieldValue.serverTimestamp(),
    });
  }

  const cleanWinner = (id, w) => ({
    id, userId: w.userId, monthKey: w.monthKey, prizeName: w.prizeName,
    totalEntries: w.totalEntries ?? 0,
    wonAt: toMillis(w.wonAt), claimed: !!w.claimed, claimedAt: toMillis(w.claimedAt),
    claimDeadline: toMillis(w.claimDeadline), expired: !!w.expired,
    deliveryStatus: w.deliveryStatus || "none", deliveryNote: w.deliveryNote || "",
    contactedAt: toMillis(w.contactedAt), deliveredAt: toMillis(w.deliveredAt),
    disqualified: !!w.disqualified, disqualifiedReason: w.disqualifiedReason || "",
    userDeleted: !!w.userDeleted,
  });
  const isActiveWin = (w) => !w.disqualified && !w.expired;

  // uid -> sign-up time (ms) from Firebase Auth; the app never stores createdAt on profiles.
  async function authCreatedMap() {
    const map = new Map();
    if (typeof auth.listUsers !== "function") return map;
    let pageToken;
    do {
      const r = await auth.listUsers(1000, pageToken);
      r.users.forEach((u) => {
        const t = Date.parse(u.metadata && u.metadata.creationTime);
        if (!Number.isNaN(t)) map.set(u.uid, t);
      });
      pageToken = r.pageToken;
    } while (pageToken);
    return map;
  }

  async function eligibleRecords(monthKey) {
    const snap = await db.collection("monthly_records")
      .where("monthKey", "==", monthKey).where("totalEntries", ">", 0).get();
    return snap.docs.map((d) => d.data()).filter((r) => !r.disqualified);
  }

  async function winnersForMonth(monthKey) {
    const s = await db.collection("raffle_winners").where("monthKey", "==", monthKey).get();
    return s.docs.map((d) => ({ id: d.id, ...d.data() }));
  }

  // ── dashboard ──────────────────────────────────────────────────────────────
  async function adminGetDashboard(data, context) {
    requireAdmin(context);
    const n = now();
    const mk = monthKeyOf(n);
    const dayKey = n.toISOString().split("T")[0];
    const weekAgo = n.getTime() - 7 * 86400000;

    const users = await db.collection("users").get();
    let newThisWeek = 0;
    const created = await authCreatedMap();
    users.docs.forEach((d) => {
      const c = created.get(d.id) || toMillis(d.data().createdAt);
      if (c && c >= weekAgo) newThisWeek++;
    });

    const recs = await db.collection("monthly_records").where("monthKey", "==", mk).get();
    let entries = 0, activeToday = 0;
    recs.docs.forEach((d) => {
      const r = d.data();
      entries += r.totalEntries || 0;
      if (r.dailyActiveSeconds && r.dailyActiveSeconds[dayKey] > 0) activeToday++;
    });

    const prizeDoc = await db.collection("raffle_config").doc(mk).get();
    const nextPrize = await db.collection("raffle_config").doc(nextMonthKey(n)).get();
    const nextDraw = new Date(Date.UTC(n.getUTCFullYear(), n.getUTCMonth() + 1, 1, 0, 5));

    const wins = await db.collection("raffle_winners").get();
    let unclaimed = 0, expiring = 0;
    wins.docs.forEach((d) => {
      const w = d.data();
      if (w.claimed || w.expired || w.disqualified) return;
      unclaimed++;
      const dl = toMillis(w.claimDeadline);
      if (dl && dl - n.getTime() < 48 * 3600000 && dl > n.getTime()) expiring++;
    });

    const warnings = [];
    if (!nextPrize.exists) warnings.push(`No prize set for ${nextMonthKey(n)}.`);
    return {
      month: mk,
      players: { total: users.docs.length, newThisWeek },
      activeToday, entriesThisMonth: entries,
      currentPrize: prizeDoc.exists ? prizeDoc.data().prize : null,
      daysToDraw: Math.ceil((nextDraw.getTime() - n.getTime()) / 86400000),
      unclaimedWins: unclaimed, expiringWins: expiring, warnings,
    };
  }

  // ── prizes ─────────────────────────────────────────────────────────────────
  async function adminListPrizes(data, context) {
    requireAdmin(context);
    const snap = await db.collection("raffle_config").get();
    const prizes = snap.docs.map((d) => ({
      month: d.id, prize: d.data().prize || "", description: d.data().description || "",
      imageUrl: d.data().imageUrl || "",
    })).sort((a, b) => (a.month < b.month ? 1 : -1));
    const nm = nextMonthKey(now());
    return { prizes, nextMonth: nm, nextMonthMissing: !prizes.some((p) => p.month === nm) };
  }

  async function adminSetPrize(data, context) {
    const actor = requireAdmin(context);
    const m = month(data && data.month);
    if (m < monthKeyOf(now())) fail("failed-precondition", "Cannot edit a past month.");
    const prize = str(data.prize, "prize", { max: 120 });
    const description = str(data.description, "description", { max: 1000, required: false });
    const imageUrl = str(data.imageUrl, "imageUrl", { max: 500, required: false });
    if (imageUrl && !/^https:\/\//.test(imageUrl)) fail("invalid-argument", "imageUrl must be https.");
    const ref = db.collection("raffle_config").doc(m);
    const prev = await ref.get();
    const after = { prize, description, imageUrl };
    await ref.set(after, { merge: true });
    await audit(actor, "setPrize", `raffle_config/${m}`, prev.exists ? prev.data() : null, after);
    return { month: m, ...after };
  }

  // ── entrants ───────────────────────────────────────────────────────────────
  async function adminListEntrants(data, context) {
    requireAdmin(context);
    const m = month(data && data.month);
    const snap = await db.collection("monthly_records").where("monthKey", "==", m).get();
    const entrants = snap.docs.map((d) => d.data()).map((r) => ({
      userId: r.userId, username: r.username || "", totalEntries: r.totalEntries || 0,
      bestScore: r.bestScore || 0, totalSessions: r.totalSessions || 0,
      totalPlaySeconds: r.totalPlaySeconds || 0, disqualified: !!r.disqualified,
    })).sort((a, b) => b.totalEntries - a.totalEntries);
    return { month: m, entrants };
  }

  // ── winners ────────────────────────────────────────────────────────────────
  async function adminListWinners(data, context) {
    requireAdmin(context);
    const filter = (data && data.filter) || {};
    let q = db.collection("raffle_winners");
    if (filter.month) q = q.where("monthKey", "==", month(filter.month));
    const snap = await q.get();
    let winners = snap.docs.map((d) => cleanWinner(d.id, d.data()));
    if (filter.status === "pending") winners = winners.filter((w) => !w.claimed && !w.expired && !w.disqualified);
    else if (filter.status === "expired") winners = winners.filter((w) => w.expired);
    else if (filter.status === "claimed") winners = winners.filter((w) => w.claimed);
    winners.sort((a, b) => (b.wonAt || 0) - (a.wonAt || 0));
    // attach emails for the operator (support needs to contact the winner)
    for (const w of winners) {
      const u = await db.collection("users").doc(w.userId).get();
      w.email = u.exists ? u.data().email || "" : "";
      w.username = u.exists ? u.data().username || "" : "";
    }
    return { winners };
  }

  async function adminUpdateWinner(data, context) {
    const actor = requireAdmin(context);
    const id = str(data && data.id, "id");
    const patch = (data && data.patch) || {};
    const ref = db.collection("raffle_winners").doc(id);
    const snap = await ref.get();
    if (!snap.exists) fail("not-found", "Winner not found.");
    const before = snap.data();
    const update = {};

    if (patch.deliveryStatus !== undefined) {
      if (!DELIVERY_STATUSES.includes(patch.deliveryStatus)) fail("invalid-argument", "Bad deliveryStatus.");
      update.deliveryStatus = patch.deliveryStatus;
      if (patch.deliveryStatus === "contacted" && !before.contactedAt) update.contactedAt = FieldValue.serverTimestamp();
      if (patch.deliveryStatus === "delivered") update.deliveredAt = FieldValue.serverTimestamp();
    }
    if (patch.deliveryNote !== undefined) update.deliveryNote = str(patch.deliveryNote, "deliveryNote", { max: 1000, required: false });
    if (patch.extendDays !== undefined) {
      const days = patch.extendDays;
      if (!Number.isInteger(days) || days < 1 || days > 30) fail("invalid-argument", "extendDays must be 1-30.");
      if (before.disqualified) fail("failed-precondition", "Winner is disqualified.");
      const base = Math.max(toMillis(before.claimDeadline) || 0, now().getTime());
      update.claimDeadline = new Date(base + days * 86400000);
      update.expired = false;
    }
    if (patch.disqualify !== undefined) {
      if (patch.disqualify !== true) fail("invalid-argument", "disqualify must be true.");
      update.disqualified = true;
      update.disqualifiedReason = str(patch.reason, "reason", { max: 500 });
    }
    if (!Object.keys(update).length) fail("invalid-argument", "Nothing to update.");
    await ref.update(update);
    await audit(actor, "updateWinner", `raffle_winners/${id}`, before, update);
    return { id, updated: Object.keys(update) };
  }

  async function adminResendWinnerPush(data, context) {
    const actor = requireAdmin(context);
    const id = str(data && data.id, "id");
    const snap = await db.collection("raffle_winners").doc(id).get();
    if (!snap.exists) fail("not-found", "Winner not found.");
    const w = snap.data();
    if (w.claimed || w.expired || w.disqualified) fail("failed-precondition", "Win is not pending.");
    const u = await db.collection("users").doc(w.userId).get();
    const token = u.exists ? u.data().fcmToken : null;
    if (!token) return { sent: false, reason: "no_token" };
    await messaging.send({
      token,
      notification: { title: "🏆 Reminder: claim your prize", body: `You won: ${w.prizeName}. Open the app to claim.` },
      data: { type: "winner", winnerId: id },
    });
    await audit(actor, "resendWinnerPush", `raffle_winners/${id}`, null, null);
    return { sent: true };
  }

  // ── draw ───────────────────────────────────────────────────────────────────
  async function adminPreviewDraw(data, context) {
    requireAdmin(context);
    const m = month(data && data.month);
    const existing = (await winnersForMonth(m)).filter(isActiveWin);
    const records = await eligibleRecords(m);
    const { poolSize, winner } = pickWinner(records, rand);
    const prizeDoc = await db.collection("raffle_config").doc(m).get();
    return {
      month: m, poolSize, entrants: records.length,
      candidate: winner ? { userId: winner.userId, username: winner.username || "", totalEntries: winner.totalEntries } : null,
      prizeName: prizeDoc.exists ? prizeDoc.data().prize : "Monthly Prize",
      existingWinnerId: existing[0] ? existing[0].id : null,
    };
  }

  async function adminRunDraw(data, context) {
    const actor = requireAdmin(context);
    const m = month(data && data.month);
    const redraw = !!(data && data.redraw);
    const reason = str(data && data.reason, "reason", { max: 500, required: redraw });

    const all = await winnersForMonth(m);
    if (all.length && !redraw) fail("already-exists", "A winner already exists for this month.");
    if (redraw) {
      if (!all.length) fail("failed-precondition", "Nothing to redraw.");
      // A claimed or still-running win stands; only expired/disqualified ones can be redrawn.
      if (all.some(isActiveWin)) {
        fail("failed-precondition", "Redraw only allowed when the previous winner expired or was disqualified.");
      }
    }

    const previous = new Set(all.map((w) => w.userId));
    const records = (await eligibleRecords(m)).filter((r) => !previous.has(r.userId));
    const { winner } = pickWinner(records, rand);
    if (!winner) fail("failed-precondition", "No eligible entrants.");

    const prizeDoc = await db.collection("raffle_config").doc(m).get();
    const prizeName = prizeDoc.exists ? prizeDoc.data().prize : "Monthly Prize";
    const ref = await db.collection("raffle_winners").add({
      userId: winner.userId, monthKey: m, prizeName, totalEntries: winner.totalEntries,
      wonAt: FieldValue.serverTimestamp(), claimed: false,
      claimDeadline: new Date(now().getTime() + CLAIM_WINDOW_DAYS * 86400000),
      deliveryStatus: "none", drawnManually: true,
    });

    if (redraw) {
      // Keep the old win, flagged, so the history stays auditable.
      for (const w of all.filter((x) => !x.disqualified)) {
        await db.collection("raffle_winners").doc(w.id).update({
          disqualified: true, disqualifiedReason: reason,
        });
      }
    }

    const u = await db.collection("users").doc(winner.userId).get();
    const token = u.exists ? u.data().fcmToken : null;
    if (token) {
      await messaging.send({
        token,
        notification: { title: "🏆 You Won Flapper Birds!", body: `Congratulations! You won: ${prizeName}. Open the app to claim.` },
        data: { type: "winner", winnerId: ref.id },
      });
    }
    await audit(actor, redraw ? "redraw" : "runDraw", `raffle_winners/${ref.id}`, null,
      { month: m, winnerUid: winner.userId, prizeName }, { reason: reason || null });
    return { id: ref.id, userId: winner.userId, prizeName, pushed: !!token };
  }

  // ── players ────────────────────────────────────────────────────────────────
  // Empty query lists the newest players; otherwise matches email / username / uid.
  async function adminSearchUsers(data, context) {
    requireAdmin(context);
    const q = str(data && data.query, "query", { max: 100, required: false }).toLowerCase();
    const snap = await db.collection("users").get();
    const created = await authCreatedMap();
    const out = [];
    for (const d of snap.docs) {
      const u = d.data();
      if (!q || d.id === q || (u.email || "").toLowerCase().includes(q) || (u.username || "").toLowerCase().includes(q)) {
        out.push({ uid: d.id, username: u.username || "", email: u.email || "",
          createdAt: created.get(d.id) || toMillis(u.createdAt) });
      }
    }
    out.sort((a, b) => (b.createdAt || 0) - (a.createdAt || 0));
    return { users: out.slice(0, q ? 25 : 100), total: out.length };
  }

  async function adminGetUser(data, context) {
    requireAdmin(context);
    const uid = str(data && data.uid, "uid", { max: 128 });
    const u = await db.collection("users").doc(uid).get();
    if (!u.exists) fail("not-found", "User not found.");
    const p = u.data();
    let disabled = false;
    let createdAt = null;
    try {
      const au = await auth.getUser(uid);
      disabled = !!au.disabled;
      createdAt = Date.parse(au.metadata && au.metadata.creationTime) || null;
    } catch (e) { /* auth user may be gone */ }
    const recs = await db.collection("monthly_records").where("userId", "==", uid).get();
    const records = recs.docs.map((d) => d.data()).map((r) => ({
      monthKey: r.monthKey, totalEntries: r.totalEntries || 0, bestScore: r.bestScore || 0,
      totalSessions: r.totalSessions || 0, totalPlaySeconds: r.totalPlaySeconds || 0,
      disqualified: !!r.disqualified,
    })).sort((a, b) => (a.monthKey < b.monthKey ? 1 : -1));
    const wins = await db.collection("raffle_winners").where("userId", "==", uid).get();
    return {
      uid, username: p.username || "", email: p.email || "", avatarId: p.avatarId || "",
      totalWins: p.totalWins || 0, createdAt: createdAt || toMillis(p.createdAt), disabled,
      records, wins: wins.docs.map((d) => cleanWinner(d.id, d.data())),
    };
  }

  async function adminSetUserDisabled(data, context) {
    const actor = requireAdmin(context);
    const uid = str(data && data.uid, "uid", { max: 128 });
    if (typeof data.disabled !== "boolean") fail("invalid-argument", "disabled must be boolean.");
    if (uid === actor.uid) fail("failed-precondition", "You cannot disable yourself.");
    await auth.updateUser(uid, { disabled: data.disabled });
    await audit(actor, data.disabled ? "disableUser" : "enableUser", `users/${uid}`, null, { disabled: data.disabled });
    return { uid, disabled: data.disabled };
  }

  async function adminDeleteUser(data, context) {
    const actor = requireAdmin(context);
    const uid = str(data && data.uid, "uid", { max: 128 });
    if (data.confirmUid !== uid) fail("invalid-argument", "confirmUid must equal uid.");
    if (uid === actor.uid) fail("failed-precondition", "You cannot delete yourself.");
    const u = await db.collection("users").doc(uid).get();
    const before = u.exists ? { email: u.data().email || null, username: u.data().username || null } : null;
    const result = await deleteAccountData({ db, auth, FieldValue }, uid);
    await audit(actor, "deleteUser", `users/${uid}`, before, result);
    return { deleted: true, ...result };
  }

  // ── audit ──────────────────────────────────────────────────────────────────
  async function adminListAudit(data, context) {
    requireAdmin(context);
    const limit = Math.min(Math.max(parseInt(data && data.limit, 10) || 100, 1), 500);
    const snap = await db.collection("admin_audit").orderBy("at", "desc").limit(limit).get();
    return {
      entries: snap.docs.map((d) => {
        const e = d.data();
        return { id: d.id, actorEmail: e.actorEmail, actorUid: e.actorUid, action: e.action,
          target: e.target, before: e.before ?? null, after: e.after ?? null,
          reason: e.reason ?? null, at: toMillis(e.at) };
      }),
    };
  }

  return {
    adminGetDashboard, adminListPrizes, adminSetPrize, adminListEntrants,
    adminListWinners, adminUpdateWinner, adminResendWinnerPush,
    adminPreviewDraw, adminRunDraw, adminSearchUsers, adminGetUser,
    adminSetUserDisabled, adminDeleteUser, adminListAudit,
  };
}

/**
 * One-time admin bootstrap. The signed-in caller gets the admin claim only if
 * their email equals the single allowed address (ADMIN_BOOTSTRAP_EMAIL) and
 * no bootstrap has happened before. The slot is claimed atomically with
 * create(), so it can succeed at most once; it is released if granting fails.
 */
function makeBootstrap({ db, auth, FieldValue, allowedEmail }) {
  return async function adminBootstrap(data, context) {
    if (!context || !context.auth) fail("unauthenticated", "Sign in first.");
    const token = context.auth.token || {};
    const allowed = (allowedEmail || "").trim().toLowerCase();
    if (!allowed || (token.email || "").toLowerCase() !== allowed) return { granted: false };
    if (token.admin === true) return { granted: false, reason: "already_admin" };

    const slot = db.collection("admin_config").doc("bootstrap");
    try {
      await slot.create({ uid: context.auth.uid, email: allowed, at: FieldValue.serverTimestamp() });
    } catch (e) {
      if (e && (e.code === 6 || e.code === "already-exists")) return { granted: false, reason: "already_bootstrapped" };
      throw e;
    }
    try {
      const user = await auth.getUser(context.auth.uid);
      await auth.setCustomUserClaims(context.auth.uid, { ...(user.customClaims || {}), admin: true });
    } catch (e) {
      await slot.delete();
      throw e;
    }
    await db.collection("admin_audit").add({
      actorUid: context.auth.uid, actorEmail: allowed, action: "bootstrapAdmin",
      target: `users/${context.auth.uid}`, before: null, after: { admin: true }, at: FieldValue.serverTimestamp(),
    });
    return { granted: true };
  };
}

module.exports = { makeBootstrap, makeAdminHandlers, requireAdmin, AdminError, pickWinner, prevMonthKey, monthKeyOf };
