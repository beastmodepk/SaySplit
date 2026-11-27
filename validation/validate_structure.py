import json, os, re, sys, plistlib
import xml.etree.ElementTree as ET
from collections import Counter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
pbx_path = os.path.join(ROOT, "SaySplit.xcodeproj/project.pbxproj")
pbx = open(pbx_path).read()
results = []
def check(name, ok, detail=""):
    results.append((name, ok, detail))
    print(f"{'PASS' if ok else 'FAIL'}  {name}  {detail}")

# 1. conflict markers anywhere
bad = []
for dirpath, dirs, files in os.walk(ROOT):
    if ".git" in dirpath: continue
    dirs[:] = [d for d in dirs if d != ".git"]
    for f in files:
        p = os.path.join(dirpath, f)
        try: t = open(p, encoding="utf-8", errors="strict").read()
        except Exception: continue
        markers = ("<" * 7, ">" * 7, "\n" + "=" * 7 + "\n")
        if any(m in t for m in markers):
            bad.append(p)
check("no conflict markers", not bad, str(bad))

# 2. pbxproj object definitions: ID followed by optional comment then '= {'
defs = re.findall(r"^\t\t([0-9A-F]{24})(?: /\*[^*]*\*/)? = \{", pbx, re.M)
defcount = Counter(defs)
dups = {k: v for k, v in defcount.items() if v > 1}
check("pbxproj: every object defined exactly once (duplicate-definition check)",
      not dups, f"{len(defs)} definitions, {len(defcount)} unique, dups={dups}")

# 3. dangling references: every 24-hex token used must be defined.
# rootObject and section ids are definitions; remoteGlobalIDString must resolve too.
tokens = set(re.findall(r"\b([0-9A-F]{24})\b", pbx))
dangling = tokens - set(defcount)
check("pbxproj: no dangling references", not dangling, f"{len(tokens)} distinct ids referenced, dangling={dangling}")

# 4. balanced braces/parens in pbxproj (comments stripped not needed: ids/comments balanced too)
check("pbxproj: balanced braces", pbx.count("{") == pbx.count("}"), f"{{={pbx.count('{')} }}={pbx.count('}')}")
check("pbxproj: balanced parens", pbx.count("(") == pbx.count(")"), f"(={pbx.count('(')} )={pbx.count(')')}")

# 5. group children are pure references (no '= {' on a child line)
child_lines = re.findall(r"^\t\t\t\t([0-9A-F]{24}) /\*[^*]*\*/,", pbx, re.M)
inline_defs_in_groups = [c for c in child_lines if re.search(rf"^\t\t\t\t{c}[^\n]*= \{{", pbx, re.M)]
check("pbxproj: group listings hold references only", not inline_defs_in_groups, f"{len(child_lines)} child entries")

# 6. referenced files exist on disk
refs = re.findall(r"([0-9A-F]{24}) /\* ([^*]+) \*/ = \{isa = PBXFileReference;[^}]*path = ([^;]+); sourceTree = ([^;]+);", pbx)
missing = []
for rid, name, path, tree in refs:
    if tree.strip() == "BUILT_PRODUCTS_DIR":
        continue
    # figure folder from group path: app files under SaySplit/, tests under SaySplitTests/
    cands = [os.path.join(ROOT, "SaySplit", path), os.path.join(ROOT, "SaySplitTests", path)]
    if not any(os.path.exists(c) for c in cands):
        missing.append((name, path))
check("pbxproj: every referenced file exists on disk", not missing, f"{len(refs)} file refs, missing={missing}")

# 7. swift file set in project == on disk
proj_swift = sorted({name for _, name, path, tree in refs if name.endswith(".swift")})
disk_swift = []
for dirpath, dirs, files in os.walk(ROOT):
    dirs[:] = [d for d in dirs if d not in (".git",)]
    for f in files:
        if f.endswith(".swift"):
            disk_swift.append(f)
disk_swift = sorted(set(disk_swift))
check("swift file set in project == on disk", proj_swift == disk_swift, f"project={proj_swift} disk={disk_swift}")

# 8. swift brace/paren/bracket balance per file (naive; string literals reviewed if a file fails)
imb = []
for dirpath, dirs, files in os.walk(ROOT):
    dirs[:] = [d for d in dirs if d != ".git"]
    for f in files:
        if f.endswith(".swift"):
            t = open(os.path.join(dirpath, f)).read()
            for a, b in [("{","}"),("(",")"),("[","]")]:
                if t.count(a) != t.count(b):
                    imb.append((f, a, t.count(a), b, t.count(b)))
check("swift files: brace/paren/bracket balance", not imb, str(imb))

# 9. Info.plist parses and contains required usage descriptions
with open(os.path.join(ROOT, "SaySplit/Info.plist"), "rb") as fh:
    info = plistlib.load(fh)
check("Info.plist parses (plistlib)", True, f"{len(info)} keys")
check("Info.plist: NSMicrophoneUsageDescription present", bool(info.get("NSMicrophoneUsageDescription")), "")
check("Info.plist: NSSpeechRecognitionUsageDescription present", bool(info.get("NSSpeechRecognitionUsageDescription")), "")

# 10. asset catalog JSON parses
json_files = []
for dirpath, dirs, files in os.walk(os.path.join(ROOT, "SaySplit/Assets.xcassets")):
    for f in files:
        if f == "Contents.json":
            p = os.path.join(dirpath, f)
            json.load(open(p)); json_files.append(p)
