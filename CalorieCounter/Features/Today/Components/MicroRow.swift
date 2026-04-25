import SwiftUI

struct MicroRow: View {
    let key: MicroKey
    let value: MicroValue

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(.tint.opacity(0.75))
                .frame(width: 7, height: 7)
            Text(key.displayName)
            Spacer()
            Text(UnitsFormatting.grams(value.mass))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 6)
    }
}
