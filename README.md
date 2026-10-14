# Lucky Wings

A Flappy-style Flutter game with a daily 5-minute play qualifier and a monthly prize raffle.

- Package: `com.robinson.luckywings` (Dart package `flip_flop`) · Firebase project: `lucky-wings-1535f`
- Android release: `flutter build apk --release` (signing is read from `android/key.properties`; without it the APK is left unsigned). R8 rules: `android/app/proguard-rules.pro`.

## How it works
- **Play:** every game banks active seconds locally first (local-first sync); 5 active minutes in a day earns that day's raffle entry, and each further 5 minutes fills the oldest missed day.
- **Server is the authority:** the `verifyQualification` Cloud Function re-checks heartbeats, wall-clock time, day key and replays before writing `monthly_records`.
- **Raffle:** on the 1st of each month `monthlyRaffleDraw` picks a winner weighted by entries and writes `raffle_winners` (`claimed:false`, 7-day deadline) and pushes a notification. `expireUnclaimedWins` marks missed claims `expired`. Prize delivery is manual (outside the app).
- **Ads (AdMob):** banner, interstitial, rewarded, native, app-open. Rules are in `lib/ads/ad_policy.dart`. Test IDs are used until real ad unit IDs are put in `lib/ads/ad_config.dart`.

## Layout
- `lib/` — app (`auth`, `raffle`, `leaderboard`, `ads`, `anti_cheat`, `backend`, `notifications`, `setting`, `my_game`, `components`)
- `functions/` — Cloud Functions (`npm test` runs the mocked scheduled-function tests)
- `firestore.rules`, `firestore.indexes.json` — security rules and composite indexes
- `test/` — unit tests (`flutter test`)

## Common commands
```
flutter pub get
flutter analyze
flutter test
cd functions && npm test
firebase deploy --only firestore:indexes --project lucky-wings-1535f
```
