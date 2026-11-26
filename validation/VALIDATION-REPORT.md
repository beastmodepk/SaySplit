# Word Games — validation report (2026-11-26)

**Compile status: structurally validated only on Linux — the real
compile and unit tests run in GitHub Actions (macOS-26, Xcode 26).**

- `validation/validate_structure.py`: 22/22 checks PASS (pbxproj
  integrity, file references, Swift brace balance, Info.plist, scheme,
  CI workflow, bundle ID `com.parthey.saysplit` — technical name kept).
- Logic cross-checks (script simulation of the Swift code): word
  evaluator incl. duplicate-letter cases, word-list well-formedness,
  daily-word validity over 60 days × 3 difficulties, and all 14
  Connections puzzles (16 unique words, levels 0–3) — all PASS.
  See `validation/TRACE.md`.
- Known prior CI failure (push dc706ab, exit 65) was traced to three
  WordleView.swift errors (ShapeStyle/Color ternary mix + a keyboard
  Button the compiler could not type-check); fixed in commit 78d0d1a.
