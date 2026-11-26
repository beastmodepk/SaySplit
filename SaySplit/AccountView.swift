import SwiftUI
import AuthenticationServices

/// Account tab: sign in to keep your Word Trio and Group Four history
/// under your account. Playing is NEVER blocked by sign-in — signed-out
/// play is stored as guest, on this device.
struct AccountView: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var pendingProvider: String?
    @State private var showPendingAlert = false
    @State private var history: [GameHistoryEntry] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection

                    if auth.isSignedIn {
                        SignedInSection(auth: auth) {
                            auth.signOut()
                            refreshHistory()
                        }
                    } else {
                        signedOutSection
                    }

                    historySection

                    aboutSection
                }
                .padding(16)
            }
            .navigationTitle("Account")
            .onAppear { refreshHistory() }
            .alert("Sign-in coming soon", isPresented: $showPendingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("\(pendingProvider ?? "That option") sign-in will be enabled once its setup is configured (Google needs an OAuth client for this app). Apple sign-in works now, and you can keep playing as a guest meanwhile.")
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Word Games")
                .font(.largeTitle.bold())
            Text("Sign in to keep your Word Trio and Group Four history.")
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
        }
    }

    // MARK: - Signed out

    private var signedOutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                handleApple(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            SecondarySignInButton(title: "Continue with Google (Gmail)") {
                pendingProvider = "Google (Gmail)"
                showPendingAlert = true
            }

            SecondarySignInButton(title: "Continue with Email") {
                pendingProvider = "Email"
                showPendingAlert = true
            }

            Text("You're playing as a guest. The games work either way — guest games are saved on this device, signed-in games are kept under your account.")
                .font(.footnote)
                .foregroundStyle(Color.secondary)
        }
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your History")
                .font(.title3.bold())

            if history.isEmpty {
                Text("No finished games yet for this account. Finish a Word Trio or Group Four board and it will be logged here.")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(history) { entry in
                        HistoryRow(entry: entry)
                        if entry.id != history.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 12)
                .background(Color.gray.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("About")
                .font(.title3.bold())
            Text("Word Games — two daily word games in one app. Word Trio: guess the five-letter word, three new words a day (Easy, Medium, Hard). Group Four: sort sixteen words into four groups of four. Replay past days, sign in to keep your history.")
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
        }
    }

    // MARK: - Logic (unchanged behaviour)

    private func refreshHistory() {
        history = GameHistory.entries()
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        guard case .success(let authorization) = result,
              let credential = authorization.credential as? ASAuthorizationAppleIDCredential
        else { return }
        var name: String?
        if let fullName = credential.fullName {
            let formatted = PersonNameComponentsFormatter().string(from: fullName)
            if !formatted.isEmpty { name = formatted }
        }
        auth.signInWithApple(userId: credential.user, name: name, email: credential.email)
        refreshHistory()
    }
}

// MARK: - Signed-in identity + sign out

private struct SignedInSection: View {
    @ObservedObject var auth: AuthManager
    let onSignOut: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.green.opacity(0.25))
                    Text(initials)
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 2) {
                    if let name = auth.displayName, !name.isEmpty {
                        Text(name).font(.headline)
                    }
                    if let email = auth.email, !email.isEmpty {
                        Text(email)
                            .font(.subheadline)
                            .foregroundStyle(Color.secondary)
                    }
                    Text("Signed in with Apple")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                }
            }

            Button(role: .destructive) {
                onSignOut()
            } label: {
                Text("Sign Out")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
            }
            .background(Color.gray.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(12)
        .background(Color.gray.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var initials: String {
        let source = auth.displayName ?? auth.email ?? "?"
        let letters = source.split(separator: " ").prefix(2).compactMap { $0.first }
        let result = String(letters).uppercased()
        return result.isEmpty ? "?" : result
    }
}

// MARK: - Secondary (pending) sign-in button

private struct SecondarySignInButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
        }
        .background(Color.gray.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - History row

private struct HistoryRow: View {
    let entry: GameHistoryEntry

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: entry.won ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(entry.won ? Color.green : Color.red)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.game).font(.headline)
                Text(entry.detail)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
            }
            Spacer()
            Text(entry.dateKey)
                .font(.caption)
                .foregroundStyle(Color.secondary)
        }
        .padding(.vertical, 10)
    }
}
