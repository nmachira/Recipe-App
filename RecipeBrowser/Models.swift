import Foundation

struct Meal: Identifiable, Codable {
    let id: String
    let name: String
    let thumbnail: String

    enum CodingKeys: String, CodingKey {
        case id = "idMeal"
        case name = "strMeal"
        case thumbnail = "strMealThumb"
    }
}

struct MealDetails: Codable {
    let id: String
    let name: String
    let instructions: String
    let ingredients: [String: String]

    enum CodingKeys: String, CodingKey {
        case id = "idMeal"
        case name = "strMeal"
        case instructions = "strInstructions"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        instructions = try container.decode(String.self, forKey: .instructions)
        
        var ingredients = [String: String]()
        for index in 1...20 {
            let ingredientKey = "strIngredient\(index)"
            let measureKey = "strMeasure\(index)"
            if let ingredient = try container.decodeIfPresent(String.self, forKey: CodingKeys(stringValue: ingredientKey)!),
               let measure = try container.decodeIfPresent(String.self, forKey: CodingKeys(stringValue: measureKey)!),
               !ingredient.isEmpty, !measure.isEmpty {
                ingredients[ingredient] = measure
            }
        }
        self.ingredients = ingredients
    }
}
