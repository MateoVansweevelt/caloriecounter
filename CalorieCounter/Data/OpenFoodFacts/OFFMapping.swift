import Foundation

enum OFFMapping {
    /// Map an OFF product into a domain `FoodItem`. Returns `nil` when essential data is missing
    /// (name or energy) — those products are effectively unusable for a nutrition app.
    static func foodItem(from response: OFFResponse, barcode: String) -> FoodItem? {
        guard response.status == 1, let product = response.product else { return nil }
        let name = product.productName?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? product.genericName?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let name, !name.isEmpty else { return nil }

        let basis: ServingBasis = inferBasis(from: product.productQuantityUnit)
        guard let facts = nutritionFacts(from: product.nutriments, basis: basis) else { return nil }

        let brand = product.brands?
            .split(separator: ",")
            .first
            .map { $0.trimmingCharacters(in: .whitespaces) }

        let image = (product.imageFrontURL ?? product.imageURL).flatMap(URL.init(string:))

        return FoodItem(
            name: name,
            brand: brand,
            source: .openFoodFacts(barcode: barcode),
            imageURL: image,
            facts: facts,
            suggestedServings: suggestedServings(from: product, basis: basis)
        )
    }

    private static func inferBasis(from unit: String?) -> ServingBasis {
        switch unit?.lowercased() {
        case "ml", "cl", "l", "dl": .volume
        default: .mass
        }
    }

    private static func nutritionFacts(from nutriments: OFFNutriments?, basis: ServingBasis) -> NutritionFacts? {
        guard let n = nutriments else { return nil }
        let kcal = n.energyKcal100g?.value
            ?? n.energy100g.map { $0.value / 4.184 }  // kJ → kcal fallback
        guard let kcal else { return nil }

        let macros = Macros(
            carbohydrates: .grams(n.carbohydrates100g?.value ?? 0),
            sugars: n.sugars100g.map { .grams($0.value) },
            fiber: n.fiber100g.map { .grams($0.value) },
            protein: .grams(n.proteins100g?.value ?? 0),
            fat: .grams(n.fat100g?.value ?? 0),
            saturatedFat: n.saturatedFat100g.map { .grams($0.value) },
            salt: n.salt100g.map { .grams($0.value) }
        )

        var micros = Micros()
        func set(_ key: MicroKey, grams: FlexibleDouble?) {
            guard let grams else { return }
            micros[key] = .init(mass: .grams(grams.value))
        }
        set(.sodium, grams: n.sodium100g)
        set(.potassium, grams: n.potassium100g)
        set(.calcium, grams: n.calcium100g)
        set(.iron, grams: n.iron100g)
        set(.magnesium, grams: n.magnesium100g)
        set(.zinc, grams: n.zinc100g)
        set(.vitaminA, grams: n.vitaminA100g)
        set(.vitaminC, grams: n.vitaminC100g)
        set(.vitaminD, grams: n.vitaminD100g)
        set(.vitaminE, grams: n.vitaminE100g)
        set(.vitaminB6, grams: n.vitaminB6100g)
        set(.vitaminB12, grams: n.vitaminB12100g)
        set(.folate, grams: n.folate100g)

        return NutritionFacts(
            basis: basis,
            energy: .init(value: kcal, unit: .kilocalories),
            macros: macros,
            micros: micros
        )
    }

    private static func suggestedServings(from product: OFFProduct, basis: ServingBasis) -> [Serving] {
        var result: [Serving] = []
        if let qty = product.servingQuantity?.value, qty > 0 {
            let label = product.servingSize ?? "Serving"
            result.append(Serving(basis: basis, amount: qty, label: label))
        }
        let unitLabel = basis == .mass ? "100 g" : "100 ml"
        result.append(Serving(basis: basis, amount: 100, label: unitLabel))
        return result
    }
}

private extension Measurement where UnitType == UnitMass {
    static func grams(_ value: Double) -> Measurement<UnitMass> {
        .init(value: value, unit: .grams)
    }
}
