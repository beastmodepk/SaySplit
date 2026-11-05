import Foundation

/// Local rule-based command parser, ported from the web version's
/// `parser.py` with the same behaviour and phrase shapes:
///   "Dinner, eighty dollars, split four ways"
///   "Taxi $24 paid by Shannon split between Parthey and Shannon"
///   "Groceries 120 dollars split equally"
///   "I paid 60 for pizza split with Shannon"
/// It only produces a PREVIEW. Nothing is saved by this type — the UI
/// shows an editable preview and the user confirms before storing.

struct ParsedCommand {
    var raw: String = ""
    var descriptionText: String = ""
    var amountCents: Int? = nil
    var payerName: String? = nil
    var splitMemberNames: [String] = []
    var splitMode: String = "equal"
    var splitCount: Int? = nil
    var warnings: [String] = []

    var amountDollars: Double? {
        guard let cents = amountCents else { return nil }
        return Double(cents) / 100.0
    }
}

enum RegexHelper {
    static func regex(_ pattern: String, caseInsensitive: Bool = true) -> NSRegularExpression? {
        try? NSRegularExpression(pattern: pattern,
                                 options: caseInsensitive ? [.caseInsensitive] : [])
    }

    /// Capture groups of the first match (group 0 is the whole match).
    static func firstGroups(_ pattern: String, in text: String) -> [String]? {
        guard let re = regex(pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = re.firstMatch(in: text, range: range) else { return nil }
        var groups: [String] = []
        for i in 0..<match.numberOfRanges {
            if let r = Range(match.range(at: i), in: text) {
                groups.append(String(text[r]))
            } else {
                groups.append("")
            }
        }
        return groups
    }

    static func contains(_ pattern: String, in text: String) -> Bool {
        firstGroups(pattern, in: text) != nil
    }

    static func replace(_ pattern: String, in text: String, with replacement: String) -> String {
        guard let re = regex(pattern) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return re.stringByReplacingMatches(in: text, range: range, withTemplate: replacement)
    }

    static func allTokens(_ text: String) -> [String] {
        let lowered = text.lowercased()
        guard let re = regex("[a-z]+", caseInsensitive: false) else { return [] }
        let range = NSRange(lowered.startIndex..., in: lowered)
        return re.matches(in: lowered, range: range).compactMap { match in
            Range(match.range, in: lowered).map { String(lowered[$0]) }
        }
    }
}

enum CommandParser {
    static let units: [String: Int] = [
        "zero": 0, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
        "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
        "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14,
        "fifteen": 15, "sixteen": 16, "seventeen": 17, "eighteen": 18,
        "nineteen": 19, "a": 1, "an": 1
    ]
    static let tens: [String: Int] = [
        "twenty": 20, "thirty": 30, "forty": 40, "fifty": 50,
        "sixty": 60, "seventy": 70, "eighty": 80, "ninety": 90
    ]
    static var numberWords: Set<String> {
        Set(units.keys).union(tens.keys).union(["hundred", "thousand", "and"])
    }

    /// Convert tokens like ["eighty","five"] or
    /// ["one","hundred","and","twenty","five"] to an Int. (Port of
    /// `words_to_number`.)
    static func wordsToNumber(_ tokens: [String]) -> Int? {
        guard !tokens.isEmpty else { return nil }
        var total = 0
        var current = 0
        var seen = false
        for token in tokens {
            if let value = units[token] {
                current += value; seen = true
            } else if let value = tens[token] {
                current += value; seen = true
            } else if token == "hundred" {
                current = (current == 0 ? 1 : current) * 100; seen = true
            } else if token == "thousand" {
                total += (current == 0 ? 1 : current) * 1000; current = 0; seen = true
            } else if token == "and" {
                continue
            } else {
                return nil
            }
        }
        return seen ? total + current : nil
    }

