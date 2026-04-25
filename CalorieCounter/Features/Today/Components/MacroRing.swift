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
                    .stroke(tint.opacity(0.18), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(tint, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.5), value: progress)
                VStack(spacing: 1) {
                    Text("\(Int(current.rounded()))")
                        .font(.system(.headline, design: .rounded).bold())
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text("/ \(Int(target))\(unit)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .frame(width: 76, height: 76)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
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
