import SwiftUI

/// Word Games root: two games in one app, with a date pager at the top.
/// TestFlight Test Information: No account needed — open app, Wordle tab has
/// 3 daily words Easy/Medium/Hard, Connections tab is the grouping game.
/// The ‹ › pager goes back to yesterday, the day before, and earlier days;
/// it never goes into the future, and a "Today" shortcut appears on past days.
struct ContentView: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var selectedDate: Date = GameCalendar.today

    var body: some View {
        VStack(spacing: 0) {
            DatePagerView(selectedDate: $selectedDate)
            TabView {
                WordleView(selectedDate: selectedDate)
                    .id(auth.storageKey + "|" + GameCalendar.key(for: selectedDate))
                    .tabItem { Label("Wordle", systemImage: "square.grid.3x3.fill") }
                ConnectionsView(selectedDate: selectedDate)
                    .id(auth.storageKey + "|" + GameCalendar.key(for: selectedDate))
                    .tabItem { Label("Connections", systemImage: "square.grid.2x2.fill") }
                AccountView()
                    .tabItem { Label("Account", systemImage: "person.circle") }
            }
        }
    }
}

/// ‹ Previous day · "Thursday, November 26, 2026" · Next day ›
/// Next is disabled on today (no future puzzles); "Today" jumps back.
struct DatePagerView: View {
    @Binding var selectedDate: Date

    private var isToday: Bool { GameCalendar.isToday(selectedDate) }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                selectedDate = GameCalendar.adding(days: -1, to: selectedDate)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("Previous day")

            Spacer()

            VStack(spacing: 1) {
                Text(GameCalendar.display(for: selectedDate))
                    .font(.headline)
                    .multilineTextAlignment(.center)
                if !isToday {
                    Button("Today") {
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
                    .frame(width: 36, height: 36)
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
