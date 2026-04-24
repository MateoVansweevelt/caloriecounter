import SwiftUI

struct BarcodeScannerView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var model: ScanViewModel?
    @State private var presentedFood: FoodItem?
    @State private var manualBarcode: String = ""
    @State private var showingManualEntry = false
    @FocusState private var manualFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                if let model {
                    scannerBody(model: model)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Scan Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            if model == nil, let deps = dependencies {
                model = ScanViewModel(nutrition: deps.nutritionProvider)
            }
        }
        .sheet(item: $presentedFood) { food in
            FoodDetailView(food: food) {
                presentedFood = nil
                model?.reset()
            }
        }
        .onChange(of: model?.state) { _, newState in
            if case let .resolved(item) = newState {
                presentedFood = item
            }
        }
    }

    // MARK: - Scanner body

    @ViewBuilder
    private func scannerBody(model: ScanViewModel) -> some View {
        if ScannerAvailability.isAvailable {
            ZStack {
                DataScannerRepresentable(
                    onBarcode: { model.handle(barcode: $0) },
                    isScanning: Binding(get: { model.isScanning }, set: { model.isScanning = $0 })
                )
                .ignoresSafeArea()

                cameraOverlay(model: model)
            }
        } else {
            simulatorFallback(model: model)
        }
    }

    // MARK: - Camera overlay

    @ViewBuilder
    private func cameraOverlay(model: ScanViewModel) -> some View {
        VStack {
            Spacer()
            VStack(spacing: 12) {
                if showingManualEntry {
                    manualEntryPanel(model: model)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                HStack(spacing: 12) {
                    statusChip(for: model)
                    if case .idle = model.state, !showingManualEntry {
                        Button {
                            withAnimation(.spring(duration: 0.3)) { showingManualEntry = true }
                            manualFocused = true
                        } label: {
                            Image(systemName: "keyboard")
                                .padding(12)
                        }
                        .glassEffect(.regular, in: .circle)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .animation(.spring(duration: 0.3), value: showingManualEntry)
        .animation(.spring(duration: 0.3), value: model.state == .idle)
    }

    // MARK: - Manual entry panel

    private func manualEntryPanel(model: ScanViewModel) -> some View {
        HStack(spacing: 10) {
            TextField("Barcode number", text: $manualBarcode)
                .keyboardType(.numberPad)
                .textFieldStyle(.plain)
                .focused($manualFocused)
            if !manualBarcode.isEmpty {
                Button("Look up") {
                    let trimmed = manualBarcode.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    model.handle(barcode: trimmed)
                    withAnimation { showingManualEntry = false }
                    manualBarcode = ""
                }
                .buttonStyle(.glassProminent)
            }
            Button {
                withAnimation(.spring(duration: 0.3)) { showingManualEntry = false }
                manualBarcode = ""
                manualFocused = false
            } label: {
                Image(systemName: "xmark")
                    .padding(10)
            }
            .glassEffect(.regular, in: .circle)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .capsule)
    }

    // MARK: - Status chip

    @ViewBuilder
    private func statusChip(for model: ScanViewModel) -> some View {
        switch model.state {
        case .idle:
            Label("Point at a barcode", systemImage: "viewfinder")
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 20).padding(.vertical, 12)
                .glassEffect(.regular, in: .capsule)
        case .looking(let barcode):
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("Looking up \(barcode)…")
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
            .glassEffect(.regular, in: .capsule)
        case .notFound(let barcode):
            HStack(spacing: 10) {
                Image(systemName: "questionmark.circle.fill")
                Text("No record for \(barcode)")
                Button("Retry") { model.reset() }.buttonStyle(.glass)
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
            .glassEffect(.regular, in: .capsule)
        case .failed(let message):
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(message).lineLimit(2)
                Button("Retry") { model.reset() }.buttonStyle(.glass)
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
            .glassEffect(.regular.tint(.red.opacity(0.2)), in: .capsule)
        case .resolved:
            EmptyView()
        }
    }

    // MARK: - Simulator fallback

    private func simulatorFallback(model: ScanViewModel) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 56))
                        .foregroundStyle(.tint)
                    Text("Camera Not Available")
                        .font(.headline)
                    Text("Enter a barcode number to look up a product.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    TextField("e.g. 5449000000996", text: $manualBarcode)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                    Button("Look up") {
                        let trimmed = manualBarcode.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        model.handle(barcode: trimmed)
                        manualBarcode = ""
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(manualBarcode.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                statusChip(for: model)
                    .frame(maxWidth: .infinity)
            }
            .padding(24)
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
        .padding(20)
    }
}

#Preview {
    BarcodeScannerView()
}
