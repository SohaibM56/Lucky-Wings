# Lucky Wings — Admin Panel: Plan, Flows and Build Prompt

Kept at the repo root on purpose. Do **not** move it into `docs/` (that folder is public on GitHub Pages).

## 1. Why an admin panel

Today the operator does these things by hand in the Firebase console:

| Job | Where it lives now |
|---|---|
| Set the monthly prize | create doc `raffle_config/{YYYY-MM}` with a `prize` field |
| Run / check the monthly draw | `monthlyRaffleDraw` (scheduled, 1st of month 00:05 UTC) |
| Contact winner, deliver prize, record it | not tracked anywhere |
| Handle unclaimed wins | `expireUnclaimedWins` marks `expired` after the 7-day claim window |
| Look up a player / support request | Firestore console |
| Delete an account on email request (policy promises 30 days) | not possible without code |

The panel replaces these with one secure web app.

## 2. Existing backend (what the panel builds on)

Project `lucky-wings-1535f`, Cloud Functions v1, Node 20 (**retires 2026-10-30, upgrade first**).

| Collection | Fields (as used by the code) | Client access |
|---|---|---|
| `users/{uid}` | username, email, avatarId, totalWins, createdAt, fcmToken | owner only |
| `monthly_records/{uid_YYYY-MM}` | userId, monthKey, totalEntries, bestScore, username, avatarId, totalSessions, totalPlaySeconds, dailyActiveSeconds | read: any signed-in user, write: none |
| `used_sessions/{uid_sessionId}` | anti-replay record | none |
| `raffle_config/{YYYY-MM}` | prize (name) | read: signed-in, write: none |
| `raffle_winners/{id}` | userId, monthKey, prizeName, totalEntries, wonAt, claimed, claimedAt, claimDeadline, expired | owner reads, may only set claimed/claimedAt |

Functions: `verifyQualification`, `deleteAccount`, `monthlyRaffleDraw`, `expireUnclaimedWins`, `sendDrawDayReminder`.
Reusable: `deleteAccountData(deps, uid)` in `functions/account.js`.

## 3. Architecture

- **Frontend:** React + Vite + TypeScript, Tailwind + a table library (TanStack Table). A separate Firebase Hosting site (target `admin`) in `admin_panel/`. Not GitHub Pages.
- **Auth:** Firebase Auth email/password **plus MFA**, and a custom claim `admin: true` (set once with a script, never from the client). Optional second claim `role: "owner" | "support"`.
- **Data access:** the panel never reads Firestore directly. Everything goes through new **callable Cloud Functions** (`admin*`) that check `context.auth.token.admin === true`. `firestore.rules` stay locked (no admin write path from clients).
- **Audit log:** every admin action writes `admin_audit/{id}` (actor uid/email, action, target, before/after, timestamp). Readable only through `adminListAudit`.
- **Hardening:** Firebase App Check on the admin callables, rate limits, CSP/`X-Frame-Options` headers, no secrets in the bundle, separate Firebase project or at least separate hosting site/domain.

## 4. Features (by phase)

### Phase 0 — prerequisites
1. Upgrade functions runtime (Node 22) and `firebase-functions`.
2. `scripts/set-admin.js` (run locally with a service account) to grant the `admin` claim.
3. Add `admin_audit` collection and helper `requireAdmin(context)` + `audit(...)`.

### Phase 1 — MVP
1. **Dashboard:** players total / new this week, active today, entries this month, current prize, days to draw, unclaimed wins, expiring in <48h.
2. **Prize management:** list/create/edit `raffle_config/{month}` (prize name, description, image URL optional). Warn if next month has no prize. Edits to a past month are blocked.
3. **Raffle & winners:**
   - Month view: all entrants with `totalEntries` and play stats; export CSV.
   - Winners list per month: status chip `Pending claim → Claimed → Contacted → Shipped/Delivered`, or `Expired`.
   - Winner detail: player email, username, entries, claim deadline, notes, delivery fields (tracking, delivered at). Needs new fields on `raffle_winners`: `deliveryStatus`, `deliveryNote`, `contactedAt`, `deliveredAt` (admin-only writes).
   - Actions: mark contacted/delivered, extend claim deadline, re-send winner push, redraw (only if the first winner expired or was disqualified; old win kept with `disqualified: true` and a reason).
4. **Run draw manually:** dry-run preview (pool size, winner shown, nothing written) then confirm. Refuses if a winner already exists for that month unless "redraw" is chosen.
5. **Players:** search by email / username / uid. Detail: profile, monthly records, sessions summary, wins. Actions: delete account (calls `deleteAccountData`, fulfils email deletion requests) and disable/enable sign-in.
6. **Audit log view.**

### Phase 2
1. Anti-cheat review: flag players whose play time / session counts are outliers; disqualify entries for a month (new `monthly_records.disqualified` honoured by the draw).
2. Push broadcast / segmented message (all, entrants this month, winners) via FCM topics or token batches, with preview and rate limit.
3. Remote app settings doc `app_config/current` (daily goal minutes, claim window days, maintenance banner) read by the app.
4. Deletion-request queue (inbound emails logged by hand, 30-day SLA countdown).
5. Roles: `support` read-only + deletion, `owner` everything.

## 5. Flows

