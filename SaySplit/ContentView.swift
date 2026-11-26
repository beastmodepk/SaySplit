import SwiftUI

/// Word Games root: two games in one app.
/// TestFlight Test Information: No account needed — open app, Wordle tab has
/// 3 daily words Easy/Medium/Hard, Connections tab is the grouping game.
struct ContentView: View {
    var body: some View {
        TabView {
            WordleView()
                .tabItem { Label("Wordle", systemImage: "square.grid.3x3.fill") }
            ConnectionsView()
                .tabItem { Label("Connections", systemImage: "square.grid.2x2.fill") }
        }
    }
}
