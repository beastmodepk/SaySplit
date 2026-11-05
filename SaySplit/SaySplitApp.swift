import SwiftUI

@main
struct SaySplitApp: App {
    @StateObject private var store = SaySplitStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
