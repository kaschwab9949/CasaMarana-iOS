import SwiftUI
import MapKit

struct EventsView: View {
    @StateObject private var model = EventsFeedModel()
    @State private var refreshTimer: Timer?

    // refresh every 15 minutes while visible
    private let refreshInterval: TimeInterval = 15 * 60

    var body: some View {
        List {
            Section {
                if let n = model.notice {
                    Label(n, systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.blue)
                }

                if let err = model.error {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("events.errorText")
                }

                if let updated = model.lastUpdated {
                    Text("Last updated \(updated.formatted(date: .abbreviated, time: .shortened))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("events.lastUpdatedText")
                }

#if DEBUG
                if model.diagnostics.linksFound > 0 {
                    Text("Diagnostics: links \(model.diagnostics.linksFound), pages \(model.diagnostics.pagesParsed), events \(model.diagnostics.eventsProduced)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
#endif
            }

            if model.events.isEmpty {
                Section {
                    if model.isLoading {
                        HStack {
                            Spacer()
                            ProgressView("Loading…")
                                .padding()
                            Spacer()
                        }
                    } else if model.error == nil {
                        Text("No events are currently published.")
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("events.emptyStateText")
                    } else {
                        Text("Events are temporarily unavailable.")
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("events.emptyUnavailableText")
                    }
                }
            } else {
                Section("Events") {
                    ForEach(model.events) { e in
                        NavigationLink {
                            EventDetailView(event: e)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(e.title)
                                    .font(.headline)

                                Text(eventDateLine(e))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                if let s = e.summary, !s.isEmpty {
                                    Text(s)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }

                                if let location = locationLine(e), !location.isEmpty {
                                    HStack(spacing: 4) {
                                        Image(systemName: "mappin.and.ellipse")
                                        Text(location)
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .tint(CMBrand.accent)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await model.refresh(force: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(model.isLoading)
                .accessibilityIdentifier("events.refreshButton")
            }
        }
        .task {
            // Initial load if empty
            if model.events.isEmpty || model.lastUpdated == nil {
                await model.refresh(force: true)
            }
        }
        .onAppear {
            // Set up background refresh timer
            refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { _ in
                guard !model.isLoading else { return }
                Task { await model.refresh() }
            }
        }
        .onDisappear {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }

    private func eventDateLine(_ e: CasaEvent) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short

        if let s = e.startDate, let end = e.endDate {
            return "\(df.string(from: s)) – \(df.string(from: end))"
        } else if let s = e.startDate {
            return df.string(from: s)
        } else {
            return "Date TBD"
        }
    }

    private func locationLine(_ event: CasaEvent) -> String? {
        [event.locationName, event.locationAddress]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " • ")
            .nilIfEmpty
    }
}

struct EventDetailView: View {
    let event: CasaEvent

    @State private var showSafari = false

    private var mapsURL: URL? {
        let q = [event.locationName, event.locationAddress]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        guard !q.isEmpty else { return nil }
        guard let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: "https://maps.apple.com/?q=\(encoded)")
    }

    var body: some View {
        List {
            Section {
                Text(event.title)
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(dateString)
                    .foregroundStyle(.secondary)

                if let loc = locationString {
                    HStack(alignment: .top) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(.secondary)
                        Text(loc)
                    }
                }
            }

            if let s = event.summary, !s.isEmpty {
                Section("About") {
                    Text(s)
                        .font(.body)
                }
            }

            if let u = event.url {
                Section {
                    Button {
                        showSafari = true
                    } label: {
                        Label("View on CasaMarana.com", systemImage: "safari")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .sheet(isPresented: $showSafari) {
                        SafariView(url: u)
                            .ignoresSafeArea()
                    }
                }
            }

            if let mapsURL {
                Section {
                    Link(destination: mapsURL) {
                        Label("Directions", systemImage: "map")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Event")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var dateString: String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short

        if let s = event.startDate, let end = event.endDate {
            return "\(df.string(from: s)) – \(df.string(from: end))"
        } else if let s = event.startDate {
            return df.string(from: s)
        } else {
            return "Date TBD"
        }
    }

    private var locationString: String? {
        [event.locationName, event.locationAddress].compactMap { $0 }.joined(separator: " • ")
            .nilIfEmpty
    }
}

// Helper
extension String {
    var nilIfEmpty: String? {
        self.isEmpty ? nil : self
    }
}
