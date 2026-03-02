import SwiftUI

struct HomeView: View {
    @Binding var selectedTab: AppTab
    @Environment(\.openURL) private var openURL

    private let destinationAddress = "8225 N Courtney Page Way, Suite 191, Marana, AZ 85743"

    // Website links
    private let websiteURL = URL(string: "https://www.casamarana.com")!
    private let newsletterURL = URL(string: "https://www.casamarana.com/newsletter")!

    private var addressLine1: String {
        destinationAddress.components(separatedBy: ",").first ?? destinationAddress
    }
    private var addressLine2: String {
        let parts = destinationAddress.components(separatedBy: ",")
        guard parts.count > 1 else { return "" }
        return parts.dropFirst().joined(separator: ",").trimmingCharacters(in: .whitespaces)
    }

    private func routeToVenue() {
        let encoded = destinationAddress.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? destinationAddress
        if let url = URL(string: "https://maps.apple.com/?daddr=\(encoded)&dirflg=d") {
            openURL(url)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Hero
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome Home")
                        .font(.largeTitle)
                        .fontWeight(.black)
                        .foregroundStyle(Color.mint)

                    Text("Craft Cocktails • Draft Beer • Neapolitan Pizza")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                // Social Life
                GroupBox("Social Life") {
                    let cols = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
                    LazyVGrid(columns: cols, alignment: .leading, spacing: 10) {
                        Link(destination: URL(string: "https://www.instagram.com/casamarana/")!) {
                            CMBrandPill(text: "Instagram", systemImage: "camera")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Link(destination: URL(string: "https://www.facebook.com/casamarana/")!) {
                            CMBrandPill(text: "Facebook", systemImage: "f.circle")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Link(destination: newsletterURL) {
                            CMBrandPill(text: "Newsletter", systemImage: "envelope")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Link(destination: URL(string: "https://g.page/r/...")!) { // replace with real maps link
                            CMBrandPill(text: "Rate Us", systemImage: "star.fill")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.vertical, 2)
                }

                // Hours
                GroupBox("Hours of Operation") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Sunday – Wednesday")
                            Spacer(minLength: 8)
                            Text("10:30 AM – 10:00 PM")
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("Thursday")
                            Spacer(minLength: 8)
                            Text("10:30 AM – 12:00 AM")
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("Friday – Saturday")
                            Spacer(minLength: 8)
                            Text("10:30 AM – 2:00 AM")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // More Information
                GroupBox("More Information") {
                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(addressLine1)
                            Text(addressLine2)
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        }

                        Button {
                            routeToVenue()
                        } label: {
                            Label("Get Directions", systemImage: "car.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 4)

                        Divider().padding(.vertical, 4)

                        Link(destination: websiteURL) {
                            Label("Visit Website", systemImage: "safari")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Link(destination: URL(string: "tel:5205551234")!) { // replace w/ actual
                            Label("Call Us", systemImage: "phone")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .labelStyle(.titleAndIcon)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // About blurb (short)
                GroupBox("About Casa Marana") {
                    Text("Your local Marana bar and pizzeria—craft cocktails, rotating draft beer, great wine, and authentic Neapolitan pizza with an American twist. Built around community, quality, and a laid-back atmosphere that feels like home.")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
    }
}

// MARK: - Reusable UI Components
struct CMBrandPill: View {
    let text: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(text)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.mint.opacity(0.15))
        .foregroundStyle(Color.mint)
        .clipShape(Capsule())
    }
}
