# Word Games (in the SaySplit shell) 🎲

This repo/app shell was formerly SaySplit. On 2026-11-26 Parthey ordered it
REPLACED by **Word Games** — the old expense-splitting UI is gone.
He will rename the repo / app himself later; bundle ID, project, scheme and
App Store record are intentionally unchanged for now:
`com.parthey.saysplit`, project `SaySplit.xcodeproj`, scheme `SaySplit`.

## The games

- **Wordle tab:** Instead of 1 word a day, **3 daily words — Easy, Medium, Hard**.
  Each difficulty has its own deterministic daily word (same all day), its own
  board, 6 guesses, 5-letter grid, on-screen keyboard (green/yellow/gray),
  correct duplicate-letter handling, win/lose + answer reveal, and simple local
  stats/streaks (UserDefaults). Daily-only — there is no Practice mode.
- **Connections tab:** 16 words, 4 groups of 4 with category names and
  yellow/green/blue/purple levels. Select 4, Submit / Deselect / Shuffle,
  4 mistakes allowed, correct groups lock in, win/lose states.
  Daily puzzle is deterministic by date from 14 embedded puzzles. Daily-only.

## Date navigation

At the top of the app, above both tabs, a date pager shows the selected
date in full — e.g. **"Thursday, November 26, 2026"**:
**‹** goes back to yesterday, the day before, and earlier; **›** moves
forward again but is disabled/greyed on today (no future puzzles), and a
**Today** shortcut appears whenever a past date is selected. Both games
show the puzzles *for the selected date* (Wordle Easy/Medium/Hard words and
the Connections board are seeded deterministically by date), and each date
keeps its own board/progress (UserDefaults, keyed by date).

## Test access (demo mode — no login)

**TestFlight Test Information (copy-ready):**
> No account needed — open app, Wordle tab has 3 daily words Easy/Medium/Hard, Connections tab is the grouping game.

No account, no server, no network calls. Everything is on-device.

## Compile status

**Structurally validated only on Linux — real compile happens in CI (macOS).**
See `validation/validate_structure.py`. GitHub Actions: Build (unsigned +
unit tests) and Release to TestFlight run on push to `main`.

## Project layout

```
SaySplit/
  SaySplitApp.swift         @main entry (name kept)
  ContentView.swift         TabView root: Wordle + Connections
  WordGame.swift            word logic, evaluator, daily provider, word lists, stats
  WordleView.swift          Wordle UI: grid + keyboard
  ConnectionsGame.swift     Connections puzzles, logic and UI
  Info.plist / Assets       kept from shell (icon included)
SaySplitTests/              word evaluation + connections tests
.github/workflows/          build.yml + release.yml (TestFlight) — kept
```
