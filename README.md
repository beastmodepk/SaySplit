# Word Games 🎲

**Two daily word games in one app.**

> **Word Games** — two daily word games in one app. **Word Trio**:
> guess the five-letter word — three new words a day (Easy, Medium,
> Hard). **Group Four**: sort sixteen words into four groups of four.
> Replay past days, sign in to keep your history.

This app lives in the shell of a retired app Parthey replaced on
2026-11-26. He will rename the repo / app himself later; until then the
project, scheme, target and bundle ID keep their technical names
(`SaySplit.xcodeproj`, scheme `SaySplit`, `com.parthey.saysplit`) — those
names are plumbing only and say nothing about what the app does.

## The games

### Word Trio — five letters, 3 words a day, not one
- Every day has **three words: Easy, Medium and Hard**, each with its own
  board, 6 guesses, 5-letter grid and on-screen keyboard
  (green / yellow / gray, with correct duplicate-letter handling).
- Win/lose state with the answer revealed on a loss, plus per-difficulty
  stats and streaks.

### Group Four — daily grouping
- 16 words, **4 groups of 4**, each group with a category name and a
  difficulty colour (yellow / green / blue / purple).
- Select 4 → Submit; Shuffle and Deselect included; "One away!" hint;
  4 mistakes allowed; solved groups lock in; a loss reveals the groups.

### Date pager — replay past days
- A pager at the top of the app shows the selected date in full, e.g.
  **"Thursday, November 26, 2026"**.
- **‹** goes back to yesterday, the day before, and earlier; **›** moves
  forward again but is disabled on today (no future puzzles); a **Today**
  shortcut appears on past dates.
- Each date has its own puzzles and its own saved progress.

### How the daily puzzles are chosen
Deterministic by date, on-device: the Word Trio word for a difficulty
is picked from that difficulty's answer bank by the day number (days
since 1970 × 31 + a per-difficulty offset, modulo the bank size —
300 Easy / 300 Medium / 200 Hard answers, all drawn from a 14,896-word
guess dictionary, so ordinary words like EARTH and TREAD always
validate). The Group Four board is the day number modulo the 14
built-in puzzles.
Same date → same puzzles, on every device, with no server.

## Sign in & history (optional)

Playing never requires an account — signed-out play is stored as "guest".

- **Sign in with Apple — live.** Native AuthenticationServices flow from
  the Account tab. The Apple user ID (and name/email, which Apple sends
  only on first authorization) is stored on-device; stats, per-date
  progress and history are then keyed by that account, and the Account
  tab lists that account's finished games (date, game, result).
- **Continue with Google (Gmail) — coming soon.** Shown in the UI but
  gated on a Google Cloud OAuth client ID for this app, which does not
  exist yet. No SDK is linked and no credentials are invented; tapping
  it explains the pending setup.
- **Continue with Email — coming soon**, same treatment (no auth
  backend configured yet).
- **Sign out** any time; guest play keeps working.

## Reminders (local notifications, opt-in)

- **OFF by default — both of them.** On a fresh install no reminder
  toggle is on, nothing is scheduled, and notification permission is
  never requested until you deliberately turn a toggle on.
- Just two toggles in the Account tab's **Reminders** section — one per
  game: **Word Trio** and **Group Four**. The Word Trio toggle covers
  all three words (Easy / Medium / Hard) together: its reminder names
  whichever levels you still have unfinished that day.
- Enabled reminders fire **3 times a day — 9:00 AM, 1:00 PM, 7:00 PM**
  local — and only for games you haven't finished. Finishing a game
  cancels its remaining reminders for that day, and the schedule re-syncs
  whenever the app becomes active (rolling 7-day window, on-device only,
  no server).

## Test access (demo mode — no login)

