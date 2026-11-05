import Foundation

/// Splitwise CSV import/export, ported from the web version's
/// `parse_splitwise_csv` / `export_csv` in core.py.
///
/// Export format: `Date, Description, Cost, Currency,` + one column per
/// member holding that member's NET amount for the row
/// (positive = they paid more than their share / are owed,
///  negative = that amount is their share owed).
/// Bad rows are reported by row number, never silently dropped.

struct ImportedRow {
    var date: Date
    var dateText: String
    var descriptionText: String
    var costCents: Int
    var payerName: String
    var splitsByName: [String: Int]
}

struct SplitwiseParseResult {
    var rows: [ImportedRow] = []
    var errors: [String] = []
    var memberNames: [String] = []

    var totalCents: Int { rows.reduce(0) { $0 + $1.costCents } }
}

enum CSVText {
    /// Minimal RFC-4180-style parser: quoted fields, embedded commas,
    /// doubled quotes, CRLF or LF line endings.
    static func parse(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var field = ""
        var row: [String] = []
        var inQuotes = false
        let chars = Array(text)
        var i = 0

        func endField() { row.append(field); field = "" }
        func endRow() { endField(); rows.append(row); row = [] }

        while i < chars.count {
            let c = chars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" {
                        field.append("\"")
                        i += 2
                        continue
                    }
                    inQuotes = false
                } else {
                    field.append(c)
                }
            } else if c == "\"" {
                inQuotes = true
            } else if c == "," {
                endField()
            } else if c == "\r" {
                // handled together with the following \n if present
                if i + 1 < chars.count && chars[i + 1] == "\n" { i += 1 }
                endRow()
            } else if c == "\n" {
                endRow()
            } else {
                field.append(c)
            }
            i += 1
        }
        if !field.isEmpty || !row.isEmpty { endRow() }
        return rows
    }

    static func escape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }
}

enum SplitwiseCSV {
    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func parse(_ text: String) -> SplitwiseParseResult {
        var result = SplitwiseParseResult()
        let table = CSVText.parse(text)
        guard let headerRaw = table.first, !headerRaw.isEmpty else {
            result.errors = ["CSV has no header row."]
            return result
        }
        let fields = headerRaw.map { $0.trimmingCharacters(in: .whitespaces) }
        var lowerToField: [String: String] = [:]
        for field in fields { lowerToField[field.lowercased()] = field }
        for needed in ["date", "description", "cost"] where lowerToField[needed] == nil {
            result.errors = ["Missing required column: \(needed.capitalized)"]
            return result
        }
        let reserved: Set<String> = ["date", "description", "category", "cost", "currency"]
        let memberNames = fields.filter { !reserved.contains($0.lowercased()) }
        guard !memberNames.isEmpty else {
            result.errors = ["No member columns found (expected one column per person)."]
            return result
        }
        result.memberNames = memberNames

        func cell(_ row: [String], _ field: String) -> String {
            guard let index = fields.firstIndex(of: field), index < row.count else { return "" }
            return row[index]
        }

        for (offset, row) in table.dropFirst().enumerated() {
            let lineno = offset + 2 // header is line 1
            if row.allSatisfy({ $0.trimmingCharacters(in: .whitespaces).isEmpty }) { continue }
            do {
                let dateTextRaw = cell(row, lowerToField["date"]!).trimmingCharacters(in: .whitespaces)
                let datePrefix = String(dateTextRaw.prefix(10))
                guard let date = dateFormatter.date(from: datePrefix) else {
                    throw SaySplitError.message("invalid date '\(dateTextRaw)'")
                }
                let desc = cell(row, lowerToField["description"]!).trimmingCharacters(in: .whitespaces)
                guard !desc.isEmpty else {
                    throw SaySplitError.message("empty description")
                }
                let cost = try Money.dollarsToCents(cell(row, lowerToField["cost"]!))
                guard cost > 0 else {
                    throw SaySplitError.message("cost must be more than zero")
                }
                var nets: [String: Int] = [:]
                for name in memberNames {
                    let rawValue = cell(row, name).trimmingCharacters(in: .whitespaces)
                    nets[name] = rawValue.isEmpty ? 0 : try Money.dollarsToCents(rawValue)
                }
                let netSum = nets.values.reduce(0, +)
                if abs(netSum) > memberNames.count {
                    throw SaySplitError.message(
                        "member amounts sum to \(Money.format(netSum)), not $0.00")
                }
                let positives = nets.filter { $0.value > 0 }
                guard let payer = positives.max(by: { $0.value < $1.value })?.key else {
                    throw SaySplitError.message("no payer found (no member has a positive amount)")
                }
                let owedTotal = nets.values.filter { $0 < 0 }.reduce(0) { $0 - $1 }
                let remaining = cost - owedTotal
                guard remaining >= 0 else {
                    throw SaySplitError.message("member shares exceed the cost")
                }
                var splits: [String: Int] = [:]
                for (name, value) in nets where value < 0 { splits[name] = -value }
                if remaining > 0 {
                    // Give member IDs a stable order for allocation.
                    let orderedPositiveNames = memberNames.filter { (positives[$0] ?? 0) > 0 }
                    var weights: [UUID: Double] = [:]
                    var scratchIDs: [String: UUID] = [:]
                    for name in orderedPositiveNames {
                        let scratch = UUID()
                        scratchIDs[name] = scratch
                        weights[scratch] = Double(positives[name]!)
                    }
                    let alloc = try SplitMath.proportional(amountCents: remaining, weights: weights)
                    for name in orderedPositiveNames {
                        if let scratch = scratchIDs[name], let cents = alloc[scratch] {
                            splits[name, default: 0] += cents
                        }
                    }
                }
                guard splits.values.reduce(0, +) == cost else {
                    throw SaySplitError.message("could not reconcile shares to the cost")
                }
                result.rows.append(ImportedRow(date: date, dateText: datePrefix,
                                               descriptionText: desc, costCents: cost,
                                               payerName: payer, splitsByName: splits))
            } catch {
                result.errors.append("Row \(lineno): \(error.localizedDescription)")
            }
        }
        return result
    }

    /// Export a group back into Splitwise format (expenses only;
    /// settle-ups are not part of the Splitwise export shape, matching
    /// the web version).
    static func export(group: SplitGroup) -> String {
        let memberOrder = group.members.sorted { $0.name < $1.name }
        var lines: [String] = []
        let header = ["Date", "Description", "Cost", "Currency"] + memberOrder.map { $0.name }
        lines.append(header.map(CSVText.escape).joined(separator: ","))
        for expense in group.expenses.sorted(by: { $0.date < $1.date }) {
            var nets: [UUID: Int] = [:]
            for member in group.members { nets[member.id] = 0 }
            for split in expense.splits { nets[split.memberID, default: 0] -= split.shareCents }
            nets[expense.payerID, default: 0] += expense.amountCents
            var row = [dateFormatter.string(from: expense.date), expense.descriptionText,
                       String(format: "%.2f", Double(expense.amountCents) / 100.0), "USD"]
            for member in memberOrder {
                row.append(String(format: "%.2f", Double(nets[member.id] ?? 0) / 100.0))
            }
            lines.append(row.map(CSVText.escape).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
