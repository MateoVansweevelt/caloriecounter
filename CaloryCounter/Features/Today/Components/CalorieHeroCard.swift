import SwiftUI

struct CalorieHeroCard: View {
    let consumedKcal: Double
    let targetKcal: Double

    private var remaining: Double { max(0, targetKcal - consumedKcal) }
    private var progress: Double {
        guard targetKcal > 0 else { return 0 }
        return min(1.0, consumedKcal / targetKcal)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Calories today").font(.subheadline).foregroundStyle(.secondary)
                    Text("\(Int(consumedKcal.rounded())) kcal")
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Remaining").font(.caption).foregroundStyle(.secondary)
                    Text("\(Int(remaining.rounded()))")
                        .font(.headline.monospacedDigit())
                }
            }

            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(.accentColor)

            HStack {
                Label("Target \(Int(targetKcal)) kcal", systemImage: "target")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(20)
        .glassEffect(.regular.tint(.accentColor.opacity(0.15)), in: .rect(cornerRadius: 28))
    }
}

#Preview {
    CalorieHeroCard(consumedKcal: 1420, targetKcal: 2200)
        .padding()
        .background(Color(.systemGroupedBackground))
}
