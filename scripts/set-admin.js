// Grants (or revokes) the admin custom claim for an email.
//
//   node scripts/set-admin.js <service-account.json> <email> [--revoke]
//
// The service account JSON is passed by path and must never be committed.
// Run from the functions/ folder's node_modules context:
//   cd functions && node ../scripts/set-admin.js ..\key.json you@example.com

const path = require("path");
const admin = require(path.join(__dirname, "..", "functions", "node_modules", "firebase-admin"));

async function main() {
  const [keyPath, email, flag] = process.argv.slice(2);
  if (!keyPath || !email) {
    console.error("usage: node scripts/set-admin.js <service-account.json> <email> [--revoke]");
    process.exit(1);
  }
  admin.initializeApp({ credential: admin.credential.cert(require(path.resolve(keyPath))) });
  const user = await admin.auth().getUserByEmail(email);
  const revoke = flag === "--revoke";
  await admin.auth().setCustomUserClaims(user.uid, { ...(user.customClaims || {}), admin: !revoke });
  console.log(`${revoke ? "Revoked" : "Granted"} admin for ${email} (${user.uid}). Sign out and in again to refresh the token.`);
}
main().catch((e) => { console.error(e.message); process.exit(1); });
