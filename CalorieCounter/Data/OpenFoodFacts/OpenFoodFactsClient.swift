import Foundation

public actor OpenFoodFactsClient: NutritionProvider {
    private let session: URLSession
    private let baseURL: URL
    private let userAgent: String
    private var cache: [String: FoodItem] = [:]

    public init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://world.openfoodfacts.org")!,
        userAgent: String = "CalorieCounter/0.1 (iOS; POC)"
    ) {
        self.session = session
        self.baseURL = baseURL
        self.userAgent = userAgent
    }

    public func lookup(barcode: String) async throws -> FoodItem? {
        if let cached = cache[barcode] { return cached }

        let url = baseURL
            .appendingPathComponent("api/v2/product/\(barcode).json")
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw NutritionLookupError.cancelled
        } catch {
            throw NutritionLookupError.network(underlying: error.localizedDescription)
        }

        if let http = response as? HTTPURLResponse, http.statusCode == 404 { return nil }

        do {
            let decoded = try JSONDecoder().decode(OFFResponse.self, from: data)
            guard decoded.status == 1 else { return nil }
            guard let item = OFFMapping.foodItem(from: decoded, barcode: barcode) else { return nil }
            cache[barcode] = item
            return item
        } catch let error as NutritionLookupError {
            throw error
        } catch {
            throw NutritionLookupError.decoding(underlying: error.localizedDescription)
        }
    }

    public func search(query: String, limit: Int) async throws -> [FoodItem] {
        // Intentionally minimal for the POC — barcode is the primary path.
        // The v2 search endpoint can be slotted in here later without touching callers.
        _ = (query, limit)
        return []
    }
}
