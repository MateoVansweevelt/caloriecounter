import SwiftUI
import SwiftData
import UIKit

@main
struct CalorieCounterApp: App {
    @State private var dependencies: AppDependencies?
    @State private var startupError: String?

    init() {
        UIScrollView.appearance().showsVerticalScrollIndicator = false
        UIScrollView.appearance().showsHorizontalScrollIndicator = false
        PhoneWatchSnapshotNotifier.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let dependencies {
                    RootView()
                        .environment(\.dependencies, dependencies)
                        .modelContainer(dependencies.modelContainer)
                } else if let startupError {
                    ContentUnavailableView(
                        "Couldn't start",
                        systemImage: "exclamationmark.triangle.fill",
                        description: Text(startupError)
                    )
                } else {
                    ProgressView()
                        .task {
                            do {
                                dependencies = try AppDependencies.live()
                            } catch {
                                startupError = error.localizedDescription
                            }
                        }
                }
            }
        }
    }
}
