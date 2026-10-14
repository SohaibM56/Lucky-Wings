/**
 * Flapper Birds — Firebase Cloud Functions
 * Deploy: firebase deploy --only functions
 *
 * Functions:
 *   verifyQualification  - validates a session token and grants raffle entry
 *   monthlyRaffleDraw    - scheduled: runs 1st of each month at 00:05 UTC
 *   expireUnclaimedWins  - scheduled: checks for unclaimed wins after 7 days
 *   sendDrawDayReminder  - scheduled: sends FCM push on draw day at 10:00 UTC
 */

const functions = require("firebase-functions/v1");
const admin     = require("firebase-admin");
admin.initializeApp();

const { applyBlocks } = require("./qualifier");
const { assertRecentSignIn, deleteAccountData } = require("./account");
const { makeAdminHandlers } = require("./admin");

const db        = admin.firestore();
const messaging = admin.messaging();
// firebase-admin 13 no longer hangs FieldValue off the legacy admin.firestore namespace.
const FieldValue = admin.firestore.FieldValue || require("firebase-admin/firestore").FieldValue;

// ─── Constants ────────────────────────────────────────────────────────────────

const CLAIM_WINDOW_DAYS   = 7;     // days winner has to claim prize
const MAX_ENTRIES_PER_MO  = 31;    // max days in a month

// ─── verifyQualification ──────────────────────────────────────────────────────
//
// Called by the app after each game session with the signed token.
// Returns { qualified: bool, entryGranted: bool, catchupApplied: bool }

exports.verifyQualification = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be signed in.");
  }

  const { sessionId, userId, dayKey, monthKey, activeSeconds,
          score, startedAt, endedAt, heartbeatTimestamps, checksum } = data;

  // 1. Auth matches token
  if (context.auth.uid !== userId) {
    throw new functions.https.HttpsError("permission-denied", "User mismatch.");
  }

  // 2. Replay attack check — sessionId must be unique per user per day
  const sessionRef = db.collection("used_sessions").doc(`${userId}_${sessionId}`);
  const sessionSnap = await sessionRef.get();
  if (sessionSnap.exists) {
    return { qualified: false, entryGranted: false, reason: "duplicate_session" };
  }

  // 3. Day key must match server time (prevents clock manipulation)
  const serverNow = new Date();
  const serverDayKey = serverNow.toISOString().split("T")[0]; // "2026-05-15"
  if (dayKey !== serverDayKey) {
    // Allow a day either side (the player's local date can be ahead of or
    // behind UTC) but nothing further
    const yesterday = new Date(serverNow - 86400000).toISOString().split("T")[0];
    const tomorrow = new Date(+serverNow + 86400000).toISOString().split("T")[0];
    if (dayKey !== yesterday && dayKey !== tomorrow) {
      return { qualified: false, entryGranted: false, reason: "invalid_day" };
    }
  }

  // 4. Heartbeat count sanity check
  // expect at least (activeSeconds / 30) - 4 heartbeats (each pause/resume
  // restarts the 30s timer, so a few can legitimately be missing)
  const minHeartbeats = Math.max(0, Math.floor(activeSeconds / 30) - 4);
  if (heartbeatTimestamps.length < minHeartbeats) {
    return { qualified: false, entryGranted: false, reason: "insufficient_heartbeats" };
  }

  // 5. Active seconds cannot exceed wall-clock time
  const sessionStart = new Date(startedAt).getTime();
  const sessionEnd   = new Date(endedAt).getTime();
  const wallSeconds  = Math.floor((sessionEnd - sessionStart) / 1000);
  if (activeSeconds > wallSeconds + 15) {
    return { qualified: false, entryGranted: false, reason: "time_overflow" };
  }

  // 6. Mark session as used
  await sessionRef.set({ userId, sessionId, usedAt: FieldValue.serverTimestamp() });

  // 8. Load or create monthly record
  const recordId  = `${userId}_${monthKey}`;
  const recordRef = db.collection("monthly_records").doc(recordId);
  const recordSnap = await recordRef.get();
  let record = recordSnap.exists ? recordSnap.data() : {
    userId, monthKey,
    qualifiedDays: [], catchupDays: [], bestScore: 0,
    totalSessions: 0, totalPlaySeconds: 0, totalEntries: 0,
    dailyActiveSeconds: {},
  };

  // Denormalize the display name/avatar onto the record so the leaderboard
  // can read it directly instead of joining against users/{uid} per entry.
  // Only re-fetched when missing — not on every session — since it rarely
  // changes mid-month.
  if (!record.username) {
    const userDoc = await db.collection("users").doc(userId).get();
    if (userDoc.exists) {
      record.username = userDoc.data().username || "Player";
      record.avatarId = userDoc.data().avatarId || "bird_1";
    }
  }

  // 7. Bank this session onto the day's running total and grant entries: every
  // full 300s of play that day is one entry — the first block qualifies the
  // day, each further block earns the oldest missed day. "Today" comes from the
  // token's own dayKey (already validated above) so server and app agree on the
  // day even when the server's UTC date differs from the player's local date.
  const [dy, dm, dd] = dayKey.split("-").map(Number);
  const { meetsThreshold, entryGranted, catchupApplied } =
    applyBlocks(record, dayKey, activeSeconds, new Date(dy, dm - 1, dd));

  // Update best score
  if (score > (record.bestScore || 0)) {
    record.bestScore = score;
  }
  record.totalSessions    = (record.totalSessions    || 0) + 1;
  record.totalPlaySeconds = (record.totalPlaySeconds || 0) + activeSeconds;
  record.totalEntries     = record.qualifiedDays.length + record.catchupDays.length;
  record.updatedAt        = FieldValue.serverTimestamp();

  await recordRef.set(record, { merge: true });

  return {
    qualified    : meetsThreshold,
    entryGranted,
    catchupApplied,
    totalEntries : record.totalEntries,
    // Return the record we just wrote so the client doesn't need a second
    // round-trip read to pick up what this call already computed.
    record: {
      userId: record.userId,
      monthKey: record.monthKey,
      qualifiedDays: record.qualifiedDays,
      catchupDays: record.catchupDays,
      bestScore: record.bestScore,
      totalSessions: record.totalSessions,
      totalPlaySeconds: record.totalPlaySeconds,
      dailyActiveSeconds: record.dailyActiveSeconds,
    },
  };
});

