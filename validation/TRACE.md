# SaySplit iOS — logic trace / cross-check

**Purpose.** The Swift parser/split/balance/CSV code is a port of the web
version's Python (`app/parser.py`, `app/core.py`), whose own test suite
passes 12/12 (re-run 2026-11-05: `Ran 12 tests … OK`). This document
traces each Swift unit-test case through the Swift code by hand and
compares the result to the Python expected value, which
`validation/mirror_check.py` also asserts programmatically
(see `mirror_check_output.txt` — 32/32 PASS).

**Scope limit, stated plainly:** this validates the logic *design* and
the expected values. It does **not** prove the Swift code compiles or
that the Swift tests pass — there is no Swift toolchain on the authoring
machine. The Swift tests are **written but not run**.

## Parser cases

| Case | Swift code path | Traced Swift result | Python expected |
|---|---|---|---|
| "Dinner, eighty dollars, split four ways" | `findWordAmount` walks back from "dollars" over number-words → eighty = 8000¢; `findSplitCount` "four" → 4 → first 4 members; description: word-amount span and `\bsplit\b.*$` removed, whitespace collapsed | Dinner / 8000¢ / count 4 / all 4 members | Dinner / 8000¢ / count 4 / all 4 ✓ |
| "Taxi $24 paid by Shannon split between Parthey and Shannon" | `\$` amount → 2400¢; `paid by ([a-z]+)` → matchMember → Shannon; no count, so `split between (.+)$` split on ","/" and " → both members | Taxi / 2400¢ / Shannon / [Parthey, Shannon] | Taxi / 2400¢ / Shannon / [Parthey, Shannon] ✓ |
| "Groceries 120 dollars split equally" | digits-before-"dollars" amount → 12000¢; no names found → all members + warning; "equally" → mode equal | Groceries / 12000¢ / equal / all 4 | Groceries / 12000¢ / equal / all 4 ✓ |
| "I paid 60 for pizza split with Shannon" | `(paid\|…)\s+\$?(\d+)` → 6000¢; `\bi\s+paid\b` → current user Parthey; `split with` → [payer, Shannon]; "I paid 60 for" stripped from description | Pizza / 6000¢ / Parthey / [Parthey, Shannon] | Pizza / 6000¢ / Parthey / [Parthey, Shannon] ✓ |
| wordsToNumber | unit/tens/hundred/thousand accumulation, identical to Python | eighty=80; one-hundred-and-twenty-five=125; two-thousand-three-hundred=2300 | 80 / 125 / 2300 ✓ |

## Split math

| Case | Traced Swift result | Python expected |
|---|---|---|
| distribute 10000¢ over 3 | base 3333, remainder 1 → first member +1 | {3334, 3333, 3333} ✓ |
| exact 5000¢ = 3000+2000 | sums match → accepted | accepted ✓ |
| exact 5000¢ vs 3000+1000 | sum 4000 ≠ 5000 → error "Exact split adds up to $40.00, but the expense is $50.00. They must match exactly." (contains "must match") | rejected with "must match" ✓ |
| shares $90 at 50/25/25 | proportional raw values are whole cents, leftover 0 | {4500, 2250, 2250} ✓ |
| receipt: $20 solo + $10 solo + $12 shared, tax $4.20, tip $8.40 | item subtotals 2600/1600; tax splits exactly 260/160; tip exactly 520/320 | subtotal 4200, total 5460, per-member {3380, 2080} ✓ (mirror check asserts these exact cents) |

## Balances & simplification

Python run (2026-11-05, from the web suite): Asha pays $90 split 3 ways,
Ben pays $30 split Ben+Cara → balances {Asha +6000, Ben −1500, Cara −4500},
sum 0; simplified transfers Cara→Asha 4500 and Ben→Asha 1500; after Cara
settles $45 → Cara 0, sum still 0.

Swift trace of `BalanceMath.balances` / `simplifyDebts` follows the same
arithmetic step for step (distribute 9000/3 = 3000 each; 3000/2 = 1500
each; debtors sorted most-negative first → Cara pays first). The Swift
test asserts the same balances, the same 2 transfers (as a set), Cara = 0
after the settle-up, and sum = 0 at both points. ✓

## Splitwise CSV

Sample CSV identical to the Python suite (header + 4 data rows, row 4's
cost is `not-a-number`):

- Swift `Money.dollarsToCents` throws `could not convert string to
  float: 'not-a-number'` → error recorded as **"Row 4: …"** ✓
  (line numbering: header is line 1, so the third data row is row 4 —
  same convention as Python's `enumerate(reader, start=2)`.)
- Rows parsed: 3. Dinner: nets {Parthey +4000, Shannon −4000} → payer
  Parthey; owed 4000; remaining 4000 allocated to the sole positive-net
  member → splits {Parthey 4000, Shannon 4000} ✓
- Export round trip: Swift export writes the same columns (member
  columns sorted by name; Python sorts by member id — column *order*
  differs, values do not, and re-parsing is order-insensitive) →
  re-parse yields 3 rows, 0 errors ✓ (asserted in the Swift test).

## Known port divergences (deliberate, documented)

1. Web member-removal check covers payer/split usage; the iOS store
   additionally refuses removal when the member appears in a settle-up
   (the nested iOS model would otherwise orphan the record).
2. Web CSV export orders member columns by member id; iOS orders by
   member name. Import is column-name-based, so round-trips are exact.
3. iOS dates persist as ISO-8601 in JSON instead of SQLite text rows;
   CSV date handling uses the same `yyyy-MM-dd` format both ways.
