import Foundation
import Testing
@testable import CaloryCounter

@Suite("Open Food Facts mapping")
struct OFFMappingTests {

    @Test("Coca-Cola fixture maps to expected FoodItem")
    func colaFixture() throws {
        let url = try #require(Bundle(for: BundleMarker.self).url(forResource: "coca_cola", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let response = try JSONDecoder().decode(OFFResponse.self, from: data)
        let food = try #require(OFFMapping.foodItem(from: response, barcode: "5449000000996"))

        #expect(food.name == "Coca-Cola")
        #expect(food.brand == "Coca-Cola")
        #expect(food.facts.basis == .volume)
        #expect(food.facts.energy.converted(to: .kilocalories).value == 42)
        #expect(food.facts.macros.carbohydrates.converted(to: .grams).value == 10.6)
        #expect(food.suggestedServings.contains { $0.amount == 330 })
    }

    @Test("status=0 payloads return nil")
    func missingProduct() throws {
        let url = try #require(Bundle(for: BundleMarker.self).url(forResource: "missing", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let response = try JSONDecoder().decode(OFFResponse.self, from: data)
        #expect(OFFMapping.foodItem(from: response, barcode: "0000000000000") == nil)
    }

    @Test("numeric strings decode via FlexibleDouble")
    func flexibleDoubleAcceptsString() throws {
        let json = #"{"v": "12.5"}"#.data(using: .utf8)!
        struct Wrapper: Decodable { let v: FlexibleDouble }
        let wrapped = try JSONDecoder().decode(Wrapper.self, from: json)
        #expect(wrapped.v.value == 12.5)
    }
}

private final class BundleMarker {}
