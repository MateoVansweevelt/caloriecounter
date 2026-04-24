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
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        // Use search.openfoodfacts.org (Meilisearch-backed) for much better relevance
        // than the basic v2 search on world.openfoodfacts.org.
        var components = URLComponents()
        components.scheme = "https"
        components.host = "search.openfoodfacts.org"
        components.path = "/search"
        components.queryItems = [
            URLQueryItem(name: "q", value: trimmed),
            URLQueryItem(name: "page_size", value: "\(limit)"),
            URLQueryItem(name: "fields", value: "code,product_name,generic_name,brands,image_front_url,image_url,nutriments,serving_size,serving_quantity,product_quantity_unit"),
        ]
        guard let url = components.url else {
            throw NutritionLookupError.network(underlying: "Invalid search URL")
        }

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, _): (Data, URLResponse)
        do {
            (data, _) = try await session.data(for: request)
        } catch is CancellationError {
            throw NutritionLookupError.cancelled
        } catch let urlError as URLError where urlError.code == .cancelled {
            throw NutritionLookupError.cancelled
        } catch {
            throw NutritionLookupError.network(underlying: error.localizedDescription)
        }

        do {
            let decoded = try JSONDecoder().decode(OFFSearchServiceResponse.self, from: data)
            return decoded.hits.compactMap { OFFMapping.foodItem(from: $0) }
        } catch let e as NutritionLookupError {
            throw e
        } catch {
            throw NutritionLookupError.decoding(underlying: error.localizedDescription)
        }
    }
}
