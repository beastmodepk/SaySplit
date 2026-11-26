import SwiftUI

@main
struct SaySplitApp: App {
    @StateObject private var auth = AuthManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
                .onAppear { ReminderScheduler.sync() }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Re-sync reminders whenever the app becomes active, so
            // finished puzzles stop being reminded about.
            if newPhase == .active { ReminderScheduler.sync() }
        }
    }
}
