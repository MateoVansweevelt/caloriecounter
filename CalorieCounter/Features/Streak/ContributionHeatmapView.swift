import SwiftUI

struct ContributionHeatmapView: View {
    let model: ContributionHeatmapModel
    var accessibilitySummary: String
    /// When true, cell size is derived from the offered width so the grid fits without horizontal scrolling.
    var scalesToFitWidth: Bool = false

    private let defaultCellSize: CGFloat = 11
    private let spacing: CGFloat = 3

    var body: some View {
        Group {
            if scalesToFitWidth {
                GeometryReader { geo in
                    let cell = cellSize(forWidth: geo.size.width)
                    heatmapContent(cellSize: cell, monthHeaderHeight: 16)
                }
                .frame(height: 16 + 6 + 7 * 16 + 6 * spacing)
            } else {
                heatmapContent(cellSize: defaultCellSize, monthHeaderHeight: 16)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilitySummary))
    }

    private func cellSize(forWidth width: CGFloat) -> CGFloat {
        let cols = max(model.cells.count, 1)
        let totalSpacing = CGFloat(max(cols - 1, 0)) * spacing
        let raw = (width - totalSpacing) / CGFloat(cols)
        return min(16, max(8, floor(raw)))
    }

    @ViewBuilder
    private func heatmapContent(cellSize: CGFloat, monthHeaderHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            monthHeaderRow(cellSize: cellSize, headerHeight: monthHeaderHeight)
            gridRow(cellSize: cellSize)
        }
    }

    private func monthHeaderRow(cellSize: CGFloat, headerHeight: CGFloat) -> some View {
        HStack(spacing: spacing) {
            ForEach(0..<model.cells.count, id: \.self) { weekIndex in
                Text(model.monthLabels[weekIndex] ?? " ")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: cellSize, height: headerHeight, alignment: .leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.45)
            }
        }
    }

    private func gridRow(cellSize: CGFloat) -> some View {
        HStack(alignment: .top, spacing: spacing) {
            ForEach(0..<model.cells.count, id: \.self) { weekIndex in
                VStack(spacing: spacing) {
                    ForEach(0..<7, id: \.self) { weekdayIndex in
                        if weekIndex < model.cells.count, weekdayIndex < model.cells[weekIndex].count {
                            let cell = model.cells[weekIndex][weekdayIndex]
                            ZStack {
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(fillColor(for: cell))
                                if cell.isToday {
                                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                                        .stroke(Color.accentColor, lineWidth: 2)
                                }
                            }
                            .frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }
        }
    }

    private func fillColor(for cell: ContributionHeatmapCell) -> Color {
        if cell.isOutsideMonth {
            return .clear
        }
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
        model: ContributionHeatmapModel.buildLast53Weeks(
            now: Date(),
            calendar: .current,
            openDayEpochs: []
        ),
        accessibilitySummary: "Preview"
    )
    .padding()
}
