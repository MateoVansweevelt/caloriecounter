import SwiftUI

@main
struct CalorieCounterWatchApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                TodayWatchRootView()
            }
        }
    }
}
