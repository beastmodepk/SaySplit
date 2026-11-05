import Foundation

/// Pure split / balance / receipt logic, ported from the web version's
/// `core.py`. Money is integer cents everywhere; every function's results
/// sum EXACTLY to the input amount (largest-remainder where needed).

enum SaySplitError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let text): return text
        }
    }
}

enum Money {
    /// "$1,234.56" / "-$5.00" formatting for a cent amount.
    static func format(_ cents: Int) -> String {
        let sign = cents < 0 ? "-" : ""
        let absCents = abs(cents)
        let dollars = absCents / 100
        let remainder = absCents % 100
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        let grouped = formatter.string(from: NSNumber(value: dollars)) ?? "\(dollars)"
        return "\(sign)$\(grouped).\(String(format: "%02d", remainder))"
    }

    /// Parse a user-typed dollar string ("24", "24.5", "$1,200.00") to cents.
    static func parse(_ text: String) -> Int? {
        let cleaned = text.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
        guard !cleaned.isEmpty, let value = Double(cleaned) else { return nil }
        return Int((value * 100).rounded())
    }

    /// Parse a CSV dollar cell exactly (may throw a descriptive message).
    static func dollarsToCents(_ text: String) throws -> Int {
        let cleaned = text.trimmingCharacters(in: .whitespaces)
        guard let value = Double(cleaned) else {
            throw SaySplitError.message("could not convert string to float: '\(text)'")
        }
        return Int((value * 100).rounded())
    }
}

enum SplitMath {
    /// Equal split; remainder cents go to the earliest members so the
    /// parts always sum exactly to the total. (Port of `distribute`.)
    static func distribute(amountCents: Int, memberIDs: [UUID]) throws -> [UUID: Int] {
        guard !memberIDs.isEmpty else {
            throw SaySplitError.message("Select at least one member to split between.")
        }
        let n = memberIDs.count
        let base = amountCents / n
        let remainder = amountCents - base * n
        var out: [UUID: Int] = [:]
        for (index, mid) in memberIDs.enumerated() {
            out[mid] = base + (index < remainder ? 1 : 0)
        }
        return out
    }

    /// Proportional split by weights, largest-remainder method.
    /// (Port of `proportional`.)
    static func proportional(amountCents: Int, weights: [UUID: Double]) throws -> [UUID: Int] {
        let totalWeight = weights.values.reduce(0, +)
        guard totalWeight > 0 else {
            throw SaySplitError.message("Shares must add up to more than zero.")
        }
        var raw: [UUID: Double] = [:]
        var floors: [UUID: Int] = [:]
        for (key, weight) in weights {
            let value = Double(amountCents) * weight / totalWeight
            raw[key] = value
            floors[key] = Int(value) // truncation toward zero, amounts are >= 0
        }
        var leftover = amountCents - floors.values.reduce(0, +)
        let order = raw.keys.sorted { (raw[$0]! - Double(floors[$0]!)) > (raw[$1]! - Double(floors[$1]!)) }
        var index = 0
        while leftover > 0 && !order.isEmpty {
            floors[order[index % order.count], default: 0] += 1
            leftover -= 1
            index += 1
        }
        return floors
    }

    /// Compute the per-member shares for one expense.
    /// Modes: "equal", "exact", "shares" (percentages/shares).
    /// (Port of `compute_splits`.)
    static func computeSplits(amountCents: Int, mode: String, memberIDs: [UUID],
                              exact: [UUID: Int] = [:],
                              shares: [UUID: Double] = [:]) throws -> [UUID: Int] {
        guard amountCents > 0 else {
            throw SaySplitError.message("Amount must be more than zero.")
        }
        switch mode {
        case "equal":
            return try distribute(amountCents: amountCents, memberIDs: memberIDs)
        case "exact":
            guard !exact.isEmpty else {
                throw SaySplitError.message("Enter an exact amount for at least one member.")
            }
            let sum = exact.values.reduce(0, +)
            if sum != amountCents {
                throw SaySplitError.message(
                    "Exact split adds up to \(Money.format(sum)), but the expense is "
                    + "\(Money.format(amountCents)). They must match exactly.")
            }
            if exact.values.contains(where: { $0 < 0 }) {
                throw SaySplitError.message("Exact split amounts cannot be negative.")
            }
            return exact
        case "shares", "percent", "percentage":
            guard !shares.isEmpty else {
                throw SaySplitError.message("Enter shares/percentages for at least one member.")
            }
            if shares.values.contains(where: { $0 < 0 }) {
                throw SaySplitError.message("Shares cannot be negative.")
            }
            return try proportional(amountCents: amountCents, weights: shares)
        default:
            throw SaySplitError.message("Unknown split mode: \(mode)")
        }
    }
}

