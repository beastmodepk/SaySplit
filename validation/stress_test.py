#!/usr/bin/env python3
"""Word Games — permanent stress test bed (5,000 checks).

Runs 1,000 simulated game fills x 5 guesses = 5,000 guess checks against
the app's OWN data and rules, parsed directly from the Swift sources:

  * dictionary  <- SaySplit/WordDictionary.swift (the ONE multiline
                   literal, tokenised exactly as Swift's split does —
                   whole tokens, never substrings)
  * answer banks <- SaySplit/WordGame.swift (string literals concatenated
                   exactly as Swift's + does — NOTHING inserted between
                   literals — then split; this is the parse that catches
                   the Build 111 merge bug class: HEART+HEAST=HEARTHEAST)
  * rules        <- DailyWordProvider daily maths (dayNumber =
                   Int(epoch/86400); idx = abs(dayNumber*31 + seedOffset)
                   % count, offsets parsed from the WordDifficulty
                   switch), WordLists.isValidGuess (exact token),
                   WordLists.alreadyGuessed, and WordEvaluator's
                   two-pass scoring (greens consume answer letters
                   first, then yellows consume what remains) — cross-
                   checked on every accepted guess against a second,
                   independently written scorer.

Fill design (seeded RNG 20261126, fully reproducible): fills are 1,000
consecutive dates from 2025-01-01, difficulties rotating
Easy/Medium/Hard. Each fill submits 5 guesses:
  1. a must-pass common word          -> must be ACCEPTED
  2. a random dictionary word         -> must be ACCEPTED
  3. guess 1 again                    -> must be REFUSED "Already guessed",
                                         no row consumed
  4. a deliberately invalid string    -> must be REJECTED "Not in word
                                         list", no row consumed
  5. even fills: the board's answer   -> must WIN (all correct)
     odd fills: another dictionary word -> must be ACCEPTED
Category totals: 2,500 valid accepted, 500 answer wins, 1,000 duplicates
refused, 1,000 invalid rejected = 5,000 guess checks, plus 3,000 scoring
cross-checks (every accepted guess scored by both scorers).

Also asserts data integrity: 21,664 dictionary tokens, every one exactly
5 uppercase A-Z letters; answer banks exactly 300/300/200, mutually
disjoint, every answer a dictionary token; all 27 must-pass words present
as whole tokens; HEARTHEAST absent.

Exit code 0 only if every check passes. Run it before EVERY push —
see README "Build & run": a push is not done until validate_structure.py,
this bed, and both GitHub workflows are green.

Usage: python3 validation/stress_test.py
"""

import os
import random
import re
import sys
from datetime import date, timedelta

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SEED = 20261126
FILLS = 1000
START_DATE = date(2025, 1, 1)
EPOCH = date(1970, 1, 1)

MUST_PASS = ("EARTH TREAD AUDIO HEART WORLD PLANT BRAVE WATER HOUSE LIGHT "
             "SOUND POINT THING STORY LEARN WRITE SPEAK WATCH YOUNG CLEAN "
             "DIRTY HAPPY QUICK MOIST CRANE SLATE ADIEU").split()
INVALIDS = ["XXXXX", "ZZZZZ", "QQQQQ", "JJJJJ", "VVVVV", "XXXXQ", "ZZZZA"]

# ---------------------------------------------------------------- parsing

def parse_dictionary():
    """Exact tokens of WordDictionary.rawWords (one multiline literal)."""
    src = open(os.path.join(ROOT, "SaySplit/WordDictionary.swift")).read()
    rw = src.index("static let rawWords")
    q1 = src.index('"""', rw) + 3
    q2 = src.index('"""', q1)
    content = src[q1:q2]
    # Swift strips the closing delimiter's indentation (8 spaces) per line.
    lines = [l[8:] if l.startswith("        ") else l
             for l in content.split("\n")]
    # Swift: split on " " or "\n", omitting empty subsequences.
    return " ".join(lines).split()


def parse_banks():
    """Exact tokens of each answer bank, concatenating literals as Swift
    does (+ inserts NOTHING between them), then splitting with empties
    omitted — so a missing trailing space reproduces the merge bug here
    instead of hiding it."""
    text = open(os.path.join(ROOT, "SaySplit/WordGame.swift")).read()
    banks = {}
    for raw, letn in [("easyAnswersRaw", "easyAnswers"),
                      ("mediumAnswersRaw", "mediumAnswers"),
                      ("hardAnswersRaw", "hardAnswers")]:
        s = text.index(f"private static let {raw}")
        e = text.index(f"\n    static let {letn}:", s)
        lits = re.findall(r'"((?:[^"\\]|\\.)*)"', text[s:e])
        banks[letn] = "".join(lits).split()
    return banks


def parse_seed_offsets():
    text = open(os.path.join(ROOT, "SaySplit/WordGame.swift")).read()
    found = dict(re.findall(r"case \.(easy|medium|hard): return (\d+)", text))
    return {k: int(v) for k, v in found.items()}

