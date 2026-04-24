import SwiftUI

struct LogbookView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var model: LogbookViewModel?
    @State private var editingEntry: LogEntry?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let model {
                    DatePicker(
                        "Day",
                        selection: Binding(
                            get: { model.selectedDay },
                            set: { model.selectedDay = $0 }
                        ),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .padding(.horizontal, 20).padding(.top, 12)
                    .onChange(of: model.selectedDay) { _, _ in
                        Task { await model.load() }
                    }

                    totalsCard(model: model)
                        .padding(.horizontal, 20).padding(.top, 12)

                    List {
                        Section("Entries") {
                            if model.entries.isEmpty {
                                ContentUnavailableView(
                                    "No entries",
                                    systemImage: "tray",
                                    description: Text("Pick another day or scan something new.")
                                )
                            } else {
                                ForEach(model.entries) { entry in
                                    Button { editingEntry = entry } label: {
                                        entryRow(entry: entry)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .onDelete { indexSet in
                                    Task {
                                        for index in indexSet {
                                            await model.delete(model.entries[index])
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Log")
            .background(Color(.systemGroupedBackground))
        }
        .sheet(item: $editingEntry) { entry in
            EditLogEntryView(
                entry: entry,
                onSaved: { Task { await model?.load() } },
                onDeleted: { Task { await model?.load() } }
            )
        }
        .task {
            if model == nil, let deps = dependencies {
                model = LogbookViewModel(logbook: deps.logbook)
            }
            await model?.load()
        }
    }

    private func totalsCard(model: LogbookViewModel) -> some View {
        HStack(spacing: 16) {
            pill(title: "Calories", value: UnitsFormatting.calories(model.totals.energy))
            pill(title: "Carbs", value: UnitsFormatting.grams(model.totals.macros.carbohydrates))
            pill(title: "Protein", value: UnitsFormatting.grams(model.totals.macros.protein))
            pill(title: "Fat", value: UnitsFormatting.grams(model.totals.macros.fat))
        }
    }

    private func pill(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.semibold)).monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }

    private func entryRow(entry: LogEntry) -> some View {
        HStack(spacing: 12) {
            Image(systemName: entry.mealSlot.symbolName)
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.food.displayTitle).lineLimit(1)
                Text("\(entry.mealSlot.displayName) · \(entry.serving.displayLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(UnitsFormatting.calories(entry.consumed.energy))
                .monospacedDigit()
                .font(.subheadline.weight(.semibold))
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    LogbookView()
}
