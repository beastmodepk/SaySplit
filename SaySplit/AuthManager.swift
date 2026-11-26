import Foundation

// MARK: - Auth providers

enum AuthProviderID: String {
    case apple, google, email
}

/// Sign-in providers behind one protocol. Apple is live; Google (Gmail) and
/// Email are present in the UI but NOT configured yet — Google needs a
/// Google Cloud OAuth client ID for this app, which does not exist yet, so
/// no SDK is linked and no credentials are invented.
protocol AuthProvider {
    var id: AuthProviderID { get }
    var isConfigured: Bool { get }
}

struct AppleAuthProvider: AuthProvider {
    let id: AuthProviderID = .apple
    let isConfigured = true
}

struct GoogleAuthProvider: AuthProvider {
    let id: AuthProviderID = .google
    let isConfigured = false // Gate: Google Cloud OAuth client ID not created yet.
}

struct EmailAuthProvider: AuthProvider {
    let id: AuthProviderID = .email
    let isConfigured = false // Gate: no email auth backend configured yet.
}

enum AuthProviders {
    static let all: [AuthProvider] = [AppleAuthProvider(), GoogleAuthProvider(), EmailAuthProvider()]
    static func isConfigured(_ id: AuthProviderID) -> Bool {
        all.first { $0.id == id }?.isConfigured ?? false
    }
}

// MARK: - Auth manager

/// Current signed-in account. Playing never requires signing in: when
/// signed out, everything is stored under the "guest" account key.
/// The Apple user ID is kept in UserDefaults (Keychain-simple storage was
/// the alternative; the ID is an opaque, non-secret identifier).
final class AuthManager: ObservableObject {
    @Published private(set) var accountId: String?
    @Published private(set) var displayName: String?
    @Published private(set) var email: String?
    @Published private(set) var provider: String?

    init() {
        let d = UserDefaults.standard
        accountId = d.string(forKey: "auth.accountId")
        displayName = d.string(forKey: "auth.displayName")
        email = d.string(forKey: "auth.email")
        provider = d.string(forKey: "auth.provider")
    }

    var isSignedIn: Bool { accountId != nil }

    /// Storage namespace for stats, per-date progress and history.
    var storageKey: String { accountId ?? "guest" }

    /// Same value readable from non-View code (game stores).
    static var currentStorageKey: String {
        UserDefaults.standard.string(forKey: "auth.accountId") ?? "guest"
    }

    func signInWithApple(userId: String, name: String?, email: String?) {
        let d = UserDefaults.standard
        accountId = userId
        provider = AuthProviderID.apple.rawValue
        d.set(userId, forKey: "auth.accountId")
        d.set(AuthProviderID.apple.rawValue, forKey: "auth.provider")
        // Apple only sends name/email on the FIRST authorization; keep any
        // previously stored values when later sign-ins send nil.
        if let name, !name.isEmpty {
            displayName = name
            d.set(name, forKey: "auth.displayName")
        }
        if let email, !email.isEmpty {
            self.email = email
            d.set(email, forKey: "auth.email")
        }
    }

    func signOut() {
        let d = UserDefaults.standard
        accountId = nil
        displayName = nil
        email = nil
        provider = nil
        for key in ["auth.accountId", "auth.displayName", "auth.email", "auth.provider"] {
            d.removeObject(forKey: key)
        }
    }
}

// MARK: - Per-account game history

struct GameHistoryEntry: Codable, Identifiable {
    var id: String { "\(dateKey)|\(game)|\(detail)" }
    let dateKey: String   // "2026-11-26"
    let game: String      // "Wordle Easy" / "Connections"
    let detail: String    // "Won in 4" / "Lost — word was CRANE" / "Solved"
    let won: Bool
}

/// Finished-game records, stored per account: "history.<accountKey>".
enum GameHistory {
    private static func key() -> String { "history.\(AuthManager.currentStorageKey)" }

    static func record(dateKey: String, game: String, detail: String, won: Bool) {
        var entries = load()
        let entry = GameHistoryEntry(dateKey: dateKey, game: game, detail: detail, won: won)
        entries.removeAll { $0.dateKey == dateKey && $0.game == game }
        entries.append(entry)
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: key())
        }
    }

    static func entries() -> [GameHistoryEntry] {
        load().sorted { $0.dateKey > $1.dateKey }
    }

    private static func load() -> [GameHistoryEntry] {
        guard let data = UserDefaults.standard.data(forKey: key()),
              let entries = try? JSONDecoder().decode([GameHistoryEntry].self, from: data)
        else { return [] }
        return entries
    }
}
