import SwiftUI
import Foundation

// Models

/// Represents a meal in the Dessert category.
struct Meal: Identifiable, Codable {
    let id: String
    let name: String
    let thumbnail: String

    // Define the coding keys to map JSON keys to Swift properties
    enum CodingKeys: String, CodingKey {
        case id = "idMeal"
        case name = "strMeal"
        case thumbnail = "strMealThumb"
    }
}

/// Represents detailed information about a meal.
struct MealDetails: Codable {
    let id: String
    let name: String
    let instructions: String
    let ingredients: [String: String]
    let youtubeURL: String?
    let imageSource: String?
    let linkSource: String?

    // Define the coding keys to map JSON keys to Swift properties
    enum CodingKeys: String, CodingKey {
        case id = "idMeal"
        case name = "strMeal"
        case instructions = "strInstructions"
        case youtubeURL = "strYoutube"
        case imageSource = "strMealThumb"
        case linkSource = "strSource"
    }

    /// Custom initializer to decode meal details and extract ingredients.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        instructions = try container.decode(String.self, forKey: .instructions)
        youtubeURL = try container.decodeIfPresent(String.self, forKey: .youtubeURL)
        imageSource = try container.decodeIfPresent(String.self, forKey: .imageSource)
        linkSource = try container.decodeIfPresent(String.self, forKey: .linkSource)
        
        // Extract ingredients and measurements
        var ingredientsDictionary = [String: String]()
        let json = try decoder.singleValueContainer().decode([String: String?].self)
        for index in 1...20 {
            if let ingredient = json["strIngredient\(index)"] ?? nil,
               let measure = json["strMeasure\(index)"] ?? nil,
               !ingredient.isEmpty, !measure.isEmpty {
                ingredientsDictionary[ingredient] = measure
            }
        }
        self.ingredients = ingredientsDictionary
    }
}


// Network Manager

/// Manages network requests to fetch data from the MealDB API.
class NetworkManager {
    static let shared = NetworkManager()
    private let baseURL = "https://themealdb.com/api/json/v1/1"
    
    private init() {}

    /// Fetches a list of dessert meals.
    func fetchDesserts() async throws -> [Meal] {
        let urlString = "\(baseURL)/filter.php?c=Dessert"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        let (dataResponse, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(MealResponse.self, from: dataResponse)
        return response.meals.sorted { $0.name < $1.name }
    }

    /// Fetches details of a specific meal by its ID.
    func fetchMealDetails(id: String) async throws -> MealDetails {
        let urlString = "\(baseURL)/lookup.php?i=\(id)"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        let (dataResponse, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(MealDetailsResponse.self, from: dataResponse)
        guard let mealDetails = response.meals.first else {
            throw URLError(.badServerResponse)
        }
        return mealDetails
    }
}

/// Represents the response for fetching meals.
struct MealResponse: Codable {
    let meals: [Meal]
}

/// Represents the response for fetching meal details.
struct MealDetailsResponse: Codable {
    let meals: [MealDetails]
}

// Views

/// The main view displaying a list of dessert meals.
struct ContentView: View {
    @State private var meals = [Meal]()
    @State private var isLoading = true

    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5, anchor: .center)
                } else {
                    List(meals) { meal in
                        NavigationLink(destination: MealDetailView(mealID: meal.id)) {
                            HStack {
                                AsyncImage(url: URL(string: meal.thumbnail)) { image in
                                    image.resizable()
                                } placeholder: {
                                    ProgressView()
                                }
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                                Text(meal.name)
                                    .font(.headline)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Desserts")
            .onAppear {
                Task {
                    do {
                        meals = try await NetworkManager.shared.fetchDesserts()
                        isLoading = false
                    } catch {
                        print("Error fetching meals: \(error)")
                        isLoading = false
                    }
                }
            }
        }
    }
}

/// A view displaying details of a specific meal.

struct MealDetailView: View {
    let mealID: String
    @State private var mealDetails: MealDetails?
    @State private var isLoading = true
    @State private var ingredientChecks: [String: Bool] = [:]

    var body: some View {
        ScrollView {
            if let mealDetails = mealDetails {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Spacer()
                        Text(mealDetails.name)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .padding(.top)

                    if let imageUrl = mealDetails.imageSource, let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { image in
                            image.resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 15))
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(maxWidth: .infinity)
                    }

                    Text("Ingredients")
                        .font(.title2.bold())
                        .padding(.top)
                    ForEach(mealDetails.ingredients.sorted(by: >), id: \.key) { ingredient, measure in
                        HStack(alignment: .top) {
                            Button(action: {
                                ingredientChecks[ingredient, default: false].toggle()
                            }) {
                                Image(systemName: ingredientChecks[ingredient, default: false] ? "checkmark.circle.fill" : "circle")
                            }
                            Text("\(ingredient): \(measure)")
                        }
                    }

                    Text("Instructions")
                        .font(.title2.bold())
                        .padding(.top)
                    Text(mealDetails.instructions)
                        .fixedSize(horizontal: false, vertical: true)

                    if let youtubeURL = mealDetails.youtubeURL, let url = URL(string: youtubeURL) {
                        Link(destination: url) {
                            HStack {
                                Image(systemName: "play.rectangle")
                                Text("Watch on YouTube")
                            }
                        }
                        .padding(.top)
                    }

                    if let linkSource = mealDetails.linkSource, let url = URL(string: linkSource) {
                        Link("Source", destination: url)
                            .padding(.top)
                    }
                }
                .padding()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text(mealDetails.name)
                            .font(.headline)
                    }
                }
                .onAppear {
                    for ingredient in mealDetails.ingredients.keys {
                        ingredientChecks[ingredient] = false
                    }
                }
            } else if isLoading {
                ProgressView()
            } else {
                Text("Failed to load meal details")
            }
        }
        .onAppear {
            Task {
                do {
                    mealDetails = try await NetworkManager.shared.fetchMealDetails(id: mealID)
                    isLoading = false
                } catch {
                    print("Error fetching meal details: \(error)")
                    isLoading = false
                }
            }
        }
    }
}






struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
