import SwiftUI

struct EditLogEntryView: View {
    let entry: LogEntry
    let onSaved: () -> Void
    let onDeleted: () -> Void

    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var model: EditLogEntryViewModel?
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                if let model {
                    content(model: model)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Edit entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if let model {
                        if model.isSaving {
                            ProgressView().controlSize(.small)
                        } else {
                            Button("Save") {
                                Task {
                                    if await model.save() {
                                        onSaved()
                                        dismiss()
                                    }
                                }
                            }
                            .fontWeight(.semibold)
                            .disabled(model.isSaving)
                        }
                    }
                }
            }
        }
        .task {
            if model == nil, let deps = dependencies {
                model = EditLogEntryViewModel(entry: entry, logbook: deps.logbook)
            }
        }
    }

    @ViewBuilder
    private func content(model: EditLogEntryViewModel) -> some View {
        ScrollView {
            GlassEffectContainer(spacing: 16) {
                VStack(spacing: 16) {
                    header
                    servingCard(model: model)
                    metaCard(model: model)
                    deleteButton(model: model)
                }
                .padding(20)
            }
        }
        .background(background)
    }

    private var header: some View {
        HStack(spacing: 16) {
            AsyncImage(url: entry.food.imageURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    ZStack {
                        Color.secondary.opacity(0.1)
                        Image(systemName: "fork.knife")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(.rect(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.food.name).font(.title3.bold())
                if let brand = entry.food.brand { Text(brand).foregroundStyle(.secondary) }
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    private func servingCard(model: EditLogEntryViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Serving").font(.headline)
            if !entry.food.suggestedServings.isEmpty {
                Picker("Suggested", selection: Binding(
                    get: { model.selectedSuggestedServing },
                    set: { model.applySuggestedServing($0) }
                )) {
                    Text("Custom").tag(Serving?.none)
                    ForEach(entry.food.suggestedServings, id: \.self) { serving in
                        Text(serving.displayLabel).tag(Optional(serving))
                    }
                }
                .pickerStyle(.segmented)
            }
            amountRow(model: model)
            HStack {
                Text(UnitsFormatting.calories(model.consumed.energy))
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                Text("for this serving")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(20)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    private func amountRow(model: EditLogEntryViewModel) -> some View {
        HStack(spacing: 12) {
            Text("Amount")
            Spacer()
            Button { model.decrementAmount() } label: {
                Image(systemName: "minus").frame(width: 28, height: 28)
            }
            .buttonStyle(.glass)

            TextField(
                "Amount",
                value: Binding(
                    get: { model.displayAmount },
                    set: { model.displayAmount = $0 }
                ),
                format: .number.precision(.fractionLength(0...2))
            )
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.center)
            .monospacedDigit()
            .frame(minWidth: 72)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: .rect(cornerRadius: 10))

            Button { model.incrementAmount() } label: {
                Image(systemName: "plus").frame(width: 28, height: 28)
            }
            .buttonStyle(.glass)

            Picker("Unit", selection: Binding(
                get: { model.displayUnit },
                set: { model.displayUnit = $0 }
            )) {
                ForEach(model.availableDisplayUnits, id: \.self) { unit in
                    Text(unit.symbol).tag(unit)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
    }

    private func metaCard(model: EditLogEntryViewModel) -> some View {
        VStack(spacing: 12) {
            DatePicker("When", selection: Binding(
                get: { model.consumedAt },
                set: { model.consumedAt = $0 }
            ))
            Picker("Meal", selection: Binding(
                get: { model.mealSlot },
                set: { model.mealSlot = $0 }
            )) {
                ForEach(MealSlot.allCases, id: \.self) { slot in
                    Label(slot.displayName, systemImage: slot.symbolName).tag(slot)
                }
            }
            TextField("Note", text: Binding(
                get: { model.note },
                set: { model.note = $0 }
            ), axis: .vertical)
            .textFieldStyle(.roundedBorder)
        }
        .padding(20)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    private func deleteButton(model: EditLogEntryViewModel) -> some View {
        Button(role: .destructive) {
            showDeleteConfirm = true
        } label: {
            Text("Delete Entry")
                .frame(maxWidth: .infinity)
        }
        .disabled(model.isSaving)
        .padding(.top, 8)
        .confirmationDialog(
            "Delete this entry?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task {
                    if await model.delete() {
                        onDeleted()
                        dismiss()
                    }
                }
            }
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [Color.accentColor.opacity(0.2), Color(.systemGroupedBackground)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
