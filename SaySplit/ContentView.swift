import SwiftUI

/// Word Games root: two games in one app. Each game screen carries its
/// own header — the game title at the very top, then the date pager
/// under it — so the pager lives with the game it pages.
/// TestFlight Test Information: No account needed — open app, the Word Trio
/// tab has 3 daily words Easy/Medium/Hard, the Group Four tab is the grouping game.
/// The ‹ › pager under each game title goes back to yesterday and earlier
/// days — at most 5 days back, never into the future — and a "Back to
/// today" shortcut appears on past days.
///
/// Chrome insets: the iOS 26 TabView lays tab content out full-bleed
/// and floats its tab pill OVER the content, and the game screens are
/// bare VStacks with no navigation bar — so nothing kept the header
/// out of the status bar (Build 181: the clock struck through the
/// "Word Trio" title). The GeometryReader at this root reads the
/// window's true safe-area insets, and each game tab gets them back
/// explicitly: header starts at safe-area-top + 24, mirroring the
/// Muse web app's `padding-top: env(safe-area-inset-top) + 24px`.
struct ContentView: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var selectedDate: Date = GameCalendar.today

    var body: some View {
        GeometryReader { proxy in
            TabView {
                WordleView(selectedDate: $selectedDate)
                    .padding(.top, proxy.safeAreaInsets.top + 24)
                    .id(auth.storageKey + "|" + GameCalendar.key(for: selectedDate))
                    .tabItem { Label("Word Trio", systemImage: "square.grid.3x3.fill") }
                ConnectionsView(selectedDate: $selectedDate)
                    .padding(.top, proxy.safeAreaInsets.top + 24)
                    .id(auth.storageKey + "|" + GameCalendar.key(for: selectedDate))
                    .tabItem { Label("Group Four", systemImage: "square.grid.2x2.fill") }
                AccountView()
                    .tabItem { Label("Account", systemImage: "person.circle") }
            }
        }
    }
}

/// ‹ Previous day · "Thursday, November 26, 2026" · Next day ›
/// Back reaches at most 5 days into the past (for everyone); next is
/// disabled on today (no future puzzles). The word "Today" appears
/// ONLY when the viewed date really is today; on past dates the
/// shortcut back is labelled "Back to today" instead. The pager
/// buttons are a generous 64×44 tap target; the chevron glyphs
/// themselves are unchanged.
struct DatePagerView: View {
    @Binding var selectedDate: Date

    private var isToday: Bool { GameCalendar.isToday(selectedDate) }
    private var canGoBack: Bool { GameCalendar.canGoBack(from: selectedDate) }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                selectedDate = GameCalendar.adding(days: -1, to: selectedDate)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .frame(width: 64, height: 44)
            }
            .disabled(!canGoBack)
            .opacity(canGoBack ? 1 : 0.3)
            .accessibilityLabel("Previous day")

            Spacer()

            VStack(spacing: 1) {
                Text(GameCalendar.display(for: selectedDate))
                    .font(.headline)
                    .multilineTextAlignment(.center)
                if isToday {
                    Text("Today")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                } else {
                    Button("Back to today") {
                        selectedDate = GameCalendar.today
                    }
                    .font(.caption.bold())
                }
            }

            Spacer()

            Button {
                selectedDate = GameCalendar.adding(days: 1, to: selectedDate)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .frame(width: 64, height: 44)
            }
            .disabled(isToday)
            .opacity(isToday ? 0.3 : 1)
            .accessibilityLabel("Next day")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.08))
    }
}

/// Shown in place of a game board once the 15 free played days are
/// used up and that game's premium isn't owned. Premium is per game:
/// $3 once, yours for life — not a subscription. The Buy button is a
/// clearly-labelled TEST purchase in this build (no charge); real
/// StoreKit purchasing is enabled when the app is published to Apple
/// (see PremiumAccess.buyTestPurchase).
struct PremiumLockView: View {
    let game: PremiumGame
    let onBuy: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("\(game.title) is locked")
                .font(.title3.bold())
            Text("You've used your 15 free days of play. \(game.title) Premium unlocks this game forever.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("$3 once, yours for life — not a subscription.")
                .font(.headline)
            Button(action: onBuy) {
                Text("Buy \(game.title) Premium — $3")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            Text("Test purchase — no charge")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Your progress and history are safe — they're waiting in the Account tab.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .background(Color.gray.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