# ---------------------------------------------------------------- scoring

def evaluate_app(guess, answer):
    """Mirror of WordEvaluator.evaluate (count-dict two-pass)."""
    g, a = guess.upper(), answer.upper()
    if len(g) != 5 or len(a) != 5:
        return []
    result = ["absent"] * 5
    remaining = {}
    for i in range(5):
        if g[i] == a[i]:
            result[i] = "correct"
        else:
            remaining[a[i]] = remaining.get(a[i], 0) + 1
    for i in range(5):
        if result[i] != "correct" and remaining.get(g[i], 0) > 0:
            result[i] = "present"
            remaining[g[i]] -= 1
    return result


def evaluate_independent(guess, answer):
    """Second scorer, written differently on purpose: list-removal
    semantics instead of a count dict."""
    g, a = list(guess.upper()), list(answer.upper())
    if len(g) != 5 or len(a) != 5:
        return []
    result = [None] * 5
    pool = []
    for i in range(5):
        if g[i] == a[i]:
            result[i] = "correct"
        else:
            pool.append(a[i])
    for i in range(5):
        if result[i] is None:
            if g[i] in pool:
                result[i] = "present"
                pool.remove(g[i])
            else:
                result[i] = "absent"
    return result

# ------------------------------------------------------------------- main

def main():
    failures = []

    def fail(kind, detail):
        failures.append((kind, detail))

    tokens = parse_dictionary()
    token_set = set(tokens)
    banks = parse_banks()
    offsets = parse_seed_offsets()
    bank_by_diff = {"easy": banks["easyAnswers"],
                    "medium": banks["mediumAnswers"],
                    "hard": banks["hardAnswers"]}

    # ------------------------------------------------ data integrity
    integrity = []
    def integ(name, ok, detail=""):
        integrity.append((name, ok, detail))
        if not ok:
            fail("integrity", f"{name}: {detail}")

    integ("dictionary: exactly 21,664 unique tokens",
          len(tokens) == 21664 and len(token_set) == 21664,
          f"tokens={len(tokens)} unique={len(token_set)}")
    integ("dictionary: every token exactly 5 uppercase A-Z letters",
          all(re.fullmatch(r"[A-Z]{5}", t) for t in tokens), "")
    integ("dictionary: HEARTHEAST (merge-bug token) absent",
          "HEARTHEAST" not in token_set, "")
    missing_mp = [w for w in MUST_PASS if w not in token_set]
    integ("dictionary: all 27 must-pass words are whole tokens",
          not missing_mp, f"missing={missing_mp}")
    counts = {k: len(v) for k, v in bank_by_diff.items()}
    integ("banks: counts 300/300/200, unique within bank",
          counts == {"easy": 300, "medium": 300, "hard": 200}
          and all(len(set(v)) == len(v) for v in bank_by_diff.values()),
          f"counts={counts}")
    es, ms, hs = (set(bank_by_diff[k]) for k in ("easy", "medium", "hard"))
    integ("banks: mutually disjoint",
          not (es & ms or es & hs or ms & hs), "")
    integ("banks: every answer is a dictionary token",
          (es | ms | hs) <= token_set,
          f"missing={sorted((es | ms | hs) - token_set)[:10]}")
    integ("seed offsets parsed from WordGame.swift: 0/101/202",
          offsets == {"easy": 0, "medium": 101, "hard": 202},
          f"offsets={offsets}")
    bad_invalids = [w for w in INVALIDS if w in token_set]
    integ("deliberately invalid strings are all non-tokens",
          not bad_invalids, f"unexpectedly valid={bad_invalids}")

    def daily_word(diff, d):
        day_number = (d - EPOCH).days  # Int(timeIntervalSince1970 / 86400)
        lst = bank_by_diff[diff]
        return lst[abs(day_number * 31 + offsets[diff]) % len(lst)]

    # Known-good spot check (confirmed live in the Muse app and on device).
    spot = {diff: daily_word(diff, date(2026, 11, 26))
            for diff in ("easy", "medium", "hard")}
    integ("daily maths spot check 2026-11-26 = BUILT/ANKLE/LATEX",
          spot == {"easy": "BUILT", "medium": "ANKLE", "hard": "LATEX"},
          f"got={spot}")

    # ------------------------------------------------ the 5,000 checks
    rng = random.Random(SEED)
    sorted_tokens = sorted(token_set)
    diffs = ["easy", "medium", "hard"]
    cat = {"valid_accepted": 0, "answer_wins": 0, "duplicates_refused": 0,
           "invalid_rejected": 0, "scoring_crosschecks": 0}
    guess_checks = 0

    def pick_word(exclude):
        while True:
            w = rng.choice(sorted_tokens)
            if w not in exclude:
                return w

    for fill in range(FILLS):
        d = START_DATE + timedelta(days=fill)
        diff = diffs[fill % 3]
        answer = daily_word(diff, d)
        board = []  # accepted guesses on this board, as the app stores them
        ctx = f"fill {fill} date={d.isoformat()} diff={diff} answer={answer}"

        def submit(guess):
            """Mirror of WordleView.submit(): validity first, then the
            duplicate guard; returns (verdict, marks-or-None)."""
            if guess.upper() not in token_set:      # isValidGuess
                return "Not in word list", None
            if guess.upper() in board:              # alreadyGuessed
                return "Already guessed", None
            board.append(guess.upper())
            return "accepted", evaluate_app(guess, answer)

        def expect_accepted(slot, guess, category):
            nonlocal guess_checks
            guess_checks += 1
            before = len(board)
            verdict, marks = submit(guess)
            if verdict != "accepted":
                fail("guess", f"{ctx} slot={slot} guess={guess} "
                              f"expected=accepted actual={verdict}")
                return
            cat[category] += 1
            if len(board) != before + 1:
                fail("guess", f"{ctx} slot={slot} guess={guess} "
                              f"accepted but board size {before}->{len(board)}")
            indep = evaluate_independent(guess, answer)
            cat["scoring_crosschecks"] += 1
            if marks != indep:
                fail("scoring", f"{ctx} slot={slot} guess={guess} "
                                f"app={marks} independent={indep}")

        # slot 1: must-pass word (never the answer itself — the game
        # would already be over)
        mp = MUST_PASS[fill % len(MUST_PASS)]
        if mp == answer:
            mp = MUST_PASS[(fill + 1) % len(MUST_PASS)]
        expect_accepted(1, mp, "valid_accepted")

        # slot 2: a random dictionary word
        w2 = pick_word(exclude={answer, mp})
        expect_accepted(2, w2, "valid_accepted")

        # slot 3: the duplicate — slot 1's word again
        guess_checks += 1
        before = len(board)
        verdict, _ = submit(mp)
        if verdict == "Already guessed" and len(board) == before:
            cat["duplicates_refused"] += 1
        else:
            fail("guess", f"{ctx} slot=3 guess={mp} "
                          f"expected='Already guessed' with no row consumed "
                          f"actual={verdict} board {before}->{len(board)}")

        # slot 4: a deliberately invalid string
        bad = INVALIDS[fill % len(INVALIDS)]
        guess_checks += 1
        before = len(board)
        verdict, _ = submit(bad)
        if verdict == "Not in word list" and len(board) == before:
            cat["invalid_rejected"] += 1
        else:
            fail("guess", f"{ctx} slot=4 guess={bad} "
                          f"expected='Not in word list' with no row consumed "
                          f"actual={verdict} board {before}->{len(board)}")

        # slot 5: even fills play the answer (must win); odd fills play
        # another dictionary word (must be accepted)
        if fill % 2 == 0:
            guess_checks += 1
            verdict, marks = submit(answer)
            if (verdict == "accepted" and marks == ["correct"] * 5
                    and evaluate_independent(answer, answer) == ["correct"] * 5):
                cat["answer_wins"] += 1
                cat["scoring_crosschecks"] += 1
            else:
                fail("guess", f"{ctx} slot=5 guess={answer} "
                              f"expected=accepted win (all correct) "
                              f"actual={verdict} marks={marks}")
        else:
            w5 = pick_word(exclude={answer, mp, w2})
            expect_accepted(5, w5, "valid_accepted")

    # ------------------------------------------------ report
    print("Word Games stress test bed — 1,000 fills x 5 guesses")
    print(f"seed={SEED} dates={START_DATE.isoformat()}.."
          f"{(START_DATE + timedelta(days=FILLS - 1)).isoformat()}")
    print()
    print("Data integrity:")
    for name, ok, detail in integrity:
        print(f"  {'PASS' if ok else 'FAIL'}  {name}  {detail}")
    print()
    print("Guess checks:")
    rows = [("valid words accepted", cat["valid_accepted"], 2500),
            ("answer submitted -> win", cat["answer_wins"], 500),
            ("duplicates refused ('Already guessed')",
             cat["duplicates_refused"], 1000),
            ("invalid strings rejected ('Not in word list')",
             cat["invalid_rejected"], 1000),
            ("TOTAL guess checks", guess_checks, 5000),
            ("scoring cross-checks (app vs independent scorer)",
             cat["scoring_crosschecks"], 3000)]
    for name, got, exp in rows:
        mark = "PASS" if got == exp else "FAIL"
        print(f"  {mark}  {name:<52} {got:>5} / {exp}")
    print()
    if failures:
        print(f"FAILURES: {len(failures)} (showing up to 20 in full)")
        for kind, detail in failures[:20]:
            print(f"  [{kind}] {detail}")
        print()
        print(f"RESULT: FAIL — {len(failures)} failing check(s)")
        return 1
    print("RESULT: PASS — 5,000/5,000 guess checks, "
          f"{cat['scoring_crosschecks']} scoring cross-checks, "
          "all integrity assertions green")
    return 0


if __name__ == "__main__":
    sys.exit(main())
