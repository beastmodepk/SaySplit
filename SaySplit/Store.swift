import Foundation
import Combine

/// On-device-only store. All data lives in a single Codable JSON file in
/// the app's Application Support folder ("SaySplit/saysplit.json").
/// Receipt photos are stored as JPEG files alongside it ("Receipts/").
/// No server, no network, no account. Money is integer cents.
@MainActor
final class SaySplitStore: ObservableObject {
    @Published private(set) var groups: [SplitGroup] = []

    private let fileURL: URL
    private let receiptsDir: URL
    private var isLoading = true

    init() {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("SaySplit", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        receiptsDir = dir.appendingPathComponent("Receipts", isDirectory: true)
        try? fm.createDirectory(at: receiptsDir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("saysplit.json")
        load()
        isLoading = false
    }

    // MARK: - Persistence

    private func load() {
        if let data = try? Data(contentsOf: fileURL), let decoded = decode(data) {
            groups = decoded.groups
        } else {
            groups = [] // empty start, like the web version
        }
    }

    private func save() {
        guard !isLoading else { return }
        let payload = AppData(groups: groups)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(payload) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }

    // NOTE: the decoder must match the encoder's date strategy.
    private func decode(_ data: Data) -> AppData? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(AppData.self, from: data)
    }

    // Use the matching decoder for reloads triggered externally (not used
    // in v1 UI flows, kept symmetric with save()).
    func reloadFromDisk() {
        if let data = try? Data(contentsOf: fileURL), let decoded = decode(data) {
            groups = decoded.groups
        }
    }

    // MARK: - Lookup helpers

    func group(id: UUID) -> SplitGroup? { groups.first { $0.id == id } }

    private func updateGroup(id: UUID, _ mutate: (inout SplitGroup) -> Void) {
        guard let index = groups.firstIndex(where: { $0.id == id }) else { return }
        mutate(&groups[index])
        save()
    }

    // MARK: - Groups & members (each returns an error message, or nil on success)

    @discardableResult
    func createGroup(name: String) -> UUID? {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let group = SplitGroup(name: trimmed)
        groups.append(group)
        save()
        return group.id
    }

    func renameGroup(id: UUID, name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "Group name cannot be empty." }
        updateGroup(id: id) { $0.name = trimmed }
        return nil
    }

