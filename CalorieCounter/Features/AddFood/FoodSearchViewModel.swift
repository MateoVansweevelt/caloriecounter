import Foundation

@Observable
@MainActor
final class FoodSearchViewModel {
    var results: [FoodItem] = []
    var isLoading = false
    var errorMessage: String?

    private let nutrition: any NutritionProvider
    private var searchTask: Task<Void, Never>?

    init(nutrition: any NutritionProvider) {
        self.nutrition = nutrition
    }

    private static func describe(_ error: any Error) -> String {
        switch error as? NutritionLookupError {
        case .network(let msg): return "Network error: \(msg)"
        case .decoding(let msg): return "Couldn't read response: \(msg)"
        case .notFound: return "Not found"
        case .cancelled, nil: return error.localizedDescription
        }
    }

    func search(query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            isLoading = false
            errorMessage = nil
            return
        }
        isLoading = true
        errorMessage = nil
        searchTask = Task { [nutrition] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            do {
                let items = try await nutrition.search(query: trimmed)
                guard !Task.isCancelled else { return }
                results = items
                isLoading = false
            } catch NutritionLookupError.cancelled {
                // user cleared the search or typed the next character
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = Self.describe(error)
                isLoading = false
            }
        }
    }
}
