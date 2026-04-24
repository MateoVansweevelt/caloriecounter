import SwiftUI

struct MacroRing: View {
    let title: String
    let current: Double
    let target: Double
    let unit: String
    let tint: Color

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(1.0, current / target)
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(tint.opacity(0.18), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(tint, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.5), value: progress)
                VStack(spacing: 2) {
                    Text("\(Int(current.rounded()))")
                        .font(.title3.bold())
                        .monospacedDigit()
                    Text(unit).font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(width: 84, height: 84)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .padding(12)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }
}

#Preview {
    HStack {
        MacroRing(title: "Carbs", current: 120, target: 250, unit: "g", tint: .orange)
        MacroRing(title: "Protein", current: 60, target: 140, unit: "g", tint: .pink)
        MacroRing(title: "Fat", current: 40, target: 70, unit: "g", tint: .yellow)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