check("asset catalog Contents.json files parse as JSON", True, f"{len(json_files)} files")

# 11. scheme XML parses and its BlueprintIdentifiers exist in pbxproj
scheme = open(os.path.join(ROOT, "SaySplit.xcodeproj/xcshareddata/xcschemes/SaySplit.xcscheme")).read()
ET.fromstring(scheme)
blueprints = set(re.findall(r'BlueprintIdentifier = "([0-9A-F]{24})"', scheme))
check("scheme XML parses; blueprint ids defined in pbxproj", blueprints <= set(defcount) and len(blueprints) == 2, f"blueprints={blueprints}")
check("scheme has Testables for SaySplitTests", "SaySplitTests.xctest" in scheme and "<Testables>" in scheme, "")

# 12. CI workflow sanity
wf = open(os.path.join(ROOT, ".github/workflows/build.yml")).read()
check("CI workflow: macos runner + xcodebuild + signing disabled",
      "macos-" in wf and "xcodebuild build" in wf and "CODE_SIGNING_ALLOWED=NO" in wf, "")

# 13. build settings spot checks
for token in ["IPHONEOS_DEPLOYMENT_TARGET = 17.0", "PRODUCT_BUNDLE_IDENTIFIER = com.parthey.saysplit;",
              "INFOPLIST_FILE = SaySplit/Info.plist;", "GENERATE_INFOPLIST_FILE = NO;",
              "TARGETED_DEVICE_FAMILY = 1;", "TEST_HOST"]:
    check(f"build setting present: {token.split('=')[0].strip()}", token in pbx, "")

# 14. word data: EXACT token audit of the space-joined word strings.
# Parse the Swift string literals exactly as the compiler concatenates
# them (+ inserts NOTHING between literals), split on spaces, and compare
# whole TOKENS — never substrings. (Build 111 shipped literals whose
# missing trailing spaces merged boundary words into 10-letter tokens —
# HEART+HEAST=HEARTHEAST — destroying 1,732 dictionary words and 37
# answer-bank words while substring checks kept passing.)
def exact_tokens(path, start_marker, end_marker):
    t = open(path).read()
    s = t.index(start_marker); e = t.index(end_marker, s)
    lits = re.findall(r'"((?:[^"\\]|\\.)*)"', t[s:e])
    return "".join(lits).split(" "), lits

dict_src = open(os.path.join(ROOT, "SaySplit/WordDictionary.swift")).read()
rw = dict_src.index("static let rawWords")
q1 = dict_src.index('"""', rw) + 3
q2 = dict_src.index('"""', q1)
dict_content = dict_src[q1:q2]
dict_region = dict_src[rw:q2]
# Swift strips the closing delimiter's indentation (8 spaces) per line.
dict_lines = [l[8:] if l.startswith("        ") else l for l in dict_content.split("\n")]
dict_tokens = " ".join(dict_lines).split()
dict_set = set(dict_tokens)
check("word dictionary: stored as ONE multiline literal (no + chain — merges impossible)",
      '" +' not in dict_region and "split(whereSeparator" in dict_src, "")
check("word dictionary: exactly 21,664 unique tokens, all 5 letters",
      len(dict_tokens) == 21664 and len(dict_set) == 21664 and all(len(t) == 5 for t in dict_tokens),
      f"tokens={len(dict_tokens)} unique={len(dict_set)}")
must_pass = "EARTH TREAD AUDIO HEART WORLD PLANT BRAVE WATER HOUSE LIGHT SOUND POINT THING STORY LEARN WRITE SPEAK WATCH YOUNG CLEAN DIRTY HAPPY QUICK MOIST CRANE SLATE ADIEU".split()
check("word dictionary: all 27 must-pass words present as whole tokens",
      all(w in dict_set for w in must_pass),
      f"missing={[w for w in must_pass if w not in dict_set]}")

wg_text = open(os.path.join(ROOT, "SaySplit/WordGame.swift")).read()
all_answers = set()
banks_ok = True; bank_detail = []
for raw, letn, exp in [("easyAnswersRaw", "easyAnswers", 300),
                       ("mediumAnswersRaw", "mediumAnswers", 300),
                       ("hardAnswersRaw", "hardAnswers", 200)]:
    s = wg_text.index(f"private static let {raw}"); e = wg_text.index(f"\n    static let {letn}:", s)
    lits = re.findall(r'"((?:[^"\\]|\\.)*)"', wg_text[s:e])
    toks = "".join(lits).split(" ")
    all_answers |= set(toks)
    ok = (len(toks) == exp and len(set(toks)) == exp and all(len(x) == 5 for x in toks)
          and all(l.endswith(" ") for l in lits[:-1]))
    banks_ok = banks_ok and ok
    bank_detail.append(f"{raw}={len(toks)}")
check("answer banks: exact token counts 300/300/200, all 5 letters, boundaries safe",
      banks_ok, ", ".join(bank_detail))
check("answer banks: every answer is a dictionary token",
      all_answers <= dict_set,
      f"missing={sorted(a for a in all_answers if a not in dict_set)[:10]}")

print()
failed = [r for r in results if not r[1]]
print(f"TOTAL: {len(results)} checks, {len(results)-len(failed)} passed, {len(failed)} failed")
sys.exit(1 if failed else 0)