**TestFlight Test Information (copy-ready):**
> No account needed — open app, the Word Trio tab has 3 daily words
> Easy/Medium/Hard, the Group Four tab is the grouping game. Use the date
> pager at the top to replay yesterday or earlier days. Optional:
> Account tab → Sign in with Apple to keep history under your account
> (Google/Email sign-in not configured yet).

**What to Test (copy-ready):**
> 1) Word Trio tab: play today's Easy, Medium and Hard words (6 guesses
> each). 2) Tap ‹ at the top to play yesterday's words and Group Four
> board; check the › arrow is greyed out on today and a "Today" shortcut
> appears on past days. 3) Group Four tab: select 4 words and Submit —
> try Shuffle/Deselect and the "One away!" hint. 4) Account tab: play as
> guest, then Sign in with Apple and confirm your finished games appear
> under Your history; Sign out and back in. Google/Email buttons are
> placeholders that explain their pending setup — expected.
> 5) Account tab → Reminders: confirm both toggles (Word Trio, Group
> Four) start OFF. Turn Word Trio on (permission is asked only now),
> leave at least one of today's words unfinished, and check a reminder
> arrives at the next of 9:00 AM / 1:00 PM / 7:00 PM naming the
> unfinished levels; finish all three words and confirm its later
> reminders stop. Same check for Group Four.

## App Store description (copy-ready)

> **Word Games — Word Trio (3 words a day) + Group Four (daily grouping)**
>
> Why stop at one word a day? Word Trio gives you THREE new five-letter
> words to guess every day — Easy, Medium and Hard — each with six
> guesses, a colour-coded keyboard and streaks to chase. Then switch
> tabs for Group Four: sixteen words, four hidden groups of four,
> four mistakes.
>
> Missed a day? The date pager at the top lets you go back and play
> yesterday's — or any earlier day's — puzzles, each with its own saved
> progress. Sign in with Apple (optional — never required to play) to
> keep your stats and history under your account.
>
> • Word Trio: 3 five-letter words daily — Easy, Medium, Hard
> • Group Four: daily grouping puzzle (16 words, 4 groups of 4)
> • Replay any past day with the date pager
> • Stats, streaks and per-account history
> • Optional per-game reminders (off by default), 3× a day
> • No account, no ads, no server — everything on-device

## Build & run

- Open `SaySplit.xcodeproj` (technical name, see top) in Xcode 26,
  scheme `SaySplit`, run on an iOS 17+ simulator or device.
- CI: `.github/workflows/build.yml` (unsigned build + unit tests on
  macos-26) and `.github/workflows/release.yml` (signed archive →
  TestFlight) run on push to `main`. See `docs/PUBLISHING.md`.
- **Compile status:** structurally validated on Linux
  (`validation/validate_structure.py`, 22/22); the real compile and
  tests run in CI.

## Project layout

```
SaySplit/
  SaySplitApp.swift         @main entry (name kept); owns AuthManager
  ContentView.swift         date pager + TabView: Word Trio / Group Four / Account
  WordGame.swift            word logic, evaluator, daily provider, word lists,
                            stats, GameCalendar (date pager helpers)
  WordleView.swift          Word Trio UI: grid + keyboard, per-date progress
  ConnectionsGame.swift     Group Four puzzles, logic, UI, per-date progress
  AuthManager.swift         AuthProvider protocol (Apple live, Google/Email
                            stubbed), AuthManager, per-account GameHistory
  AccountView.swift         sign-in UI, signed-in state, history, Reminders
                            settings, About
  Reminders.swift           per-game reminder toggles — Word Trio / Group
                            Four (both OFF by default), 9AM/1PM/7PM planner,
                            local-notification scheduler
  SaySplit.entitlements     Sign in with Apple entitlement
  Info.plist / Assets       app info + icon (names kept)
SaySplitTests/              evaluator, daily/date, progress, auth/history tests
docs/PUBLISHING.md          TestFlight pipeline + owner gates
validation/                 structural validation + logic trace
.github/workflows/          build.yml + release.yml (names kept)
```
