import SwiftUI
import Combine

enum MenuCategory: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    
    case shareables = "Shareables"
    case neapolitanPizza = "Neapolitan Pizza"
    case signatureCocktails = "Signature Cocktails"
    case draftBeer = "Draft Beer"
    case wine = "Wine"
}

struct MenuItem: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let price: String
    let category: MenuCategory
    let tags: [String]
}

final class MenuData: ObservableObject {
    @Published var allItems: [MenuItem] = [
        // Shareables
        MenuItem(name: "Pretzel Bites", description: "Warm pretzel pieces served with house-made beer cheese and spicy mustard.", price: "$10", category: .shareables, tags: ["vegetarian", "cheese", "snack"]),
        MenuItem(name: "Caprese Skewers", description: "Cherry tomatoes, fresh mozzarella balls, and basil drizzled with balsamic glaze.", price: "$12", category: .shareables, tags: ["vegetarian", "fresh", "gluten-free"]),
        MenuItem(name: "Garlic Knots", description: "Oven-baked dough knots tossed in garlic butter and parmesan.", price: "$8", category: .shareables, tags: ["vegetarian", "garlic", "bread"]),
        
        // Neapolitan Pizza
        MenuItem(name: "Margherita", description: "San Marzano tomato sauce, fresh mozzarella, basil, and a drizzle of extra virgin olive oil.", price: "$16", category: .neapolitanPizza, tags: ["classic", "vegetarian", "pizza"]),
        MenuItem(name: "Spicy Soppressata", description: "Tomato base, mozzarella, spicy soppressata, hot honey drizzle, and fresh basil.", price: "$18", category: .neapolitanPizza, tags: ["spicy", "meat", "pizza"]),
        MenuItem(name: "Truffle Mushroom", description: "White base, roasted wild mushrooms, mozzarella, truffle oil, and thyme.", price: "$19", category: .neapolitanPizza, tags: ["truffle", "vegetarian", "pizza"]),
        MenuItem(name: "Prosciutto & Arugula", description: "Mozzarella base, baked then topped with fresh arugula, prosciutto, and shaved parmesan.", price: "$20", category: .neapolitanPizza, tags: ["meat", "greens", "pizza"]),
        
        // Signature Cocktails
        MenuItem(name: "Marana Mule", description: "Vodka, fresh lime juice, ginger beer, splash of prickly pear syrup.", price: "$12", category: .signatureCocktails, tags: ["fruity", "refreshing", "cocktail"]),
        MenuItem(name: "Smoked Old Fashioned", description: "Bourbon, simple syrup, Angostura bitters, smoked with cherry wood.", price: "$14", category: .signatureCocktails, tags: ["strong", "smoky", "cocktail"]),
        MenuItem(name: "Desert Paloma", description: "Tequila, grapefruit soda, lime, tajin rim.", price: "$11", category: .signatureCocktails, tags: ["citrus", "tequila", "refreshing"]),
        
        // Draft Beer (Rotating Examples)
        MenuItem(name: "Dragoon IPA", description: "Strong, heavily-hopped West Coast style IPA from Tucson, AZ. (7.3% ABV)", price: "$7", category: .draftBeer, tags: ["ipa", "hoppy", "local"]),
        MenuItem(name: "Huss Scottsdale Blonde", description: "Smooth, slightly sweet blonde ale. (4.7% ABV)", price: "$7", category: .draftBeer, tags: ["blonde", "light", "local"]),
        MenuItem(name: "Pueblo Vida Hefeweizen", description: "Bavarian-style wheat beer with notes of banana and clove. (5.2% ABV)", price: "$8", category: .draftBeer, tags: ["wheat", "german-style", "local"]),
        
        // Wine
        MenuItem(name: "House Cabernet Sauvignon", description: "California - Rich and full-bodied with notes of dark blackberry.", price: "$9/gl", category: .wine, tags: ["red", "full-bodied"]),
        MenuItem(name: "House Pinot Grigio", description: "Italy - Crisp and refreshing with hints of green apple.", price: "$9/gl", category: .wine, tags: ["white", "crisp"]),
        MenuItem(name: "Rosé", description: "France - Dry, notes of strawberry and watermelon.", price: "$10/gl", category: .wine, tags: ["rose", "dry"])
    ]
}

struct MenuView: View {
    @StateObject private var menuData = MenuData()
    @State private var searchText = ""
    
    // Derived property to filter items based on search text
    private var filteredItems: [MenuItem] {
        if searchText.isEmpty {
            return menuData.allItems
        } else {
            return menuData.allItems.filter { item in
                item.name.localizedCaseInsensitiveContains(searchText) ||
                item.description.localizedCaseInsensitiveContains(searchText) ||
                item.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
    }
    
    // Group filtered items by category for sections
    private func items(in category: MenuCategory) -> [MenuItem] {
        filteredItems.filter { $0.category == category }
    }

    var body: some View {
        List {
            // Check if there are results
            if filteredItems.isEmpty {
                Section {
                    Text("No results found for \"\(searchText)\".")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                        .accessibilityIdentifier("menu.noResultsText")
                }
            } else {
                ForEach(MenuCategory.allCases) { category in
                    let categoryItems = items(in: category)
                    
                    if !categoryItems.isEmpty {
                        Section(header: Text(category.rawValue)) {
                            ForEach(categoryItems) { item in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(alignment: .top) {
                                        Text(item.name)
                                            .font(.headline)
                                        Spacer()
                                        Text(item.price)
                                            .font(.subheadline)
                                            .bold()
                                    }
                                    
                                    Text(item.description)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .accessibilityIdentifier("menu.list")
        .searchable(text: $searchText, prompt: "Search pizzas, drinks, etc.")
    }
}
