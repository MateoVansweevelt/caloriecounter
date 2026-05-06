import Foundation
import Testing
@testable import CalorieCounter

// MARK: - Mock URLProtocol
final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Data, HTTPURLResponse))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (data, response) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            if error is CancellationError {
                client?.urlProtocol(self, didFailWithError: URLError(.cancelled))
            } else {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }
    }

    override func stopLoading() {}
}

private func makeSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: config)
}

@Suite("OpenFoodFactsClient")
actor OpenFoodFactsClientTests {

    @Test("lookup caches successful responses")
    func lookupCachesSuccessfulResponse() async throws {
        let session = makeSession()
        let client = OpenFoodFactsClient(session: session)

        var calls = 0
        MockURLProtocol.handler = { req in
            calls += 1
            let url = req.url!
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let json = """
            {"status":1,"product":{"product_name":"Water","nutriments":{"energy-kcal_100g":0}}}
            """.data(using: .utf8)!
            return (json, response)
        }

        let one = try await client.lookup(barcode: "123")
        let two = try await client.lookup(barcode: "123")
        #expect(one?.name == "Water")
        #expect(two?.name == "Water")
        #expect(calls == 1)
    }

    @Test("lookup returns nil on 404")
    func lookupReturnsNilOn404() async throws {
        let session = makeSession()
        let client = OpenFoodFactsClient(session: session)

        MockURLProtocol.handler = { req in
            let url = req.url!
            let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        let item = try await client.lookup(barcode: "000")
        #expect(item == nil)
    }

    @Test("lookup maps network errors to .network")
    func lookupMapsNetworkError() async {
        let session = makeSession()
        let client = OpenFoodFactsClient(session: session)

        MockURLProtocol.handler = { _ in
            throw URLError(.timedOut)
        }

        do {
            _ = try await client.lookup(barcode: "1")
            Issue.record("Expected throw")
        } catch let NutritionLookupError.network(underlying: msg) {
            #expect(!msg.isEmpty)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("lookup maps cancellation to .cancelled")
    func lookupMapsCancellation() async {
        let session = makeSession()
        let client = OpenFoodFactsClient(session: session)

        MockURLProtocol.handler = { _ in
            throw CancellationError()
        }

        do {
            _ = try await client.lookup(barcode: "1")
            Issue.record("Expected throw")
        } catch NutritionLookupError.cancelled {
            // OK
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("search trims whitespace and returns empty for blank queries")
    func searchTrimsAndRejectsEmpty() async throws {
        let session = makeSession()
        let client = OpenFoodFactsClient(session: session)
        var called = false
        MockURLProtocol.handler = { _ in
            called = true
            let url = URL(string: "https://example.com")!
            return (Data(), HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        let results = try await client.search(query: "   ")
        #expect(results.isEmpty)
        #expect(called == false)
    }

    @Test("search decodes hits")
    func searchDecodesHits() async throws {
        let session = makeSession()
        let client = OpenFoodFactsClient(session: session)

        MockURLProtocol.handler = { req in
            let url = req.url!
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let json = """
            {"hits":[
                {"product_name":"Apple Juice","brands":["Brand"],"code":"111","nutriments":{"energy-kcal_100g":46}},
                {"product_name":"Orange Juice","brands":["Brand"],"code":"222","nutriments":{"energy-kcal_100g":45}}
            ]}
            """.data(using: .utf8)!
            return (json, response)
        }

        let hits = try await client.search(query: "juice", limit: 2)
        #expect(hits.count == 2)
        #expect(hits[0].name.contains("Apple"))
        #expect(hits[1].name.contains("Orange"))
    }
}
