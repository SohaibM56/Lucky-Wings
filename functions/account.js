// Account deletion (Google Play "account deletion" requirement).
//
// Removes everything that identifies a player and keeps only what the
// raffle needs for its own history:
//   users/{uid}               deleted (name, email, avatar, FCM token)
//   monthly_records (userId)  deleted (scores, play time, entries)
//   used_sessions (userId)    deleted (replay-protection ids)
//   raffle_winners (userId)   KEPT but flagged userDeleted:true — the prize
//                             history stays auditable; with the Auth user and
//                             profile gone, the remaining uid is not linkable
//                             to a person.
//   Firebase Auth user        deleted last, so a failed run can simply be retried.

const RECENT_LOGIN_SECONDS = 300;

/**
 * Throws the error code the app understands as "ask the user to sign in
 * again" when the sign-in is older than five minutes. Guests (anonymous)
 * have no credentials to re-enter, so they are exempt.
 */
function assertRecentSignIn(token, nowSeconds = Math.floor(Date.now() / 1000)) {
  const provider = token && token.firebase && token.firebase.sign_in_provider;
  if (provider === "anonymous") return;
  const authTime = token && token.auth_time;
  if (typeof authTime !== "number" || nowSeconds - authTime > RECENT_LOGIN_SECONDS) {
    const err = new Error("reauth-required");
    err.code = "reauth-required";
    throw err;
  }
}

async function deleteDocs(snap) {
  let n = 0;
  for (const doc of snap.docs) {
    await doc.ref.delete();
    n++;
  }
  return n;
}

/**
 * @param {object} deps { db, auth, FieldValue } — firebase-admin handles.
 * @returns counts of what was removed, for logging/tests.
 */
async function deleteAccountData({ db, auth, FieldValue }, uid) {
  const result = { user: 0, records: 0, sessions: 0, winnersKept: 0 };

  const userRef = db.collection("users").doc(uid);
  if ((await userRef.get()).exists) {
    await userRef.delete();
    result.user = 1;
  }

  result.records = await deleteDocs(
    await db.collection("monthly_records").where("userId", "==", uid).get());
  result.sessions = await deleteDocs(
    await db.collection("used_sessions").where("userId", "==", uid).get());

  const wins = await db.collection("raffle_winners").where("userId", "==", uid).get();
  for (const doc of wins.docs) {
    await doc.ref.update({ userDeleted: true, userDeletedAt: FieldValue.serverTimestamp() });
    result.winnersKept++;
  }

  await auth.deleteUser(uid);
  return result;
}

module.exports = { assertRecentSignIn, deleteAccountData, RECENT_LOGIN_SECONDS };
