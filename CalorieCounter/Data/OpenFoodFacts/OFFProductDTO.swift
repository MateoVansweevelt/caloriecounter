import Foundation

/// Decodable DTOs for Open Food Facts v2 `/product/{barcode}.json`.
/// Kept deliberately permissive — OFF fields are frequently missing or typed inconsistently
/// (strings that should be numbers, numbers that should be strings). `FlexibleDouble` handles
/// both; everything else is `Optional`.

struct OFFResponse: Decodable, Sendable {
    let status: Int
    let code: String?
    let product: OFFProduct?
}

struct OFFProduct: Decodable, Sendable {
    let code: String?
    let productName: String?
    let genericName: String?
    let brands: String?
    let imageURL: String?
    let imageFrontURL: String?
    let servingSize: String?
    let servingQuantity: FlexibleDouble?
    let productQuantityUnit: String?
    let nutriments: OFFNutriments?

    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case genericName = "generic_name"
        case brands
        case imageURL = "image_url"
        case imageFrontURL = "image_front_url"
        case servingSize = "serving_size"
        case servingQuantity = "serving_quantity"
        case productQuantityUnit = "product_quantity_unit"
        case nutriments
    }
}

// Used by world.openfoodfacts.org/api/v2/search (kept for reference, not currently used)
struct OFFSearchResponse: Decodable, Sendable {
    let count: Int?
    let products: [OFFProduct]
}

// Used by search.openfoodfacts.org — better relevance, different schema
struct OFFSearchServiceResponse: Decodable, Sendable {
    let hits: [OFFSearchHit]
}

struct OFFSearchHit: Decodable, Sendable {
    let code: String?
    let productName: String?
    let genericName: String?
    let brands: [String]?
    let imageURL: String?
    let imageFrontURL: String?
    let servingSize: String?
    let servingQuantity: FlexibleDouble?
    let productQuantityUnit: String?
    let nutriments: OFFNutriments?

    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case genericName = "generic_name"
        case brands
        case imageURL = "image_url"
        case imageFrontURL = "image_front_url"
        case servingSize = "serving_size"
        case servingQuantity = "serving_quantity"
        case productQuantityUnit = "product_quantity_unit"
        case nutriments
    }
}

/// Nutriment values in OFF are per-100g/ml and in grams (mass) or as-given for energy.
/// Keys with the `_100g` suffix are the normalised ones we want.
struct OFFNutriments: Decodable, Sendable {
    let energyKcal100g: FlexibleDouble?
    let energy100g: FlexibleDouble?
    let carbohydrates100g: FlexibleDouble?
    let sugars100g: FlexibleDouble?
    let fiber100g: FlexibleDouble?
    let proteins100g: FlexibleDouble?
    let fat100g: FlexibleDouble?
    let saturatedFat100g: FlexibleDouble?
    let salt100g: FlexibleDouble?
    let sodium100g: FlexibleDouble?
    let potassium100g: FlexibleDouble?
    let calcium100g: FlexibleDouble?
    let iron100g: FlexibleDouble?
    let magnesium100g: FlexibleDouble?
    let zinc100g: FlexibleDouble?
    let vitaminA100g: FlexibleDouble?
    let vitaminC100g: FlexibleDouble?
    let vitaminD100g: FlexibleDouble?
    let vitaminE100g: FlexibleDouble?
    let vitaminB6100g: FlexibleDouble?
    let vitaminB12100g: FlexibleDouble?
    let folate100g: FlexibleDouble?

    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case energy100g = "energy_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case sugars100g = "sugars_100g"
        case fiber100g = "fiber_100g"
        case proteins100g = "proteins_100g"
        case fat100g = "fat_100g"
        case saturatedFat100g = "saturated-fat_100g"
        case salt100g = "salt_100g"
        case sodium100g = "sodium_100g"
        case potassium100g = "potassium_100g"
        case calcium100g = "calcium_100g"
        case iron100g = "iron_100g"
        case magnesium100g = "magnesium_100g"
        case zinc100g = "zinc_100g"
        case vitaminA100g = "vitamin-a_100g"
        case vitaminC100g = "vitamin-c_100g"
        case vitaminD100g = "vitamin-d_100g"
        case vitaminE100g = "vitamin-e_100g"
        case vitaminB6100g = "vitamin-b6_100g"
        case vitaminB12100g = "vitamin-b12_100g"
        case folate100g = "folates_100g"
    }
}

/// OFF occasionally returns numbers as strings. Absorb either shape.
struct FlexibleDouble: Decodable, Sendable {
    let value: Double

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let d = try? container.decode(Double.self) {
            self.value = d
        } else if let s = try? container.decode(String.self), let d = Double(s) {
            self.value = d
        } else {
            throw DecodingError.typeMismatch(
                Double.self,
                .init(codingPath: decoder.codingPath, debugDescription: "Expected number or numeric string")
            )
        }
    }
}
