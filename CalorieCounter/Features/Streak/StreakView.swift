import SwiftUI

struct StreakView: View {
    private let store = AppOpenStreakStore.shared

    var body: some View {
        List {
            Section {
                HStack(spacing: 24) {
                    streakTile(title: "Current", value: store.currentStreak, systemImage: "flame.fill")
                    streakTile(title: "Longest", value: store.longestStreak, systemImage: "trophy.fill")
                    streakTile(
                        title: "Last year",
                        value: store.heatmapModel().activeDaysInWindow,
                        systemImage: "square.grid.3x3.fill"
                    )
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            } footer: {
                Text("A day counts when you open the app. The grid shows the last 53 weeks.")
            }

            Section("Activity") {
                ScrollView(.horizontal, showsIndicators: true) {
                    ContributionHeatmapView(
                        model: store.heatmapModel(),
                        accessibilitySummary: store.accessibilitySummary
                    )
                }
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                .listRowBackground(Color.clear)

                HStack {
                    legendDot(color: Color.accentColor.opacity(0.85))
                    Text("Opened")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 16)
                    legendDot(color: Color.secondary.opacity(0.22))
                    Text("No open")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 16)
                    legendDot(color: Color.secondary.opacity(0.12))
                    Text("Future")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Daily streak")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.reloadFromDefaults() }
    }

    private func streakTile(title: String, value: Int, systemImage: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.tint)
            Text("\(value)")
                .font(.title.bold())
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func legendDot(color: Color) -> some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(color)
            .frame(width: 11, height: 11)
    }
}

#Preview {
    NavigationStack {
        StreakView()
    }
}