struct ReceiptItemInput {
    var name: String
    var priceCents: Int
    var assigneeIDs: [UUID]
}

enum ReceiptMath {
    /// Port of `receipt_splits`: item shares first, then tax and tip are
    /// allocated proportionally to each person's item subtotal.
    /// Returns (perMemberCents, subtotalCents, totalCents); always reconciles.
    static func splits(items: [ReceiptItemInput], taxCents: Int, tipCents: Int)
        throws -> (perMember: [UUID: Int], subtotal: Int, total: Int) {
        var subtotal = 0
        var personSubtotal: [UUID: Int] = [:]
        for item in items {
            if item.priceCents < 0 {
                throw SaySplitError.message("Item '\(item.name)' has a negative price.")
            }
            if item.priceCents > 0 && item.assigneeIDs.isEmpty {
                throw SaySplitError.message(
                    "Item '\(item.name)' has no one assigned to it. Assign who had it before saving.")
            }
            subtotal += item.priceCents
            if !item.assigneeIDs.isEmpty {
                let shares = try SplitMath.distribute(amountCents: item.priceCents,
                                                      memberIDs: item.assigneeIDs)
                for (mid, cents) in shares {
                    personSubtotal[mid, default: 0] += cents
                }
            }
        }
        guard subtotal > 0 else {
            throw SaySplitError.message("Add at least one priced item.")
        }
        let zeroWeights = personSubtotal.mapValues { _ in 0 }
        let taxAlloc = taxCents != 0
            ? try SplitMath.proportional(amountCents: taxCents,
                                         weights: personSubtotal.mapValues { Double($0) })
            : zeroWeights
        let tipAlloc = tipCents != 0
            ? try SplitMath.proportional(amountCents: tipCents,
                                         weights: personSubtotal.mapValues { Double($0) })
            : zeroWeights
        var perMember: [UUID: Int] = [:]
        for (mid, sub) in personSubtotal {
            perMember[mid] = sub + (taxAlloc[mid] ?? 0) + (tipAlloc[mid] ?? 0)
        }
        let total = subtotal + taxCents + tipCents
        // Invariant ported from the Python assert: totals must reconcile.
        if perMember.values.reduce(0, +) != total {
            throw SaySplitError.message("Receipt totals do not reconcile — please check the items.")
        }
        return (perMember, subtotal, total)
    }
}

struct DebtTransfer: Equatable {
    var fromID: UUID
    var toID: UUID
    var amountCents: Int
}

enum BalanceMath {
    /// Credit payers the full amount, debit each split member their share,
    /// then apply settle-ups. Result always sums to zero. (Port of `balances`.)
    static func balances(group: SplitGroup) -> [UUID: Int] {
        var bal: [UUID: Int] = [:]
        for member in group.members { bal[member.id] = 0 }
        for expense in group.expenses {
            if bal[expense.payerID] != nil { bal[expense.payerID]! += expense.amountCents }
            for split in expense.splits where bal[split.memberID] != nil {
                bal[split.memberID]! -= split.shareCents
            }
        }
        for settlement in group.settlements {
            if bal[settlement.fromID] != nil { bal[settlement.fromID]! += settlement.amountCents }
            if bal[settlement.toID] != nil { bal[settlement.toID]! -= settlement.amountCents }
        }
        return bal
    }

    /// Greedy min-transfers debt simplification. (Port of `simplify_debts`.)
    /// Positive balance = is owed money; negative = owes.
    static func simplifyDebts(balances: [UUID: Int]) -> [DebtTransfer] {
        struct Party { var id: UUID; var amount: Int }
        // Creditors: largest amount owed first. Debtors: most negative first.
        // (Sort orders mirror the Python implementation.)
        var creditors: [Party] = balances
            .filter { $0.value > 0 }
            .map { Party(id: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
        var debtors: [Party] = balances
            .filter { $0.value < 0 }
            .map { Party(id: $0.key, amount: $0.value) }
            .sorted { $0.amount < $1.amount }

        var transfers: [DebtTransfer] = []
        var i = 0
        var j = 0
        while i < debtors.count && j < creditors.count {
            let pay = min(-debtors[i].amount, creditors[j].amount)
            if pay > 0 {
                transfers.append(DebtTransfer(fromID: debtors[i].id,
                                              toID: creditors[j].id,
                                              amountCents: pay))
            }
            debtors[i].amount += pay
            creditors[j].amount -= pay
            if debtors[i].amount == 0 { i += 1 }
            if creditors[j].amount == 0 { j += 1 }
        }
        return transfers
    }
}
