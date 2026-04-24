import SwiftUI

struct BarcodeScannerView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var model: ScanViewModel?
    @State private var manualBarcode: String = ""
    @State private var presentedFood: FoodItem?

    var body: some View {
        NavigationStack {
            ZStack {
                if let model {
                    scannerBody(model: model)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Scan")
            .navigationBarTitleDisplayMode(.inline)
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

    @ViewBuilder
    private func scannerBody(model: ScanViewModel) -> some View {
        if ScannerAvailability.isAvailable {
            ZStack {
                DataScannerRepresentable(
                    onBarcode: { model.handle(barcode: $0) },
                    isScanning: Binding(get: { model.isScanning }, set: { model.isScanning = $0 })
                )
                .ignoresSafeArea()

                overlay(for: model)
            }
        } else {
            unavailableSimulatorFallback(model: model)
        }
    }

    @ViewBuilder
    private func overlay(for model: ScanViewModel) -> some View {
        VStack {
            Spacer()
            statusChip(for: model)
                .padding(.bottom, 24)
        }
        .padding(.horizontal, 20)
    }

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

    private func unavailableSimulatorFallback(model: ScanViewModel) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Live scanner needs a device")
                .font(.headline)
            Text("In the simulator, type a barcode to exercise the lookup flow.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            HStack {
                TextField("e.g. 5449000000996", text: $manualBarcode)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                Button("Look up") {
                    let trimmed = manualBarcode.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    model.handle(barcode: trimmed)
                }
                .buttonStyle(.glassProminent)
                .disabled(manualBarcode.isEmpty)
            }

            statusChip(for: model)
        }
        .padding(24)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
        .padding(20)
    }
}

#Preview {
    BarcodeScannerView()
}