### 5.1 Sign-in
```
Admin opens admin site
  -> Firebase email+password
  -> MFA (TOTP/SMS) challenge
  -> client reads ID-token claims
       admin !== true  -> "Not authorised", sign out
       admin === true  -> load dashboard (calls adminGetDashboard)
```

### 5.2 Monthly cycle (prize -> draw -> delivery)
```
 before the 1st            1st 00:05 UTC               within 7 days              after
┌────────────────┐   ┌─────────────────────────┐   ┌────────────────────┐   ┌───────────────┐
│ Admin sets     │   │ monthlyRaffleDraw       │   │ Winner opens app,  │   │ Admin marks   │
│ raffle_config  │──▶│ picks weighted winner,  │──▶│ taps claim         │──▶│ contacted ->  │
│ {next month}   │   │ writes raffle_winners,  │   │ (claimed=true)     │   │ shipped ->    │
│ prize          │   │ sends push              │   └────────┬───────────┘   │ delivered     │
└────────────────┘   └───────────┬─────────────┘            │ no claim      └───────────────┘
        ▲                        │ no prize doc? -> "Monthly Prize"   ▼
        │                        │                        expireUnclaimedWins
   Dashboard warns               │                        sets expired=true
   if prize missing              ▼                                │
                       Winner shows in panel  ◀──────────────────┘
                       (Pending claim)         Admin may redraw / extend deadline
```

### 5.3 Manual draw / redraw
```
Raffle > Month > "Run draw"
  -> adminPreviewDraw(month)  (no writes; shows pool + candidate)
  -> admin confirms
  -> adminRunDraw(month, {redraw?, reason})
       existing winner and not redraw -> reject
       write raffle_winners, push winner, write admin_audit
  -> UI refreshes winner card
```

### 5.4 Account deletion request by email
```
Support email arrives -> Players > search email
  -> verify it matches the registered address
  -> "Delete account" -> type uid to confirm
  -> adminDeleteUser(uid) -> deleteAccountData() -> audit entry
  -> reply to the player
```

## 6. New callable functions

| Function | Purpose |
|---|---|
| `adminGetDashboard` | counts and warnings |
| `adminListPrizes`, `adminSetPrize` | CRUD `raffle_config` |
| `adminListEntrants(month)` | entrants with stats |
| `adminListWinners(filter)`, `adminUpdateWinner(id, patch)` | status, notes, deadline |
| `adminPreviewDraw`, `adminRunDraw` | manual / redraw |
| `adminSearchUsers`, `adminGetUser(uid)` | support lookup |
| `adminSetUserDisabled`, `adminDeleteUser` | moderation, deletions |
| `adminSendPush` (phase 2) | broadcast |
| `adminListAudit` | audit log |

All: `requireAdmin` first, validate input, write `admin_audit`, return plain JSON. Unit tests with the existing `node --test` setup in `functions/test`.

## 7. Risks and decisions to confirm

1. Is delivery tracking inside the panel enough, or does the operator need address collection (a privacy-policy change)?
2. Prize draw legal rules: redraw policy and disqualification reasons must match the published official rules.
3. One admin, or several roles?
4. Separate Firebase project for admin hosting, or the same?

## 8. Prompt to give Claude Code

```
You are building the admin panel for Lucky Wings, in this repository (Flutter game + Firebase project lucky-wings-1535f). Read ADMIN_PANEL_PLAN.md first and follow it. Do not touch the Flutter app except where stated.

Rules
- Backend: add callable Cloud Functions in functions/ (v1 style, matching functions/index.js). Create functions/admin.js and export from index.js. Every function starts with requireAdmin(context): context.auth?.token?.admin === true, else HttpsError("permission-denied"). Validate all inputs. Write an admin_audit document for every mutating action. Reuse deleteAccountData from functions/account.js.
- firestore.rules stay locked: no client write paths for admins. Add a deny-all rule for admin_audit.
- Frontend: admin_panel/ with React + Vite + TypeScript + Tailwind, TanStack Table. Firebase Auth email/password with MFA; after sign-in read the admin claim and refuse access without it. All data via httpsCallable only. Add a Firebase Hosting target "admin" in firebase.json (do not touch the existing hosting config) with CSP, X-Frame-Options DENY, nosniff.
- scripts/set-admin.js: sets the admin claim for an email using a service account JSON passed by path (never committed).
- Tests: node --test for every admin function, including the permission-denied case, redraw rules, and that adminRunDraw refuses a second winner for the same month.

Do it in this order, committing after each step on a new branch admin-panel (no Co-Authored-By lines):
1. Upgrade functions runtime/SDK; make sure existing tests pass.
2. requireAdmin, audit helper, set-admin script, tests.
3. adminGetDashboard, prize functions (+ UI: login, dashboard, prizes).
4. Winners and draw functions (+ UI: raffle month view, winners list/detail, preview and run draw, redraw with reason). Add raffle_winners fields deliveryStatus, deliveryNote, contactedAt, deliveredAt, disqualified, disqualifiedReason.
5. Players: search, detail, disable, delete (+ UI), audit log view.
6. Emulator run-through of the flows in section 5, then summarise what is deployed and what is not.

Do not deploy to production, change the Flutter app, or delete data without asking me first. Ask before any decision listed in section 7.
```

## 9. Build order summary

Phase 0 (1–2 days) → Phase 1 (about 1–2 weeks) → Phase 2 as needed.