// ─── deleteAccount ────────────────────────────────────────────────────────────
//
// Called from Settings -> Account -> Delete account. Deletes the caller's own
// data and sign-in (see account.js). Needs a sign-in from the last five
// minutes (guests exempt); otherwise answers "reauth-required" and the app
// asks the player to confirm their password / Google account and retries.

exports.deleteAccount = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be signed in.");
  }
  try {
    assertRecentSignIn(context.auth.token);
  } catch (e) {
    throw new functions.https.HttpsError("failed-precondition", "reauth-required");
  }
  const uid = context.auth.uid;
  const result = await deleteAccountData(
    { db, auth: admin.auth(), FieldValue }, uid);
  functions.logger.info("Account deleted", { uid, ...result });
  return { deleted: true };
});

// ─── monthlyRaffleDraw ────────────────────────────────────────────────────────
//
// Scheduled: runs on the 1st of each month at 00:05 UTC
// Picks a random winner weighted by entry count.

exports.monthlyRaffleDraw = functions.pubsub
  .schedule("5 0 1 * *")
  .timeZone("UTC")
  .onRun(async (context) => {
    const now      = new Date();
    const prev     = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    const monthKey = `${prev.getFullYear()}-${String(prev.getMonth() + 1).padStart(2, "0")}`;

    functions.logger.info(`Running raffle draw for ${monthKey}`);

    // 1. Get all monthly records for the closed month
    const snap = await db.collection("monthly_records")
      .where("monthKey", "==", monthKey)
      .where("totalEntries", ">", 0)
      .get();

    if (snap.empty) {
      functions.logger.warn("No entries for month:", monthKey);
      return null;
    }

    // 2. Build weighted entry pool
    const pool = [];
    snap.docs.forEach(doc => {
      const record = doc.data();
      for (let i = 0; i < record.totalEntries; i++) {
        pool.push(record.userId);
      }
    });

    // 3. Pick winner
    const winnerUid = pool[Math.floor(Math.random() * pool.length)];
    const winnerRecord = snap.docs.find(d => d.data().userId === winnerUid).data();

    // 4. Get prize for this month
    const prizeDoc  = await db.collection("raffle_config").doc(monthKey).get();
    const prizeName = prizeDoc.exists ? prizeDoc.data().prize : "Monthly Prize";

    // 5. Write winner document
    const winnerRef = await db.collection("raffle_winners").add({
      userId    : winnerUid,
      monthKey,
      prizeName,
      totalEntries: winnerRecord.totalEntries,
      wonAt     : FieldValue.serverTimestamp(),
      claimed   : false,
      claimDeadline: new Date(Date.now() + CLAIM_WINDOW_DAYS * 86400000),
    });

    // 6. Send FCM to winner
    const userDoc = await db.collection("users").doc(winnerUid).get();
    const fcmToken = userDoc.exists ? userDoc.data().fcmToken : null;
    if (fcmToken) {
      await messaging.send({
        token: fcmToken,
        notification: {
          title: "🏆 You Won Flapper Birds!",
          body: `Congratulations! You won: ${prizeName}. Open the app to claim.`,
        },
        data: { type: "winner", winnerId: winnerRef.id },
      });
    }

    functions.logger.info(`Winner: ${winnerUid}, Prize: ${prizeName}`);
    return null;
  });

