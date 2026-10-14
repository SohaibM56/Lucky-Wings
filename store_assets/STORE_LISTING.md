# Lucky Wings — Google Play listing (draft)

Graphics are in `store_assets/out/` (regenerate with `python store_assets/make_assets.py`).
Placeholders in `{{BRACES}}` need the client's details.

## Main store listing

| Field | Value | Limit |
|---|---|---|
| App name | `Lucky Wings: Fly & Win` | 30 chars |
| Short description | `Fly 5 minutes a day, earn raffle entries and win a monthly prize.` | 80 chars (65 used) |
| Category | Games → Casual (alternative: Arcade) | |
| Tags | Casual, Arcade, One-tap, Raffle | |
| Contact email | {{CONTACT_EMAIL}} | required |
| Website | https://lucky-wings-1535f.web.app (after hosting is deployed) | optional |
| Privacy policy URL | https://lucky-wings-1535f.web.app/privacy-policy (after hosting is deployed) | required |

### Full description (≤ 4000 chars)

```
Tap, flap and fly your way through the crates — and turn your daily play into a chance to win.

LUCKY WINGS IN ONE MINUTE
• Play at least 5 minutes a day to earn that day's raffle entry.
• Missed a day? Keep playing: every extra 5 minutes fills the oldest missed day, so you can catch up any time this month.
• On the 1st of every month one winner is drawn from all entries. More entries = better odds.
• Free to play. No purchase is needed to enter or to win.

A GAME YOU CAN PICK UP ANYWHERE
• Simple one-tap controls, quick rounds, satisfying near-misses.
• Crates start still, then begin to move and squeeze as your score grows.
• Collect coins and fruit and use them to unlock birds and maps.
• Works offline: your progress is saved and synced when you're back online.

COMPETE
• Monthly leaderboard so you can see how you rank.
• "My best" shows your top runs and how long each one lasted.
• Daily calendar shows qualified, missed and catch-up days at a glance.

FAIR PLAY
• Entries are verified on our servers, so every entry comes from real play.

GOOD TO KNOW
• Reminders for missed days and draw day (you can turn them off any time).
• Play as a guest, or create an account to keep your progress and be reachable if you win.
• Contains ads. Watching a rewarded ad is always optional.
• Prize draw open to adults of legal age in eligible countries: see the official rules at {{RULES_URL}}. {{COMPANY_NAME}} is the sponsor of the draw; the prize is not sponsored by or associated with Google or Apple.
```

> Claims to keep honest: do not promise a prize amount or odds, and keep the
> "not sponsored by Google/Apple" line (Google requires it for prize draws).

## Graphics checklist

| Asset | File | Spec |
|---|---|---|
| App icon | `out/icon_512.png` | 512×512, PNG |
| Feature graphic | `out/feature_graphic_1024x500.png` | 1024×500 |
| Phone screenshots (6) | `out/phone_01…06_*.png` | 1080×2160 (2:1 maximum), min 2 / max 8 |
| 7" / 10" tablet screenshots | not generated | optional |

Screenshots show a test account and Google's *test ad* banner is cropped out. Retake them from the final release build if the UI changes.

## Content rating (IARC questionnaire) — guidance, answer honestly yourself
- Violence / sexual content / bad language / drugs: none.
- **Gambling / prizes:** the app runs a free-to-enter monthly prize draw with a real prize. There is no payment, no real-money wagering and no purchases. Answer the contest/sweepstakes questions truthfully; this may raise the rating above "3+". Confirm with the client's legal adviser.
- User-generated content: display names are visible to other players on the leaderboard.
- Shares location: no. Digital purchases: none.

## Target audience & policies
- Target age group: **18+ recommended** (prize draw for adults). If younger ages are selected, Google's Families policy applies and AdMob must be configured child-directed, which conflicts with the raffle.
- Ads: yes (AdMob). News app: no. Government app: no. Health app: no.
- Account deletion URL (Play Console → App content): https://lucky-wings-1535f.web.app/delete-account

## Data safety form (answers matching the app)

**Data collected**

| Data type | Collected | Shared | Purpose | Optional |
|---|---|---|---|---|
| Email address | Yes (accounts, Google sign-in) | No | Account management, app functionality | Yes (guests need none) |
| Name (display name) | Yes | No (shown to other players on the leaderboard in-app) | Account management, app functionality | Yes |
| User IDs (Firebase UID) | Yes | No | App functionality, account management, fraud prevention | No |
| App interactions (scores, play time, raffle entries) | Yes | No | App functionality, fraud prevention | No |
| Device or other IDs (advertising ID; FCM push token) | Yes | **Yes — Google AdMob** (advertising ID) | Advertising, app functionality (notifications) | Ads: consent form in EEA/UK/CH |
| Crash logs / diagnostics | No (no crash-reporting SDK) | — | — | — |
| Location, contacts, photos, files, audio, health, financial info | No | — | — | — |

**Security practices:** data encrypted in transit — **Yes**; users can request data deletion — **Yes** (in-app: Account → Delete account; web: /delete-account). Independent security review: No. Follows Families policy: No.

> The AdMob row stays as "collected and shared" because the SDK collects the advertising ID. Re-check this form if SDKs are added (e.g. analytics or crash reporting).

## Release notes (first release)
```
First release of Lucky Wings: fly, play 5 minutes a day and earn raffle entries for the monthly prize draw.
```
