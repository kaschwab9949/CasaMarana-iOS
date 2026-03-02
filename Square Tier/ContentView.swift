import SwiftUI

// MARK: - App Root

struct ContentView: View {
    @StateObject private var session = AppSession()
    @StateObject private var location = VenueLocationManager()

    var body: some View {
        ContentTabsView()
            .environmentObject(session)
            .environmentObject(location)
    }
}

#Preview {
    ContentView()
}
