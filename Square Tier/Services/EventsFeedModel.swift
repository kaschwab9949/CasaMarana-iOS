import Foundation
import SwiftUI
import Combine

struct CasaEvent: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let startDate: Date?
    let endDate: Date?
    let summary: String?
    let locationName: String?
    let locationAddress: String?
    let url: URL?
}

// MARK: - API Client

final class EventsFeedModel: ObservableObject {
    @Published var events: [CasaEvent] = []
    @Published var lastUpdated: Date? = nil
    @Published var error: String? = nil
    @Published var notice: String? = nil
    @Published var isLoading: Bool = false

    private let eventsURL = URL(string: "https://www.casamarana.com/events")!
    private let cacheKey = "cm.events.cache.v1"
    private let cacheDateKey = "cm.events.cacheDate.v1"

    init() {
        loadCache()
    }

    private func loadCache() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let date = UserDefaults.standard.object(forKey: cacheDateKey) as? Date else { return }
        do {
            self.events = try JSONDecoder().decode([CasaEvent].self, from: data)
            self.lastUpdated = date
        } catch {
            // ignore
        }
    }

    @MainActor
    private func saveCache(_ items: [CasaEvent]) {
        self.events = items
        self.lastUpdated = Date()
        do {
            let data = try JSONEncoder().encode(items)
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: cacheDateKey)
        } catch {
            // ignore cache write failures
        }
    }

    private static func fetchHTML(from url: URL) async throws -> (html: String, http: HTTPURLResponse) {
        var req = URLRequest(url: url)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.timeoutInterval = 25

        let (data, resp) = try await CMHTTP.session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (String(decoding: data, as: UTF8.self), http)
    }

    func refresh() async {
        // Prevent overlapping refreshes
        if await MainActor.run(body: { self.isLoading }) { return }

        await MainActor.run {
            self.isLoading = true
            self.error = nil
            self.notice = nil
        }

        defer { Task { @MainActor in self.isLoading = false } }

        do {
            // 1) Fetch the listing page
            let (listingHTML, listingHTTP) = try await Self.fetchHTML(from: eventsURL)
            guard (200..<300).contains(listingHTTP.statusCode) else {
                await MainActor.run {
                    self.error = "Failed to load events list (HTTP \(listingHTTP.statusCode))"
                    self.lastUpdated = Date()
                }
                return
            }

            // 2) Extract event page URLs
            let eventURLs = Self.extractEventURLs(from: listingHTML)
            guard !eventURLs.isEmpty else {
                await MainActor.run {
                    self.events = []
                    self.lastUpdated = Date()
                }
                return
            }

            // 3) Fetch each event page and parse JSON-LD (concurrency-limited)
            let urlsToFetch = Array(eventURLs.prefix(25))
            let maxConcurrentFetches = 6

            let parsed: [CasaEvent] = await withTaskGroup(of: [CasaEvent].self, returning: [CasaEvent].self) { group in
                func addTask(for url: URL) {
                    group.addTask {
                        await Self.fetchOneEventPage(url: url)
                    }
                }

                var results: [CasaEvent] = []
                var index = 0

                // Add initial batch
                while index < min(maxConcurrentFetches, urlsToFetch.count) {
                    addTask(for: urlsToFetch[index])
                    index += 1
                }

                // Wait for one to finish, add the next, repeat
                while let found = await group.next() {
                    results.append(contentsOf: found)
                    if index < urlsToFetch.count {
                        addTask(for: urlsToFetch[index])
                        index += 1
                    }
                }
                return results
            }

            if Task.isCancelled {
                return
            }

            // 4) De-dupe by id, filter to upcoming-ish, and sort by date
            var unique: [String: CasaEvent] = [:]
            for e in parsed { unique[e.id] = e }

            let now = Date()
            let upcoming = unique.values.filter { e in
                if let end = e.endDate { return end >= now }
                if let start = e.startDate {
                    // keep ongoing/recent events briefly
                    return start.addingTimeInterval(3600 * 4) >= now
                }
                // If it has NO date, keep it (Squarespace TBDs)
                return true
            }

            let sorted = upcoming.sorted { a, b in
                switch (a.startDate, b.startDate) {
                case let (d1?, d2?): return d1 < d2
                case (nil, _): return false // put TBD at end
                case (_, nil): return true
                }
            }

            await MainActor.run {
                // If we found NO dates on some events, add a helpful notice.
                let missingDates = sorted.filter { $0.startDate == nil }.count
                if missingDates == sorted.count {
                    self.notice = "We found events, but no clear dates for them. Tap each event for details."
                } else if missingDates > 0 {
                    self.notice = "Some events don’t include a readable date/time yet and will show as “Date TBD”."
                }
            }

            saveCache(sorted)
        } catch {
            await MainActor.run {
                if let urlErr = error as? URLError {
                    self.error = "Network error: \(urlErr.code) — \(urlErr.localizedDescription)"
                } else {
                    self.error = "Error: \(error.localizedDescription)"
                }
                self.lastUpdated = Date()
            }
        }
    }

    // MARK: - Fetch one event page
    private static func fetchOneEventPage(url: URL) async -> [CasaEvent] {
        do {
            let (html, http) = try await Self.fetchHTML(from: url)
            guard (200..<300).contains(http.statusCode) else { return [] }

            // Extract JSON-LD blocks from each event page
            let regex = try NSRegularExpression(pattern: "<script type=\"application/ld\\+json\">([\\s\\S]*?)</script>", options: .caseInsensitive)
            let ns = html as NSString
            let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length))

            var found: [CasaEvent] = []
            for m in matches {
                guard m.numberOfRanges >= 2 else { continue }
                let block = ns.substring(with: m.range(at: 1))
                guard let data = block.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: data) else { continue }
                found.append(contentsOf: Self.parseEvents(from: obj))
            }

            guard !found.isEmpty else { return [] }

            let pageURL = url.absoluteString
            let best: CasaEvent =
                found.first(where: { $0.url?.absoluteString == pageURL }) ??
                found.first(where: {
                    guard let u = $0.url?.absoluteString else { return false }
                    return pageURL.contains(u) || u.contains(pageURL)
                }) ??
                found.first!

            // Sometimes JSON-LD is missing the summary entirely.
            // When it does, extract it from the HTML (best effort).
            let htmlSummary = extractEventSummary(from: html)

            let (extractedStart, extractedEnd) = extractStartEnd(from: html)

            // Overwrite JSON-LD values with HTML-extracted values as they are typically more correct visually.
            let normalized = CasaEvent(
                id: url.path,
                title: extractH1Title(from: html) ?? best.title,
                startDate: extractedStart ?? best.startDate,
                endDate: extractedEnd ?? best.endDate,
                summary: htmlSummary ?? best.summary,
                locationName: best.locationName,
                locationAddress: best.locationAddress,
                url: url
            )
            return [normalized]
        } catch {
            return []
        }
    }

    // MARK: - HTML Extractors (Squarespace pages)

    private static func extractH1Title(from html: String) -> String? {
        // Squarespace event pages show the true title immediately after “Back to All Events”.
        let text = stripHTML(html)
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let junkPrefixes = [
            "Casa Marana",
            "CART",
            "Back to All Events",
            "Home", "Menu", "Events", "Contact", "Newsletter"
        ]

        if let title = lines.first(where: { line in
            !junkPrefixes.contains(where: { line.hasPrefix($0) })
        }) {
            return decodeHTMLEntities(title)
        }

        return nil
    }

    private static func extractEventSummary(from html: String) -> String? {
        // Build a lightweight text view of the page and return the first meaningful paragraph after the calendar links.
        let text = stripHTML(html)
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var foundCalendarLinks = false
        var cleaned: [String] = []

        for line in lines {
            if line.contains("Google Calendar") || line.contains("ICS") {
                foundCalendarLinks = true
                continue
            }
            if foundCalendarLinks {
                if !line.isEmpty { cleaned.append(String(line)) }
            }
        }

        // If we found the start of the article bounds, the next 2-3 chunks are the description.
        if !cleaned.isEmpty {
            let start = cleaned.first!.contains("Posted in") ? 1 : 0
            if start < cleaned.count {
                let snippet = cleaned[start...].prefix(3).joined(separator: " ")
                return snippet.isEmpty ? nil : snippet
            }
        }

        return cleaned.prefix(3).joined(separator: " ")
    }

    private static func extractStartEnd(from html: String) -> (Date?, Date?) {
        // Squarespace event pages display date line and time range in plain text.
        let text = stripHTML(html)

        // Date like: "Wednesday, March 19, 2025"
        let dateRegex = try! NSRegularExpression(pattern: "(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday),\\s(January|February|March|April|May|June|July|August|September|October|November|December)\\s\\d{1,2},\\s\\d{4}")
        let dateMatch = dateRegex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
        guard let dateRange = dateMatch?.range else { return (nil, nil) }
        let dateStr = (text as NSString).substring(with: dateRange)

        // Times like: "6:30 PM", "8:30 PM"
        let timeRegex = try! NSRegularExpression(pattern: "(\\d{1,2}:\\d{2}\\s(?:AM|PM))")
        let timeMatches = timeRegex.matches(in: text, range: NSRange(text.startIndex..., in: text))

        let ns = text as NSString
        let times = timeMatches.map { m -> String in
            return ns.substring(with: m.range(at: 1))
        }

        let startTime = times.first
        let endTime = times.dropFirst().first

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")

        if let startTime {
            df.dateFormat = "EEEE, MMMM d, yyyy h:mm a"
            let start = df.date(from: "\(dateStr) \(startTime)")
            if let endTime {
                let end = df.date(from: "\(dateStr) \(endTime)")
                return (start, end)
            }
            return (start, nil)
        }

        return (nil, nil)
    }

    private static func stripHTML(_ s: String) -> String {
        var s = s
        // Remove style and script completely
        s = s.replacingOccurrences(of: "<style[^>]*>([\\s\\S]*?)</style>", with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: "<script[^>]*>([\\s\\S]*?)</script>", with: " ", options: .regularExpression)

        // Replace tags with newlines
        s = s.replacingOccurrences(of: "<[^>]+>", with: "\n", options: .regularExpression)
        s = s.replacingOccurrences(of: "&nbsp;", with: " ")
        s = s.replacingOccurrences(of: "\u{00a0}", with: " ")
        return s
    }

    private static func decodeHTMLEntities(_ s: String) -> String {
        guard let data = s.data(using: .utf8) else { return s }
        if let attr = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue],
            documentAttributes: nil
        ) {
            return attr.string
        }
        return s
    }

    private static func extractEventURLs(from listingHTML: String) -> [URL] {
        // Squarespace event listings vary by template. Some include dates in the path, others don't.
        // Look for links to paths that start with /events/ or /botanica-events/
        // Only casamarana.com absolute paths, or root-relative paths.

        let regex = try! NSRegularExpression(pattern: "href\\s*=\\s*\"([^\"]+)\"", options: .caseInsensitive)

        let ns = listingHTML as NSString
        let matches = regex.matches(in: listingHTML, range: NSRange(location: 0, length: ns.length))

        var seen = Set<String>()
        var urls: [URL] = []

        func addURLString(_ raw: String) {
            let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !s.isEmpty else { return }

            // Normalize to absolute URL string on casamarana.com
            let abs: String
            if s.hasPrefix("/") {
                abs = "https://www.casamarana.com" + s
            } else if s.hasPrefix("https://www.casamarana.com/") || s.hasPrefix("http://www.casamarana.com/") || s.hasPrefix("https://casamarana.com/") {
                abs = s
            } else {
                return // skip external
            }

            guard let u = URL(string: abs) else { return }
            let lowerPath = u.path.lowercased()

            // Filter out non-event links (like the top navigation Calendar link)
            guard lowerPath.hasPrefix("/events/") || lowerPath.hasPrefix("/botanica-events/") else { return }

            // Skip the calendar aggregate view
            if lowerPath.hasSuffix("/calendar") { return }

            // Remove fragments and tracking query from the de-dupe key
            var comps = URLComponents(url: u, resolvingAgainstBaseURL: false)
            comps?.fragment = nil
            // Keep path-only for dedupe; query often contains tracking
            comps?.query = nil
            let key = comps?.url?.absoluteString ?? u.absoluteString

            guard !seen.contains(key) else { return }
            seen.insert(key)
            urls.append(comps?.url ?? u)
        }

        for m in matches {
            guard m.numberOfRanges >= 2 else { continue }
            let href = ns.substring(with: m.range(at: 1))
            addURLString(href)
        }

        return urls
    }

    private static func parseDate(_ s: String?) -> Date? {
        guard let s else { return nil }
        let iso = ISO8601DateFormatter()
        let isoFrac = ISO8601DateFormatter()
        isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return isoFrac.date(from: s) ?? iso.date(from: s)
    }

    private static func parseEvents(from obj: Any) -> [CasaEvent] {
        var dicts: [[String: Any]] = []

        func walk(_ any: Any) {
            if let d = any as? [String: Any] {
                if let type = d["@type"] {
                    let ts = (type as? [String]) ?? [(type as? String) ?? ""]
                    if ts.contains(where: { $0.lowercased() == "event" || $0.lowercased() == "educationevent" }) {
                        dicts.append(d)
                    }
                }
                for v in d.values { walk(v) }
            } else if let a = any as? [Any] {
                for v in a { walk(v) }
            }
        }

        walk(obj)

        return dicts.compactMap { d in
            let title = (d["name"] as? String) ?? "Event"
            let start = Self.parseDate(d["startDate"] as? String)
            let end = Self.parseDate(d["endDate"] as? String)
            let summary = d["description"] as? String

            var locName: String? = nil
            var locAddr: String? = nil
            if let loc = d["location"] as? [String: Any] {
                locName = loc["name"] as? String
                if let address = loc["address"] as? [String: Any] {
                    let street = address["streetAddress"] as? String ?? ""
                    let city = address["addressLocality"] as? String ?? ""
                    let region = address["addressRegion"] as? String ?? ""
                    let components = [street, city, region].filter { !$0.isEmpty }
                    if !components.isEmpty {
                        locAddr = components.joined(separator: ", ")
                    }
                } else if let addressStr = loc["address"] as? String {
                    locAddr = addressStr
                }
            }

            var url: URL? = nil
            if let str = d["url"] as? String {
                url = URL(string: str)
            }

            return CasaEvent(
                id: (d["@id"] as? String) ?? UUID().uuidString,
                title: title,
                startDate: start,
                endDate: end,
                summary: summary,
                locationName: locName,
                locationAddress: locAddr,
                url: url
            )
        }
    }
}
