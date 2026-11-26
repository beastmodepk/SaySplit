# Word Games — logic trace / cross-check

**Purpose.** The game logic is deterministic and on-device; this trace
records the exact rules the Swift code implements, cross-checked by
transcribing the evaluator and data into a script (2026-11-26).

## Word evaluation (WordEvaluator.evaluate)
Exact matches consume answer letters first; "present" matches then
consume from what remains — duplicates never over-count.
- SPEED vs ERASE → present, absent, present, present, absent ✓
- EERIE vs SPEED → exactly 2 present/correct (the two E's in SPEED) ✓

## Daily selection (DailyWordProvider / ConnectionsPuzzles)
- Day number = days since 1970. Word Trio index =
  (day × 31 + difficulty offset 0/101/202) mod list size
  (Easy 40, Medium 40, Hard 36 — all verified 5 letters, unique).
- Group Four puzzle = day mod 14; all 14 puzzles verified:
  4 groups × 4 words, 16 unique words, levels 0–3.
- Same date → same puzzles everywhere; the date pager simply passes a
  different date to the same functions. Progress is stored per date
  (and per account, see AuthManager.swift).

## History
Finished boards record one GameHistory entry per date + game
(Word Trio Easy/Medium/Hard, Group Four), namespaced by the signed-in
account ID or "guest".
