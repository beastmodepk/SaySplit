import SwiftUI
import AuthenticationServices

/// Account tab: sign in to keep your game history under your account.
/// Playing is NEVER blocked by sign-in — signed-out play is stored as guest.
struct AccountView: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var pendingProvider: String?
    @State private var showPendingAlert = false
    @State private var history: [GameHistoryEntry] = []

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    if auth.isSignedIn {
                        if let name = auth.displayName, !name.isEmpty {
                            Text(name).font(.headline)
                        }
                        if let email = auth.email, !email.isEmpty {
                            Text(email).font(.subheadline).foregroundStyle(.secondary)
                        }
                        Text("Signed in with Apple")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Button("Sign Out", role: .destructive) {
                            auth.signOut()
                            refreshHistory()
                        }
                    } else {
                        Text("You're playing as a guest. Sign in to keep your history under your account — the games work either way.")
                            .font(.subheadline).foregroundStyle(.secondary)

                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            handleApple(result)
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 44)

                        Button {
                            pendingProvider = "Google (Gmail)"
                            showPendingAlert = true
                        } label: {
                            Text("Continue with Google (Gmail)")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button {
                            pendingProvider = "Email"
                            showPendingAlert = true
                        } label: {
                            Text("Continue with Email")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Section("About") {
                    Text("Word Games — a daily word game with three Wordle-style words a day (Easy, Medium, Hard) and a daily Connections-style puzzle. Replay past days, sign in to keep your history.")
                        .font(.subheadline)
                }

                Section("Your history") {
                    if history.isEmpty {
                        Text("No finished games yet for this account. Finish a Wordle or Connections board and it will be logged here.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    } else {
                        ForEach(history) { entry in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.game).font(.headline)
                                    Text(entry.detail).font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(entry.dateKey).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
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