    /// Find "<number words> dollars/bucks"; returns (cents, spanText).
    static func findWordAmount(_ text: String) -> (cents: Int, span: String)? {
        let low = text.lowercased()
        guard let re = RegexHelper.regex("\\b(dollars?|bucks)\\b", caseInsensitive: false)
        else { return nil }
        let fullRange = NSRange(low.startIndex..., in: low)
        for match in re.matches(in: low, range: fullRange) {
            guard let matchRange = Range(match.range, in: low) else { continue }
            let beforeText = String(low[low.startIndex..<matchRange.lowerBound])
            let before = RegexHelper.allTokens(beforeText)
            var run: [String] = []
            for token in before.reversed() {
                if numberWords.contains(token) {
                    run.insert(token, at: 0)
                } else {
                    break
                }
            }
            if !run.isEmpty, let value = wordsToNumber(run) {
                return (value * 100, run.joined(separator: " ") + " " + String(low[matchRange]))
            }
        }
        return nil
    }

    static func findSplitCount(_ text: String) -> Int? {
        if let groups = RegexHelper.firstGroups("split\\s+([a-z]+|\\d+)\\s+ways?", in: text.lowercased()) {
            let token = groups[1]
            if let number = Int(token) { return number }
            return wordsToNumber([token])
        }
        if let groups = RegexHelper.firstGroups("split\\s+between\\s+(\\d+)", in: text.lowercased()) {
            return Int(groups[1])
        }
        return nil
    }

