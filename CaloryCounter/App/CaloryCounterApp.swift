import SwiftUI
import SwiftData

@main
struct CaloryCounterApp: App {
    @State private var dependencies: AppDependencies?
    @State private var startupError: String?

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
