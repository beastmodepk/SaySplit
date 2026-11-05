#!/usr/bin/env python3
"""Cross-check for the SaySplit iOS port.

Runs the ORIGINAL web version's Python logic (~/workspace/voice-split-app)
against the exact cases the Swift unit tests assert, and prints the
expected values those Swift tests must produce. The Swift code in
SaySplit/CoreLogic.swift, CommandParser.swift and SplitwiseCSV.swift was
written as a line-for-line port of this Python, and validation/TRACE.md
walks each case through the Swift code path by hand.

What this proves: the logic DESIGN and expected values match the
already-passing web implementation (its own suite passed 12/12 on
2026-11-05).
What this does NOT prove: that the Swift code compiles or that the
Swift tests pass — there is no Swift toolchain on this machine.
Swift tests are written but NOT run; first true compile/test happens
on Parthey's Mac or in the GitHub Actions macOS workflow once pushed.
"""
import os
import sys

WEB_APP = os.path.expanduser("~/workspace/voice-split-app/app")
sys.path.insert(0, WEB_APP)
import core  # noqa: E402
import parser as P  # noqa: E402

MEMBERS = ["Parthey", "Shannon", "Het", "Maya"]
failures = []


def check(label, actual, expected):
    ok = actual == expected
    print(f"{'PASS' if ok else 'FAIL'}  {label}: {actual!r}" +
          ("" if ok else f"  (expected {expected!r})"))
    if not ok:
        failures.append(label)


# ---- parser phrases (the Swift ParserTests assert the same values) ----
r = P.parse_command("Dinner, eighty dollars, split four ways", MEMBERS, "Parthey")
check("dinner.description", r["description"], "Dinner")
check("dinner.amount_cents", r["amount_cents"], 8000)
check("dinner.split_count", r["split_count"], 4)
check("dinner.split", r["split_member_names"], MEMBERS)

r = P.parse_command("Taxi $24 paid by Shannon split between Parthey and Shannon",
                    MEMBERS, "Parthey")
check("taxi.description", r["description"], "Taxi")
check("taxi.amount_cents", r["amount_cents"], 2400)
check("taxi.payer", r["payer_name"], "Shannon")
check("taxi.split", r["split_member_names"], ["Parthey", "Shannon"])

r = P.parse_command("Groceries 120 dollars split equally", MEMBERS, "Parthey")
check("groceries.description", r["description"], "Groceries")
check("groceries.amount_cents", r["amount_cents"], 12000)
check("groceries.split_mode", r["split_mode"], "equal")
check("groceries.split", r["split_member_names"], MEMBERS)

r = P.parse_command("I paid 60 for pizza split with Shannon", MEMBERS, "Parthey")
check("pizza.description", r["description"], "Pizza")
check("pizza.amount_cents", r["amount_cents"], 6000)
check("pizza.payer", r["payer_name"], "Parthey")
check("pizza.split", r["split_member_names"], ["Parthey", "Shannon"])

check("words.eighty", P.words_to_number(["eighty"]), 80)
check("words.125", P.words_to_number(["one", "hundred", "and", "twenty", "five"]), 125)
check("words.2300", P.words_to_number(["two", "thousand", "three", "hundred"]), 2300)

# ---- split math ----
s = core.distribute(10000, [1, 2, 3])
check("equal.100by3", [s[1], s[2], s[3]], [3334, 3333, 3333])
ok = core.compute_splits(5000, "exact", [], exact={1: 3000, 2: 2000})
check("exact.ok", [ok[1], ok[2]], [3000, 2000])
try:
    core.compute_splits(5000, "exact", [], exact={1: 3000, 2: 1000})
    check("exact.bad.rejected", "no error", "ValueError")
except ValueError as e:
    check("exact.bad.rejected", "must match" in str(e), True)
pct = core.compute_splits(9000, "shares", [], shares={1: 50, 2: 25, 3: 25})
check("percent.90", [pct[1], pct[2], pct[3]], [4500, 2250, 2250])

# ---- receipt (Swift test asserts exact 3380/2080) ----
items = [{"name": "Pancakes", "price_cents": 2000, "assignees": [1]},
         {"name": "Coffee", "price_cents": 1000, "assignees": [2]},
         {"name": "Fruit bowl (shared)", "price_cents": 1200, "assignees": [1, 2]}]
per, subtotal, total = core.receipt_splits(items, 420, 840)
check("receipt.subtotal", subtotal, 4200)
check("receipt.total", total, 5460)
check("receipt.member1", per[1], 3380)
check("receipt.member2", per[2], 2080)

# ---- CSV ----
SAMPLE = """Date,Description,Category,Cost,Currency,Parthey,Shannon,Het
2026-10-01,Dinner,Food,80.00,USD,40.00,-40.00,0.00
2026-10-02,Taxi,Transport,24.00,USD,-12.00,12.00,0.00
2026-10-03,Broken row,Food,not-a-number,USD,0.00,0.00,0.00
2026-10-04,Groceries,Food,90.00,USD,60.00,-30.00,-30.00
"""
rows, errors, members = core.parse_splitwise_csv(SAMPLE)
check("csv.members", members, ["Parthey", "Shannon", "Het"])
check("csv.rows", len(rows), 3)
check("csv.errors", len(errors), 1)
check("csv.error.row4", "Row 4" in errors[0], True)
check("csv.dinner.payer", rows[0]["payer_name"], "Parthey")
check("csv.dinner.splits", rows[0]["splits"], {"Parthey": 4000, "Shannon": 4000})

print()
if failures:
    print(f"MIRROR CHECK FAILED: {len(failures)} case(s): {failures}")
    sys.exit(1)
print("MIRROR CHECK PASSED: all expected values match the web implementation.")
print("Reminder: this validates the logic design only — not Swift compilation.")