// ─── expireUnclaimedWins ──────────────────────────────────────────────────────
//
// Scheduled: runs daily at 01:00 UTC
// If a winner hasn't claimed in 7 days, picks a new winner.

exports.expireUnclaimedWins = functions.pubsub
  .schedule("0 1 * * *")
  .timeZone("UTC")
  .onRun(async (context) => {
    const now = new Date();
    const expired = await db.collection("raffle_winners")
      .where("claimed", "==", false)
      .where("claimDeadline", "<", now)
      .get();

    for (const doc of expired.docs) {
      // Mark as expired
      await doc.ref.update({ expired: true, expiredAt: FieldValue.serverTimestamp() });
      functions.logger.info(`Expired unclaimed win: ${doc.id}`);
      // Note: Re-draw logic can be triggered here by calling monthlyRaffleDraw
      // with the same monthKey but excluding the expired winner.
    }
    return null;
  });

// ─── sendDrawDayReminder ──────────────────────────────────────────────────────
//
// Scheduled: runs on the 1st of each month at 10:00 UTC
// Sends FCM push to all users who have entries.

exports.sendDrawDayReminder = functions.pubsub
  .schedule("0 10 1 * *")
  .timeZone("UTC")
  .onRun(async (context) => {
    const now      = new Date();
    const prev     = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    const monthKey = `${prev.getFullYear()}-${String(prev.getMonth() + 1).padStart(2, "0")}`;

    const snap = await db.collection("monthly_records")
      .where("monthKey", "==", monthKey)
      .where("totalEntries", ">", 0)
      .get();

    const tokens = [];
    for (const doc of snap.docs) {
      const userDoc = await db.collection("users").doc(doc.data().userId).get();
      if (userDoc.exists && userDoc.data().fcmToken) {
        tokens.push(userDoc.data().fcmToken);
      }
    }

    if (tokens.length > 0) {
      // Send in batches of 500 (FCM limit)
      for (let i = 0; i < tokens.length; i += 500) {
        await messaging.sendEachForMulticast({
          tokens: tokens.slice(i, i + 500),
          notification: {
            title: "🎉 Flapper Birds Draw Day!",
            body: "The monthly raffle is happening now — good luck!",
          },
          data: { type: "draw_day" },
        });
      }
    }
    functions.logger.info(`Draw day reminders sent to ${tokens.length} users`);
    return null;
  });

// ─── Admin panel callables (see admin.js / ADMIN_PANEL_PLAN.md) ──────────────
//
// Each requires the custom claim admin:true. AdminError codes map 1:1 onto
// HttpsError codes.

const adminHandlers = makeAdminHandlers({
  db, auth: admin.auth(), messaging, FieldValue,
});
for (const [name, handler] of Object.entries(adminHandlers)) {
  exports[name] = functions.https.onCall(async (data, context) => {
    try {
      return await handler(data, context);
    } catch (e) {
      if (e && e.code && e.name !== "FirebaseError" && !(e instanceof functions.https.HttpsError)) {
        throw new functions.https.HttpsError(e.code, e.message);
      }
      throw e;
    }
  });
}
