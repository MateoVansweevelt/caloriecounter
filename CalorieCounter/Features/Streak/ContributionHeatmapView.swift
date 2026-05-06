import SwiftUI

struct ContributionHeatmapView: View {
    let model: ContributionHeatmapModel
    var accessibilitySummary: String

    private let cellSize: CGFloat = 11
    private let spacing: CGFloat = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            monthHeaderRow
            gridRow
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilitySummary))
    }

    private var monthHeaderRow: some View {
        HStack(spacing: spacing) {
            ForEach(0..<model.cells.count, id: \.self) { weekIndex in
                Text(model.monthLabels[weekIndex] ?? " ")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: cellSize, alignment: .leading)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
    }

    private var gridRow: some View {
        HStack(alignment: .top, spacing: spacing) {
            ForEach(0..<model.cells.count, id: \.self) { weekIndex in
                VStack(spacing: spacing) {
                    ForEach(0..<7, id: \.self) { weekdayIndex in
                        if weekIndex < model.cells.count, weekdayIndex < model.cells[weekIndex].count {
                            let cell = model.cells[weekIndex][weekdayIndex]
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(fillColor(for: cell))
                                .frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }
        }
    }

    private func fillColor(for cell: ContributionHeatmapCell) -> Color {
        if cell.isFuture {
            return Color.secondary.opacity(0.12)
        }
        if cell.wasOpened {
            return Color.accentColor.opacity(0.85)
        }
        return Color.secondary.opacity(0.22)
    }
}

#Preview {
    ContributionHeatmapView(
        model: ContributionHeatmapModel.build(
            now: Date(),
            calendar: .current,
            openDayEpochs: []
        ),
        accessibilitySummary: "Preview"
    )
    .padding()
}
