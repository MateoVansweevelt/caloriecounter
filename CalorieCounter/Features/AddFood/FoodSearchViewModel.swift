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
                // user cleared the search
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}
