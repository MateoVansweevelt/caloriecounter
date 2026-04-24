import SwiftUI

struct MicroRow: View {
    let key: MicroKey
    let value: MicroValue

    var body: some View {
        HStack {
            Image(systemName: "circle.hexagongrid.fill")
                .foregroundStyle(.tint)
                .font(.caption)
            Text(key.displayName)
            Spacer()
            Text(UnitsFormatting.grams(value.mass))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 6)
    }
}
