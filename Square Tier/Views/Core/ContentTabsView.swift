import SwiftUI
import CoreLocation

enum AppTab: String, Hashable {
    case home
    case rewards
    case events
    case menu
    case assistant
    case snake
    case settings
}

struct CasaHomeToolbar: ViewModifier {
    @Binding var selectedTab: AppTab

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .topBarLeading) {
                HomeButtonCircle(diameter: 36) {
                    selectedTab = .home
                }
                .accessibilityLabel("Go to Home")
            }
        }
    }
}

extension View {
    func casaHomeToolbar(selectedTab: Binding<AppTab>) -> some View {
        modifier(CasaHomeToolbar(selectedTab: selectedTab))
    }
}

struct ContentTabsView: View {
    @EnvironmentObject var session: AppSession
    @EnvironmentObject var location: VenueLocationManager
    @AppStorage("cm.selectedTab") private var selectedTabRaw: String = AppTab.home.rawValue
    @AppStorage("cm.smartCheckInEnabled") private var smartCheckInEnabled: Bool = false
    @State private var lastLocationPostTs: TimeInterval = 0

    private let loyaltyAPI = LoyaltyAPI()

    private var selectedTab: Binding<AppTab> {
        Binding(
            get: { AppTab(rawValue: selectedTabRaw) ?? .home },
            set: { selectedTabRaw = $0.rawValue }
        )
    }

    private func applyUITestSelectedTabOverrideIfPresent() {
        let args = ProcessInfo.processInfo.arguments
        guard let idx = args.firstIndex(of: "-ui-testing-selected-tab"), args.indices.contains(idx + 1) else {
            return
        }

        let requestedRaw = args[idx + 1]
        if let requested = AppTab(rawValue: requestedRaw) {
            selectedTabRaw = requested.rawValue
        }
    }

    var body: some View {
        TabView(selection: selectedTab) {
            // HOME (no login required)
            NavigationStack {
                HomeView(selectedTab: selectedTab)
                    .accessibilityIdentifier("screen.home")
                    .navigationTitle("Casa Marana")
                    .navigationBarTitleDisplayMode(NavigationBarItem.TitleDisplayMode.large)
                    .casaHomeToolbar(selectedTab: selectedTab)
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
                    .accessibilityIdentifier("tab.home")
            }
            .tag(AppTab.home)

            // REWARDS (profile required)
            NavigationStack {
                RewardsRootView()
                    .accessibilityIdentifier("screen.rewards")
                    .navigationTitle("Rewards")
                    .navigationBarTitleDisplayMode(NavigationBarItem.TitleDisplayMode.large)
                    .casaHomeToolbar(selectedTab: selectedTab)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            if session.isUnlocked {
                                NavigationLink {
                                    ProfileView()
                                        .navigationTitle("Profile")
                                } label: {
                                    Image(systemName: "person.crop.circle")
                                }
                                .accessibilityLabel("Profile")
                            }
                        }
                    }
            }
            .tabItem {
                Label("Rewards", systemImage: "gift.fill")
                    .accessibilityIdentifier("tab.rewards")
            }
            .tag(AppTab.rewards)

            // EVENTS (no login required)
            NavigationStack {
                EventsView()
                    .accessibilityIdentifier("screen.events")
                    .navigationTitle("Events")
                    .navigationBarTitleDisplayMode(NavigationBarItem.TitleDisplayMode.large)
                    .casaHomeToolbar(selectedTab: selectedTab)
            }
            .tabItem {
                Label("Events", systemImage: "calendar")
                    .accessibilityIdentifier("tab.events")
            }
            .tag(AppTab.events)

            // MENU (no login required)
            NavigationStack {
                MenuView()
                    .accessibilityIdentifier("screen.menu")
                    .navigationTitle("Menu")
                    .navigationBarTitleDisplayMode(NavigationBarItem.TitleDisplayMode.large)
                    .casaHomeToolbar(selectedTab: selectedTab)
            }
            .tabItem {
                Label("Menu", systemImage: "fork.knife")
                    .accessibilityIdentifier("tab.menu")
            }
            .tag(AppTab.menu)

            // SNAKE GAME
            NavigationStack {
                SnakeGameView()
                    .navigationTitle("Snake")
                    .navigationBarTitleDisplayMode(NavigationBarItem.TitleDisplayMode.large)
                    .casaHomeToolbar(selectedTab: selectedTab)
            }
            .accessibilityIdentifier("screen.snake")
            .tabItem {
                Label("Play Snake", systemImage: "gamecontroller.fill")
                    .accessibilityIdentifier("tab.snake")
            }
            .tag(AppTab.snake)

            // SETTINGS (privacy + delete local profile)
            NavigationStack {
                SettingsView()
                    .accessibilityIdentifier("screen.settings")
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(NavigationBarItem.TitleDisplayMode.large)
                    .casaHomeToolbar(selectedTab: selectedTab)
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
                    .accessibilityIdentifier("tab.settings")
            }
            .tag(AppTab.settings)
        }
        .tint(Color.mint) // AppBrand.accent is mint
        .onAppear {
            applyUITestSelectedTabOverrideIfPresent()
            if smartCheckInEnabled {
                location.start()
            } else {
                location.stop()
            }
        }
        .onChange(of: location.authorization) { _, newValue in
            guard smartCheckInEnabled else {
                location.stop()
                return
            }

            switch newValue {
            case .authorizedAlways, .authorizedWhenInUse:
                location.start()
            default:
                location.stop()
            }
        }
        .onChange(of: smartCheckInEnabled) { _, enabled in
            if enabled {
                location.start()
            } else {
                location.stop()
            }
        }
        .onChange(of: location.lastLocationSampledAt) { _, newValue in
            guard newValue != nil else { return }
            guard smartCheckInEnabled else { return }

            guard
                let sample = location.latestSample,
                let phone = session.verifiedPhoneE164
            else { return }

            // Throttle posts to once per 5 minutes max
            let now = Date().timeIntervalSince1970
            let lastPosted = lastLocationPostTs
            if now - lastPosted > 300 {
                Task {
                    do {
                        try await loyaltyAPI.postLocationSample(
                            phoneE164: phone,
                            lat: sample.lat,
                            lon: sample.lon,
                            accuracy: sample.accuracy,
                            timestamp: sample.timestamp
                        )
                        lastLocationPostTs = now
                    } catch {
                        // Smart Check-In is best-effort.
                    }
                }
            }
        }
    }
}
