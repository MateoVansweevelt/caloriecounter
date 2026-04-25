import SwiftUI

struct LogbookView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var model: LogbookViewModel?
    @State private var editingEntry: LogEntry?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let model {
                    List {
                        Section {
                            DatePicker(
                                "Day",
                                selection: Binding(
                                    get: { model.selectedDay },
                                    set: { model.selectedDay = $0 }
                                ),
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                            .onChange(of: model.selectedDay) { _, _ in
                                Task { await model.load() }
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listSectionSeparator(.hidden)

                        Section {
                            totalsRow(model: model)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listSectionSeparator(.hidden)

                        if model.entries.isEmpty {
                            Section {
                                ContentUnavailableView(
                                    "No entries",
                                    systemImage: "tray",
                                    description: Text("Pick another day or add something new.")
                                )
                                .listRowBackground(Color.clear)
                            }
                            .listSectionSeparator(.hidden)
                        } else {
                            ForEach(MealSlot.allCases, id: \.self) { slot in
                                let slotEntries = model.entries.filter { $0.mealSlot == slot }
                                if !slotEntries.isEmpty {
                                    Section {
                                        ForEach(slotEntries) { entry in
                                            Button { editingEntry = entry } label: {
                                                entryRow(entry: entry)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .onDelete { indexSet in
                                            Task {
                                                for index in indexSet {
                                                    await model.delete(slotEntries[index])
                                                }
                                            }
                                        }
                                    } header: {
                                        Label(slot.displayName, systemImage: slot.symbolName)
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
            .background(backgroundGradient)
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

    private func totalsRow(model: LogbookViewModel) -> some View {
        HStack(spacing: 12) {
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

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color.accentColor.opacity(0.25), Color(.systemGroupedBackground)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
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
