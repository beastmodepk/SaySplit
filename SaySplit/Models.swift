import Foundation

/// SaySplit data model. Mirrors the web version's data concepts
/// (groups / members / expenses / expense splits / settlements),
/// stored as one Codable JSON document on device.
/// Money is ALWAYS integer cents — never floating point.

struct Member: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

struct ExpenseSplit: Codable, Equatable {
    var memberID: UUID
    var shareCents: Int
}

struct Expense: Identifiable, Codable, Equatable {
    var id: UUID
    var descriptionText: String
    var amountCents: Int
    var payerID: UUID
    var date: Date
    var splitMode: String          // "equal" | "exact" | "shares" | "receipt" | "import"
    var kind: String               // "standard" | "receipt" | "import"
    var splits: [ExpenseSplit]
    var detail: String?            // e.g. receipt breakdown text
    var receiptPhotoFilename: String?

    init(id: UUID = UUID(), descriptionText: String, amountCents: Int, payerID: UUID,
         date: Date, splitMode: String, kind: String = "standard",
         splits: [ExpenseSplit], detail: String? = nil, receiptPhotoFilename: String? = nil) {
        self.id = id
        self.descriptionText = descriptionText
        self.amountCents = amountCents
        self.payerID = payerID
        self.date = date
        self.splitMode = splitMode
        self.kind = kind
        self.splits = splits
        self.detail = detail
        self.receiptPhotoFilename = receiptPhotoFilename
    }
}

struct Settlement: Identifiable, Codable, Equatable {
    var id: UUID
    var fromID: UUID
    var toID: UUID
    var amountCents: Int
    var date: Date

    init(id: UUID = UUID(), fromID: UUID, toID: UUID, amountCents: Int, date: Date) {
        self.id = id
        self.fromID = fromID
        self.toID = toID
        self.amountCents = amountCents
        self.date = date
    }
}

struct SplitGroup: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var createdAt: Date
    var members: [Member]
    var expenses: [Expense]
    var settlements: [Settlement]

    init(id: UUID = UUID(), name: String, createdAt: Date = Date(),
         members: [Member] = [], expenses: [Expense] = [], settlements: [Settlement] = []) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.members = members
        self.expenses = expenses
        self.settlements = settlements
    }

    func member(id: UUID) -> Member? { members.first { $0.id == id } }
    func memberName(id: UUID) -> String { member(id: id)?.name ?? "?" }
}

struct AppData: Codable {
    var groups: [SplitGroup] = []
}

/// One activity-feed row: either an expense or a settle-up, newest first.
enum ActivityItem: Identifiable {
    case expense(Expense)
    case settlement(Settlement)

    var id: String {
        switch self {
        case .expense(let e): return "e-\(e.id.uuidString)"
        case .settlement(let s): return "s-\(s.id.uuidString)"
        }
    }

    var sortDate: Date {
        switch self {
        case .expense(let e): return e.date
        case .settlement(let s): return s.date
        }
    }
}
