import Foundation
import CoreLocation
import Combine

struct VenueLocationSample {
    let lat: Double
    let lon: Double
    let accuracy: Double
    let timestamp: TimeInterval

    var capturedAt: Date {
        Date(timeIntervalSince1970: timestamp)
    }
}

// MARK: - Location (Smart Check-In)
@MainActor
final class VenueLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    nonisolated static let venueCoordinate = CLLocationCoordinate2D(latitude: 32.3568946, longitude: -111.0952091)
    
    private let manager = CLLocationManager()
    
    @Published var authorization: CLAuthorizationStatus = .notDetermined
    @Published var distanceToVenueMeters: Double? = nil
    @Published var isWithinVenueRadius: Bool = false
    @Published var configurationError: String? = nil
    
    @Published var lastLocationSampledAt: Date? = nil
    @Published var latestSample: VenueLocationSample? = nil

    private var hasWhenInUseUsageDescription: Bool {
        guard let s = Bundle.main.object(forInfoDictionaryKey: "NSLocationWhenInUseUsageDescription") as? String else {
            return false
        }
        return !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    override init() {
        super.init()
        manager.delegate = self
        // Foreground check-in does not need navigation-grade precision.
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        // Only wake us if the user moves > 50 meters
        manager.distanceFilter = 50
        
        self.authorization = manager.authorizationStatus

        // Clear any legacy on-device location persistence keys.
        UserDefaults.standard.removeObject(forKey: "cm.lastLocationSample.v1")
        UserDefaults.standard.removeObject(forKey: "cm.locationLog.v1")
        UserDefaults.standard.removeObject(forKey: "cm.lastLocationSample.lastPostedTs.v1")
    }

    private func retainSample(_ loc: CLLocation) {
        latestSample = VenueLocationSample(
            lat: loc.coordinate.latitude,
            lon: loc.coordinate.longitude,
            accuracy: loc.horizontalAccuracy,
            timestamp: loc.timestamp.timeIntervalSince1970
        )
        lastLocationSampledAt = Date()
    }

    /// Request permission if not yet determined, then start updates.
    /// Convenience alias so callers don't need to know the internal flow.
    func requestPermission() {
        start()
    }

    func start() {
        guard hasWhenInUseUsageDescription else {
            configurationError = "Missing NSLocationWhenInUseUsageDescription in Info.plist. Add it to enable location."
            return
        }
        configurationError = nil

        let status = manager.authorizationStatus
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
            return
        }

        if status == .authorizedAlways || status == .authorizedWhenInUse {
            manager.allowsBackgroundLocationUpdates = false
            manager.showsBackgroundLocationIndicator = false
            manager.startUpdatingLocation()
            return
        }

        // Denied/restricted: stop and clear.
        stop()
        distanceToVenueMeters = nil
        isWithinVenueRadius = false
    }
    func stop() {
        manager.stopUpdatingLocation()
        // Keep this off unless actively tracking with Always permission.
        manager.allowsBackgroundLocationUpdates = false
        manager.showsBackgroundLocationIndicator = false
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorization = manager.authorizationStatus
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                self.start()
            default:
                self.stop()
                self.distanceToVenueMeters = nil
                self.isWithinVenueRadius = false
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        
        Task { @MainActor in
            // Save the last sample so the app can send it
            self.retainSample(loc)
            
            let venueLoc = CLLocation(latitude: Self.venueCoordinate.latitude, longitude: Self.venueCoordinate.longitude)
            let d = loc.distance(from: venueLoc)
            self.distanceToVenueMeters = d
            self.isWithinVenueRadius = d <= 150
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // App still works without location.
    }
}
