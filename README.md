# SaySplit for iPhone 📱

**"SaySplit" is a working title / placeholder — rename it whenever you like.**
A native iOS (SwiftUI) version of SaySplit, the voice-first
expense-splitting app first built as a local web prototype
(`~/workspace/voice-split-app/`). This is an original implementation —
nothing copied from the app in the Instagram reel that inspired it.

Say or type one sentence — *"Dinner, eighty dollars, split four ways"* —
check the parsed preview, confirm, and balances / who-pays-whom update
automatically. Everything is on-device: no account, no server, no
network calls.

## Compile status — read this first

**Structurally validated only — tests written but not run, first true compile happens on Parthey's Mac (or in CI once pushed).**

This project was hand-authored on a Linux machine, which has no Xcode
or Swift toolchain, so the code has never been compiled. What *was*
done here:

- The Xcode project file passed structural checks (every object defined
  exactly once, no dangling references, every referenced file on disk —
  see `validation/VALIDATION-REPORT.md` in the build notes / repo).
- The parser, split math, receipt allocation, balances, debt
  simplification and CSV logic were ported line-by-line from the web
  version's Python, whose tests pass 12/12, and cross-checked case by
  case (`validation/TRACE.md`, `validation/mirror_check.py` — 32/32
  expected values match).
- Swift unit tests mirroring the Python suite are in `SaySplitTests/`
  — **written but not run**.
- A GitHub Actions workflow (`.github/workflows/build.yml`) builds the
  app unsigned on a macOS runner. It has **not run yet** — it runs the
  first time this repo is pushed to GitHub.

So: expect the first Xcode build to be the real test. If it shows a red
error, send the first error back and it will be fixed from there.

## Get it on your iPhone (Mac + USB)

You need: your Mac, your iPhone, a USB/USB-C cable, and Xcode
(free from the Mac App Store).

1. **Copy the project to your Mac** — unzip `voice-split-app-ios.zip`
   (or clone this repo) and open the folder.
2. **Open `SaySplit.xcodeproj`** in Xcode (double-click it).
3. **Sign in with your Apple ID in Xcode** (only if you haven't):
   Xcode → Settings → Accounts → **+** → sign in. A free Apple ID is
   fine — no paid developer account needed.
4. **Select your team:** click the blue **SaySplit** project icon at the
   top of the left sidebar → select the **SaySplit** target → tab
   **Signing & Capabilities** → tick **Automatically manage signing** →
   set **Team** to your name *(Personal Team)*.
   - If Xcode complains the bundle identifier is taken, change
     `com.parthey.saysplit` to anything unique, e.g.
     `com.parthey.saysplit2`.
5. **Plug in your iPhone** with the cable and unlock it. Tap **Trust**
   on the phone if it asks. If the phone asks you to enable Developer
   Mode (Settings → Privacy & Security → Developer Mode), turn it on
   and let it restart.
6. **Pick your iPhone** in the destination picker at the top of the
   Xcode window (next to the ▶ button) — choose your physical phone,
   not a simulator.
7. **Press ▶ Run.** Xcode builds, installs, and launches SaySplit.
   - If the phone says "Untrusted Developer": on the iPhone go to
     Settings → General → VPN & Device Management → tap your Apple ID
     → **Trust**, then open SaySplit again.
8. **First mic use:** tap the mic button and allow both the microphone
   and speech-recognition prompts. If you decline, typing the same
   commands always works.

### The 7-day free-signing expiry ⏰

With a free/personal team, Apple signs the app for **7 days**. After
that the app will refuse to open ("no longer available"). Nothing is
wrong and **your data is intact** — just plug the phone back in and
press ▶ Run in Xcode again; it re-signs and relaunches with everything
still there. (A paid Apple Developer account extends this to a year,
but is not needed to use the app.)

## Using it

1. Create a group (+, top right), open it, add members.
2. In the command box, tap the mic and speak — or type:
   - `Dinner, eighty dollars, split four ways`
   - `Taxi $24 paid by Shannon split between Parthey and Shannon`
   - `Groceries 120 dollars split equally`
   - `I paid 60 for pizza split with Shannon`
   Tap **Parse & preview**, edit anything, **Confirm & save**.
   *Nothing is ever saved straight from a parse.*
3. **Add manually** for exact-dollar or percentage splits — an exact
   split that doesn't add up is rejected with both totals shown.
4. **Receipt mode:** attach a photo for reference, enter items, tick
   who had each, add tax + tip — totals reconcile to the cent.
5. **Balances & settle up:** balances always sum to $0.00; the
   simplified list says who pays whom; recording a payment updates it.
6. **Splitwise:** home screen ⋯ menu → **Import Splitwise CSV** (pick
   the export file; preview shows good rows, total, and every bad row
   by number before you confirm). Inside a group, **Export Splitwise
   CSV** shares the group back out in the same format.
7. **Load demo group** (home ⋯ menu, or the empty-state button)
   creates demo data only when tapped.

## Honest limits

- 🎤 Voice uses Apple's on-device Speech framework
  (`SFSpeechRecognizer`). Depending on the device/locale, recognition
  may use Apple servers per Apple's own policy — this app sends
  nothing anywhere itself. Denied permission degrades gracefully to
  typing, with a clear message.
- The parser is local and rule-based — **not an AI/LLM**, no API keys.
  Odd phrasing may misfire; that's exactly why the editable preview
  step exists and parses never auto-save.
- 🧾 **No OCR.** Receipt photos are preview-only reference; items are
  typed in by hand, and the UI says so plainly.
- 💸 No real money moves — no Venmo/bank integration. A "settle-up"
  is a bookkeeping record inside the app only.
- 📱 Single-device v1: data lives in a JSON file in the app's
  Application Support folder (plus receipt photos alongside it).
  No iCloud sync, no sharing a group with other people's phones yet.
- iOS 17 or later, iPhone only. SwiftUI, no third-party dependencies.

## Project layout

```
SaySplit.xcodeproj          hand-authored Xcode project (app + test targets)
SaySplit/
  SaySplitApp.swift         @main entry
  Models.swift              Codable model (integer cents everywhere)
  CoreLogic.swift           split math, receipts, balances, debt simplification
  CommandParser.swift       the rule-based voice/text command parser
  SplitwiseCSV.swift        Splitwise import/export (per-row error reporting)
  Store.swift               on-device JSON store, demo data, receipt photos
  SpeechRecognizer.swift    SFSpeechRecognizer + AVAudioEngine mic capture
  ContentView.swift         group list, quick-start, import entry point
  GroupDetailView.swift     command box, balances, activity, members, export
  ExpenseEntryViews.swift   parse preview, manual entry, receipt mode, settle-up
  ImportExportViews.swift   import preview sheet
  Info.plist                incl. mic + speech-recognition usage descriptions
  Assets.xcassets           app icon slots + accent color (icon art: add your own)
SaySplitTests/              XCTest port of the web test suite (not yet run)
.github/workflows/build.yml macOS CI: xcodebuild unsigned (not yet run)
validation/                 mirror check + hand trace of the ported logic
```

## Tests (on your Mac)

In Xcode: **Product → Test** (⌘U). The suite mirrors the web version's
12 tests: the 4 parser phrases, number-words, equal/exact/percent
splits, receipt tax/tip reconciliation to the cent, balances summing
to zero with the greedy simplification and a settle-up, and Splitwise
CSV import (3 rows OK, "Row 4" reported) + export round-trip.
