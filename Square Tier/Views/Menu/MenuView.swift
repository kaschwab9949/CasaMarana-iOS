import SwiftUI
import Combine

struct MenuItem: Identifiable {
    let id: String
    let name: String
    let description: String
    let price: String
    let category: String
    let tags: [String]
    let sectionHint: String?

    init(
        id: String,
        name: String,
        description: String,
        price: String,
        category: String,
        tags: [String],
        sectionHint: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.price = price
        self.category = category
        self.tags = tags
        self.sectionHint = sectionHint
    }
}

@MainActor
final class MenuData: ObservableObject {
    enum DataSource {
        case square
        case seed
    }

    @Published var allItems: [MenuItem] = SquareMenuSeed.items
    @Published var isLoading = false
    @Published var notice: String? = nil
    @Published var errorText: String? = nil
    @Published var dataSource: DataSource = .seed

    private let api = SquareMenuAPI()

    init() {
        notice = seedNotice
    }

    private var seedNotice: String {
        "Showing fallback menu snapshot (\(SquareMenuSeed.generatedAtDisplay))."
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        errorText = nil

        do {
            let remoteItems = try await api.fetchMenu()
            if !remoteItems.isEmpty {
                allItems = remoteItems
                notice = "Menu updated from Square."
                dataSource = .square
            } else {
                notice = "Square returned no menu items. Showing fallback menu snapshot."
                dataSource = .seed
            }
            isLoading = false
        } catch {
            errorText = UserFacingError.message(
                for: error,
                context: .generic,
                fallback: "Could not refresh menu right now."
            )
            notice = dataSource == .square ? "Showing last successful menu update." : seedNotice
            isLoading = false
        }
    }
}

struct MenuView: View {
    @StateObject private var menuData = MenuData()
    @State private var searchText = ""
    @State private var selectedSection: MenuSection = .food
    @State private var searchAllSections = false

    private var sectionScopedItems: [MenuItem] {
        if searchAllSections {
            return menuData.allItems
        }
        return menuData.allItems.filter { MenuCategoryMapping.classify($0) == selectedSection }
    }

    private var filteredItems: [MenuItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return sectionScopedItems }
        return sectionScopedItems.filter { item in
            item.name.localizedCaseInsensitiveContains(query) ||
            item.category.localizedCaseInsensitiveContains(query) ||
            item.description.localizedCaseInsensitiveContains(query) ||
            item.tags.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    private var visibleCategories: [String] {
        let effectiveSection: MenuSection = searchAllSections ? .other : selectedSection
        return MenuCategoryMapping.orderedCategories(in: effectiveSection, items: filteredItems)
    }

    private func items(in category: String) -> [MenuItem] {
        filteredItems
            .filter { $0.category == category }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var showsOperationalFoodEmptyState: Bool {
        !menuData.isLoading
            && !searchAllSections
            && selectedSection == .food
            && searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && filteredItems.isEmpty
    }

    var body: some View {
        List {
            Section {
                Picker("Menu Section", selection: $selectedSection) {
                    Text(MenuSection.food.title).tag(MenuSection.food)
                    Text(MenuSection.drinks.title).tag(MenuSection.drinks)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("menu.sectionPicker")

                Toggle("Search all sections", isOn: $searchAllSections)
                    .font(.footnote)
                    .accessibilityIdentifier("menu.allSectionsToggle")

                if menuData.isLoading {
                    HStack {
                        ProgressView()
                        Text("Refreshing menu…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityIdentifier("menu.loadingText")
                }

                if let errorText = menuData.errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("menu.errorText")
                }

                if let notice = menuData.notice {
                    Text(notice)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("menu.noticeText")
                }
            }

            if showsOperationalFoodEmptyState {
                Section {
                    Text("No Food items are currently published in the live menu. Verify category mapping in Square and pull to refresh.")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                        .accessibilityIdentifier("menu.foodEmptyOperationalText")
                }
            } else if filteredItems.isEmpty {
                Section {
                    Text("No menu results found for \"\(searchText)\".")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                        .accessibilityIdentifier("menu.noResultsText")
                }
            } else {
                ForEach(visibleCategories, id: \.self) { category in
                    let categoryItems = items(in: category)
                    
                    if !categoryItems.isEmpty {
                        Section(header: Text(category)) {
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

                                    if !item.description.isEmpty {
                                        Text(item.description)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .accessibilityIdentifier("screen.menu")
        .searchable(text: $searchText, prompt: "Search pizzas, drinks, etc.")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await menuData.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(menuData.isLoading)
                .accessibilityIdentifier("menu.refreshButton")
            }
        }
        .task {
            await menuData.refresh()
        }
    }
}
