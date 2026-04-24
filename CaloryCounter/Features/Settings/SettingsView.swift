import SwiftUI

struct SettingsView: View {
    @AppStorage(UnitSystem.storageKey) private var unitSystemRaw: String = UnitSystem.metric.rawValue

    var body: some View {
        NavigationStack {
            Form {
                Section("Units") {
                    Picker("Measurement system", selection: unitSystemBinding) {
                        ForEach(UnitSystem.allCases, id: \.self) { system in
                            Text(system.displayName).tag(system)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Coming soon") {
                    Label("Apple Health sync", systemImage: "heart.fill")
                        .foregroundStyle(.pink)
                    Label("Custom foods & recipes", systemImage: "fork.knife.circle")
                    Label("Apple Watch app", systemImage: "applewatch")
                    Label("Widgets & Live Activities", systemImage: "rectangle.stack.badge.play")
                    Label("Siri / App Intents", systemImage: "mic.fill")
                    Label("iCloud sync", systemImage: "cloud.fill")
                }

                Section("About") {
                    LabeledContent("Version", value: "0.1.0 (POC)")
                    LabeledContent("Data source", value: "Open Food Facts")
                }
            }
            .navigationTitle("Settings")
        }
    }

    private var unitSystemBinding: Binding<UnitSystem> {
        Binding(
            get: { UnitSystem(rawValue: unitSystemRaw) ?? .metric },
            set: { unitSystemRaw = $0.rawValue }
        )
    }
}

#Preview {
    SettingsView()
}
