import SwiftUI

struct RootView: View {
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

            Tab("Meals", systemImage: "fork.knife", value: AppTab.meals) {
                MealsListView()
            }

            Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                SettingsView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(.accentColor)
    }
}

enum AppTab: Hashable { case today, log, scan, meals, settings }

#Preview {
    RootView()
}
