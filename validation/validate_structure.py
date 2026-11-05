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
      "macos-14" in wf and "xcodebuild build" in wf and "CODE_SIGNING_ALLOWED=NO" in wf, "")

# 13. build settings spot checks
for token in ["IPHONEOS_DEPLOYMENT_TARGET = 17.0", "PRODUCT_BUNDLE_IDENTIFIER = com.parthey.saysplit;",
              "INFOPLIST_FILE = SaySplit/Info.plist;", "GENERATE_INFOPLIST_FILE = NO;",
              "TARGETED_DEVICE_FAMILY = 1;", "TEST_HOST"]:
    check(f"build setting present: {token.split('=')[0].strip()}", token in pbx, "")

print()
failed = [r for r in results if not r[1]]
print(f"TOTAL: {len(results)} checks, {len(results)-len(failed)} passed, {len(failed)} failed")
sys.exit(1 if failed else 0)