    static func matchMember(_ fragment: String, memberNames: [String]) -> String? {
        let frag = fragment.trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: ",."))
            .lowercased()
        for name in memberNames {
            let lowered = name.lowercased()
            if frag == lowered || frag.hasPrefix(lowered + " ")
                || lowered == frag.split(separator: " ").first.map(String.init) {
                return name
            }
        }
        return nil
    }

    /// Parse a command into a preview. `currentUser` is who "I" refers to
    /// (defaults to a member named "Parthey", else the first member).
    static func parseCommand(_ text: String, memberNames: [String],
                             currentUser: String? = nil) -> ParsedCommand {
        let original = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let low = original.lowercased()
        var result = ParsedCommand()
        result.raw = original
        guard !original.isEmpty else {
            result.warnings.append("Empty command.")
            return result
        }
        var work = low

        let me: String = currentUser
            ?? memberNames.first(where: { $0.lowercased() == "parthey" })
            ?? memberNames.first
            ?? "You"

        // ---- amount ---------------------------------------------------
        if let groups = RegexHelper.firstGroups("\\$\\s*(\\d+(?:\\.\\d{1,2})?)", in: work),
           let value = Double(groups[1]) {
            result.amountCents = Int((value * 100).rounded())
            work = work.replacingOccurrences(of: groups[0], with: " ")
        }
        if result.amountCents == nil, let found = findWordAmount(work) {
            result.amountCents = found.cents
            work = work.replacingOccurrences(of: found.span, with: " ")
        }
        if result.amountCents == nil,
           let groups = RegexHelper.firstGroups("\\b(\\d+(?:\\.\\d{1,2})?)\\s*(?:dollars?|bucks)\\b", in: work),
           let value = Double(groups[1]) {
            result.amountCents = Int((value * 100).rounded())
            work = work.replacingOccurrences(of: groups[0], with: " ")
        }
        if result.amountCents == nil,
           let groups = RegexHelper.firstGroups("(?:paid|pay|spent|cost)\\s+\\$?(\\d+(?:\\.\\d{1,2})?)", in: work),
           let value = Double(groups[1]) {
            result.amountCents = Int((value * 100).rounded())
        }
        if result.amountCents == nil {
            // Bare word amount, e.g. "dinner eighty split equally"
            let tokens = RegexHelper.allTokens(work)
            outer: for i in tokens.indices {
                let upper = min(i + 4, tokens.count)
                if upper <= i { continue }
                for j in stride(from: upper, through: i + 1, by: -1) {
                    let chunk = Array(tokens[i..<j])
                    if chunk.allSatisfy({ numberWords.contains($0) }),
                       let value = wordsToNumber(chunk), value > 0 {
                        result.amountCents = value * 100
                        break outer
                    }
                }
            }
        }
        if result.amountCents == nil {
            result.warnings.append("No amount found — add one in the preview.")
        }

        // ---- payer ------------------------------------------------------
        if let groups = RegexHelper.firstGroups("paid\\s+by\\s+([a-z]+)", in: work) {
            result.payerName = matchMember(groups[1], memberNames: memberNames)
                ?? groups[1].capitalized
        }
        if result.payerName == nil, RegexHelper.contains("\\bi\\s+paid\\b", in: work) {
            result.payerName = me
        }
        if result.payerName == nil {
            for name in memberNames
            where RegexHelper.contains("\\b\(NSRegularExpression.escapedPattern(for: name.lowercased()))\\s+paid\\b", in: work) {
                result.payerName = name
                break
            }
        }
        if result.payerName == nil {
            result.payerName = me
            result.warnings.append("No payer named — assuming \(me). Check the preview.")
        }

        // ---- split ------------------------------------------------------
        let count = findSplitCount(work)
        if let count = count {
            result.splitCount = count
            result.splitMemberNames = Array(memberNames.prefix(count))
            if memberNames.count < count {
                result.warnings.append(
                    "Says split \(count) ways but the group has \(memberNames.count) member(s) — "
                    + "pick who is in the split in the preview.")
            }
        }
        if count == nil,
           let groups = RegexHelper.firstGroups("split\\s+between\\s+(.+)$", in: work) {
            var names: [String] = []
            let parts = groups[1].components(separatedBy: ",")
                .flatMap { $0.components(separatedBy: " and ") }
            for part in parts {
                if let name = matchMember(part, memberNames: memberNames), !names.contains(name) {
                    names.append(name)
                }
            }
            if !names.isEmpty { result.splitMemberNames = names }
        }
        if result.splitMemberNames.isEmpty,
           let groups = RegexHelper.firstGroups("split\\s+with\\s+([a-z]+)", in: work) {
            let name = matchMember(groups[1], memberNames: memberNames)
            var names: [String] = []
            if let payer = result.payerName, memberNames.contains(payer) {
                names.append(payer)
            }
            if let name = name, !names.contains(name) { names.append(name) }
            if !names.isEmpty { result.splitMemberNames = names }
        }
        if result.splitMemberNames.isEmpty {
            result.splitMemberNames = memberNames
            if !memberNames.isEmpty {
                result.warnings.append("No split names found — splitting among all group members.")
            }
        }
        if low.contains("equally") || low.contains("evenly") {
            result.splitMode = "equal"
        }

        // ---- description ------------------------------------------------
        var desc = original
        desc = RegexHelper.replace("\\$\\s*\\d+(?:\\.\\d{1,2})?", in: desc, with: " ")
        desc = RegexHelper.replace("\\b\\d+(?:\\.\\d{1,2})?\\s*(?:dollars?|bucks)\\b", in: desc, with: " ")
        if let found = findWordAmount(low) {
            desc = RegexHelper.replace(NSRegularExpression.escapedPattern(for: found.span),
                                       in: desc, with: " ")
        }
        desc = RegexHelper.replace("\\bpaid\\s+by\\s+[A-Za-z]+\\b", in: desc, with: " ")
        desc = RegexHelper.replace("\\bI\\s+paid\\s+\\d+(?:\\.\\d{1,2})?\\s+for\\b", in: desc, with: " ")
        desc = RegexHelper.replace("\\bI\\s+paid\\b", in: desc, with: " ")
        for name in memberNames {
            desc = RegexHelper.replace(
                "\\b\(NSRegularExpression.escapedPattern(for: name))\\s+paid\\b", in: desc, with: " ")
        }
        desc = RegexHelper.replace("\\bsplit\\b.*$", in: desc, with: " ")
        desc = desc.trimmingCharacters(in: .whitespaces)
        desc = RegexHelper.replace("\\bfor\\b\\s*$", in: desc, with: " ")
        desc = RegexHelper.replace("[\\s,]+", in: desc, with: " ")
        desc = desc.trimmingCharacters(in: CharacterSet(charactersIn: " ,.-"))
        if !desc.isEmpty {
            desc = desc.prefix(1).uppercased() + desc.dropFirst()
        }
        result.descriptionText = desc
        if result.descriptionText.isEmpty {
            result.warnings.append("No description found — add one in the preview.")
        }
        return result
    }
}
