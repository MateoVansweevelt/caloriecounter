import Foundation

@Observable
@MainActor
final class ScanViewModel {
    enum State: Equatable {
        case idle
        case looking(barcode: String)
        case resolved(FoodItem)
        case notFound(barcode: String)
        case failed(String)
    }

    var state: State = .idle
    var isScanning: Bool = true

    private let nutrition: any NutritionProvider
    private var activeTask: Task<Void, Never>?

    init(nutrition: any NutritionProvider) {
        self.nutrition = nutrition
    }

    func handle(barcode: String) {
        guard state != .looking(barcode: barcode) else { return }
        isScanning = false
        state = .looking(barcode: barcode)
        activeTask?.cancel()
        activeTask = Task { [nutrition] in
            do {
                if let item = try await nutrition.lookup(barcode: barcode) {
                    state = .resolved(item)
                } else {
                    state = .notFound(barcode: barcode)
                }
            } catch NutritionLookupError.cancelled {
                // user moved on
            } catch {
                state = .failed((error as? NutritionLookupError).map(describe) ?? error.localizedDescription)
            }
        }
    }

    func reset() {
        activeTask?.cancel()
        activeTask = nil
        state = .idle
        isScanning = true
    }

    private func describe(_ error: NutritionLookupError) -> String {
        switch error {
        case .notFound: "Not found"
        case .network(let underlying): "Network error: \(underlying)"
        case .decoding(let underlying): "Data error: \(underlying)"
        case .cancelled: "Cancelled"
        }
    }
}
