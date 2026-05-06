import SwiftUI
import UIKit

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection: AppTab = .today

    var body: some View {
        TabView(selection: $selection) {
            Tab("Today", systemImage: "chart.bar.doc.horizontal", value: AppTab.today) {
                TodayView()
            }

            Tab("Log", systemImage: "list.bullet.rectangle.portrait", value: AppTab.log) {
                LogbookView()
            }

            Tab("Add Food", systemImage: "plus.circle", value: AppTab.scan, role: .search) {
                AddFoodView()
            }

            Tab("Forecast", systemImage: "chart.line.uptrend.xyaxis", value: AppTab.forecast) {
                MetabolismForecastView()
            }

            Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                SettingsView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(.accentColor)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                AppOpenStreakStore.shared.recordOpenIfNeeded()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            AppOpenStreakStore.shared.recordOpenIfNeeded()
        }
    }
}

enum AppTab: Hashable { case today, log, scan, forecast, settings }

#Preview {
    RootView()
}
