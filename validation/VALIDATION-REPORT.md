# SaySplit iOS — validation report (2026-11-05)

**Compile status: structurally validated only — tests written but not run,
first true compile happens on Parthey's Mac (or in CI once pushed).**

Authoring machine is Linux: `swift`, `swiftc` and `xcodebuild` are all
absent (checked at the start of the build), so no Swift compilation or
test execution was possible here. The checks below are everything that
*can* be verified locally. Full output:
`validation/structural_validation_output.txt`,
script: `validation/validate_structure.py` (re-runnable).

## Structural checks — 22/22 passed

Project file (`SaySplit.xcodeproj/project.pbxproj`):

1. No conflict markers anywhere in the repo — PASS
2. **Every referenced object defined exactly once** (separate
   duplicate-definition check) — PASS: 53 definitions, 53 unique, 0 duplicates
3. No dangling references — PASS: 53 distinct IDs referenced, all defined
4. Balanced braces — PASS after a fix (see below): 66 `{` / 66 `}`
5. Balanced parentheses — PASS: 35 / 35
6. Group listings hold references only (no second inline definitions)
   — PASS: 47 child entries, all pure references
7. Every referenced file exists on disk — PASS: 16 file references, 0 missing

Swift sources:

8. Swift file set in project == file set on disk — PASS: 12 files both ways
9. Brace/paren/bracket balance in every Swift file — PASS

Plists / catalogs / scheme:

10. Info.plist parses (plistlib) — PASS, 15 keys
11. `NSMicrophoneUsageDescription` present — PASS
12. `NSSpeechRecognitionUsageDescription` present — PASS
13. All 3 asset-catalog `Contents.json` files parse as JSON — PASS
14. Scheme XML parses; both BlueprintIdentifiers (app + test targets)
    are defined in the pbxproj — PASS
15. Scheme contains a Testables entry for SaySplitTests — PASS

CI / build settings:

16. Workflow uses a macOS runner, `xcodebuild build`, and
    `CODE_SIGNING_ALLOWED=NO` — PASS (workflow itself NOT run)
17–22. Build settings present: iOS deployment target 17.0, bundle id
    `com.parthey.saysplit`, `INFOPLIST_FILE = SaySplit/Info.plist`,
    `GENERATE_INFOPLIST_FILE = NO`, iPhone-only device family,
    unit-test `TEST_HOST` — all PASS

## Fix made during validation

The first structural run failed the brace-balance check (66 `{` vs
67 `}`): the generated PBXProject attributes block had one surplus
closing brace. It was removed and the full suite re-run green. This is
exactly the defect class the duplicate/balance checks exist to catch in
hand-authored project files.

## Logic cross-check (design-level, not compilation)

- `validation/mirror_check.py` runs the web version's passing Python
  logic against every value the Swift tests assert: **32/32 PASS**
  (output in `validation/mirror_check_output.txt`).
- `validation/TRACE.md` hand-traces each Swift test case (4 parser
  phrases, number-words, equal/exact/percent splits, receipt tax/tip
  to the exact cent, balances summing to zero + simplification +
  settle-up, CSV import "Row 4" error + export round trip) through the
  Swift code paths.
- The web Python suite itself was re-run during this build:
  12 tests, OK.

## Not verified

- Swift compilation (no toolchain) — first build is on Parthey's Mac
  or the macOS CI workflow after a push (workflow authored, NOT run).
- Swift unit tests — written, mirroring the Python suite, NOT run.
- Speech recognition / microphone behaviour on a real device.
- PhotosUI receipt-photo picking with a real photo (standard API usage,
  untested on device).