    func addMember(groupID: UUID, name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "Member name cannot be empty." }
        guard let group = group(id: groupID) else { return "Group not found." }
        if group.members.contains(where: { $0.name.lowercased() == trimmed.lowercased() }) {
            return "'\(trimmed)' is already a member of this group."
        }
        updateGroup(id: groupID) { $0.members.append(Member(name: trimmed)) }
        return nil
    }

    /// Port of the web rule: a member who is payer or split member on any
    /// expense cannot be removed — refuse with an explanation.
    func removeMember(groupID: UUID, memberID: UUID) -> String? {
        guard let group = group(id: groupID) else { return "Group not found." }
        let isPayer = group.expenses.contains { $0.payerID == memberID }
        let isSplit = group.expenses.contains { expense in
            expense.splits.contains { $0.memberID == memberID }
        }
        let inSettlement = group.settlements.contains {
            $0.fromID == memberID || $0.toID == memberID
        }
        if isPayer || isSplit || inSettlement {
            return "That member is on existing expenses and cannot be removed. "
                + "Add a replacement or leave them in the group."
        }
        updateGroup(id: groupID) { $0.members.removeAll { $0.id == memberID } }
        return nil
    }

    // MARK: - Expenses

    /// Validates that shares sum to the total and everyone belongs to the
    /// group (same checks as the web Store.add_expense).
    func addExpense(groupID: UUID, expense: Expense) -> String? {
        guard let group = group(id: groupID) else { return "Group not found." }
        guard !expense.descriptionText.trimmingCharacters(in: .whitespaces).isEmpty else {
            return "Description cannot be empty."
        }
        guard expense.splits.reduce(0) { $0 + $1.shareCents } == expense.amountCents else {
            return "Split shares do not add up to the expense total."
        }
        let memberIDs = Set(group.members.map { $0.id })
        guard memberIDs.contains(expense.payerID) else {
            return "Payer must be a member of this group."
        }
        guard expense.splits.allSatisfy({ memberIDs.contains($0.memberID) }) else {
            return "Every split member must belong to this group."
        }
        updateGroup(id: groupID) { $0.expenses.append(expense) }
        return nil
    }

    func addSettlement(groupID: UUID, fromID: UUID, toID: UUID,
                       amountCents: Int, date: Date) -> String? {
        guard fromID != toID else { return "A settle-up needs two different members." }
        guard amountCents > 0 else { return "Settle-up amount must be more than zero." }
        guard let group = group(id: groupID) else { return "Group not found." }
        let memberIDs = Set(group.members.map { $0.id })
        guard memberIDs.contains(fromID), memberIDs.contains(toID) else {
            return "Both members must belong to this group."
        }
        let settlement = Settlement(fromID: fromID, toID: toID,
                                    amountCents: amountCents, date: date)
        updateGroup(id: groupID) { $0.settlements.append(settlement) }
        return nil
    }

    // MARK: - Balances & activity

    func balances(groupID: UUID) -> [UUID: Int] {
        guard let group = group(id: groupID) else { return [:] }
        return BalanceMath.balances(group: group)
    }

    func simplifiedDebts(groupID: UUID) -> [DebtTransfer] {
        BalanceMath.simplifyDebts(balances: balances(groupID: groupID))
    }

    func activity(groupID: UUID) -> [ActivityItem] {
        guard let group = group(id: groupID) else { return [] }
        let items: [ActivityItem] = group.expenses.map(ActivityItem.expense)
            + group.settlements.map(ActivityItem.settlement)
        return items.sorted { $0.sortDate > $1.sortDate }
    }

    // MARK: - Receipt photos (preview reference only — no OCR)

    func saveReceiptPhoto(_ data: Data) -> String? {
        let filename = UUID().uuidString + ".jpg"
        let url = receiptsDir.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: [.atomic])
            return filename
        } catch {
            return nil
        }
    }

    func receiptPhotoData(filename: String) -> Data? {
        try? Data(contentsOf: receiptsDir.appendingPathComponent(filename))
    }

    // MARK: - Splitwise import / export

    /// Creates a new import group from parsed rows, matching the web flow.
    func importGroup(name: String, result: SplitwiseParseResult) -> UUID? {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !result.rows.isEmpty else { return nil }
        var group = SplitGroup(name: trimmed)
        var idsByName: [String: UUID] = [:]
        for memberName in result.memberNames {
            let member = Member(name: memberName)
            group.members.append(member)
            idsByName[memberName] = member.id
        }
        for row in result.rows {
            guard let payerID = idsByName[row.payerName] else { continue }
            let splits = row.splitsByName.compactMap { (name, cents) -> ExpenseSplit? in
                guard let mid = idsByName[name] else { return nil }
                return ExpenseSplit(memberID: mid, shareCents: cents)
            }
            group.expenses.append(Expense(descriptionText: row.descriptionText,
                                          amountCents: row.costCents, payerID: payerID,
                                          date: row.date, splitMode: "import",
                                          kind: "import", splits: splits))
        }
        groups.append(group)
        save()
        return group.id
    }

    func exportCSV(groupID: UUID) -> String {
        guard let group = group(id: groupID) else { return "" }
        return SplitwiseCSV.export(group: group)
    }

    /// Writes the export to a temporary .csv file for the share sheet.
    func exportFileURL(groupID: UUID) -> URL? {
        guard let group = group(id: groupID) else { return nil }
        let safeName = group.name.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SaySplit-\(safeName).csv")
        do {
            try exportCSV(groupID: groupID).write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Demo data (only when the user taps "Load demo group")

    func loadDemoGroup() {
        let parthey = Member(name: "Parthey")
        let shannon = Member(name: "Shannon")
        let het = Member(name: "Het")
        let maya = Member(name: "Maya")
        let memberIDs = [parthey.id, shannon.id, het.id, maya.id]
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today

        func equalExpense(_ description: String, cents: Int, payer: Member,
                          among: [Member], date: Date) -> Expense {
            let ids = among.map { $0.id }
            let shares = (try? SplitMath.distribute(amountCents: cents, memberIDs: ids)) ?? [:]
            return Expense(descriptionText: description, amountCents: cents,
                           payerID: payer.id, date: date, splitMode: "equal",
                           splits: ids.compactMap { id in
                               shares[id].map { ExpenseSplit(memberID: id, shareCents: $0) }
                           })
        }

        var group = SplitGroup(name: "Demo — Lisbon Trip",
                               members: [parthey, shannon, het, maya])
        group.expenses = [
            equalExpense("Dinner", cents: 8000, payer: parthey,
                         among: [parthey, shannon, het, maya], date: yesterday),
            equalExpense("Taxi", cents: 2400, payer: shannon,
                         among: [parthey, shannon], date: yesterday),
            equalExpense("Groceries", cents: 12000, payer: het,
                         among: [parthey, shannon, het, maya], date: today)
        ]
        _ = memberIDs
        groups.append(group)
        save()
    }
}
