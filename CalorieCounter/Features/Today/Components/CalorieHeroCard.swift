import SwiftUI

struct CalorieHeroCard: View {
    let consumedKcal: Double
    let targetKcal: Double

    private var isOver: Bool { consumedKcal > targetKcal }
    private var difference: Double { abs(consumedKcal - targetKcal) }
    private var progress: Double {
        guard targetKcal > 0 else { return 0 }
        return min(1.0, consumedKcal / targetKcal)
    }
    private var progressTint: Color {
        if isOver { return .red }
        if progress >= 0.9 { return .orange }
        return .accentColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Calories").font(.subheadline).foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(Int(consumedKcal.rounded()))")
                            .font(.system(size: 40, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        Text("kcal")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(isOver ? "Over goal" : "Remaining").font(.caption).foregroundStyle(.secondary)
                    Text("\(Int(difference.rounded()))")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(isOver ? .red : .primary)
                }
            }

            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(progressTint)
                .animation(.easeInOut(duration: 0.4), value: progress)

            Label("\(Int(targetKcal)) kcal goal", systemImage: "target")
                .font(.caption)
                .foregroundStyle(.secondary)
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
