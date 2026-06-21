import CoreLocation
import Foundation

enum LocationProviderError: LocalizedError, Equatable, Sendable {
    case denied
    case restricted
    case unavailable
    case timedOut

    var errorDescription: String? {
        switch self {
        case .denied:
            "Location access is denied. Enable location in Settings for local weather."
        case .restricted:
            "Location access is restricted on this device."
        case .unavailable:
            "Current location is unavailable."
        case .timedOut:
            "Location request timed out."
        }
    }
}

protocol LocationProviding: Sendable {
    func requestWhenInUseAuthorization() async
    func currentLocation() async throws -> CLLocation
    func authorizationStatus() async -> CLAuthorizationStatus
}

@MainActor
final class LiveLocationProvider: NSObject, LocationProviding, CLLocationManagerDelegate {
    private static let lastLatitudeKey = "stepReceipt.weather.lastLatitude"
    private static let lastLongitudeKey = "stepReceipt.weather.lastLongitude"
    private static let lastLocationAtKey = "stepReceipt.weather.lastLocationAt"
    private static let maxCachedLocationAge: TimeInterval = 60 * 60

    private let manager = CLLocationManager()
    private var authorizationContinuation: CheckedContinuation<Void, Never>?
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var locationTimeoutTask: Task<Void, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func authorizationStatus() async -> CLAuthorizationStatus {
        manager.authorizationStatus
    }

    func requestWhenInUseAuthorization() async {
        let status = manager.authorizationStatus
        guard status == .notDetermined else { return }

        await withCheckedContinuation { continuation in
            authorizationContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    func currentLocation() async throws -> CLLocation {
        switch manager.authorizationStatus {
        case .notDetermined:
            await requestWhenInUseAuthorization()
            return try await currentLocation()
        case .denied:
            throw LocationProviderError.denied
        case .restricted:
            throw LocationProviderError.restricted
        case .authorizedAlways, .authorizedWhenInUse:
            break
        @unknown default:
            throw LocationProviderError.unavailable
        }

        if let recent = recentCachedLocation() {
            return recent
        }

        if let live = manager.location, live.timestamp.timeIntervalSinceNow > -Self.maxCachedLocationAge {
            cacheLocation(live)
            return live
        }

        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()

            locationTimeoutTask?.cancel()
            locationTimeoutTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(12))
                guard !Task.isCancelled, let pending = locationContinuation else { return }
                locationContinuation = nil
                if let cached = Self.loadPersistedLocation() {
                    pending.resume(returning: cached)
                } else {
                    pending.resume(throwing: LocationProviderError.timedOut)
                }
            }
        }
    }

    private func recentCachedLocation() -> CLLocation? {
        if let live = manager.location, live.timestamp.timeIntervalSinceNow > -Self.maxCachedLocationAge {
            return live
        }
        return Self.loadPersistedLocation()
    }

    private func cacheLocation(_ location: CLLocation) {
        let defaults = UserDefaults.standard
        defaults.set(location.coordinate.latitude, forKey: Self.lastLatitudeKey)
        defaults.set(location.coordinate.longitude, forKey: Self.lastLongitudeKey)
        defaults.set(location.timestamp.timeIntervalSince1970, forKey: Self.lastLocationAtKey)
    }

    private static func loadPersistedLocation() -> CLLocation? {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: lastLatitudeKey) != nil else { return nil }
        let latitude = defaults.double(forKey: lastLatitudeKey)
        let longitude = defaults.double(forKey: lastLongitudeKey)
        let timestamp = defaults.double(forKey: lastLocationAtKey)
        guard timestamp > 0 else { return nil }

        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: 0,
            horizontalAccuracy: 1_000,
            verticalAccuracy: 1_000,
            timestamp: Date(timeIntervalSince1970: timestamp)
        )
        guard location.timestamp.timeIntervalSinceNow > -maxCachedLocationAge else { return nil }
        return location
    }

    private func finishLocationRequest(with result: Result<CLLocation, Error>) {
        locationTimeoutTask?.cancel()
        locationTimeoutTask = nil
        guard let continuation = locationContinuation else { return }
        locationContinuation = nil

        switch result {
        case let .success(location):
            cacheLocation(location)
            continuation.resume(returning: location)
        case let .failure(error):
            if let cached = Self.loadPersistedLocation() {
                continuation.resume(returning: cached)
            } else {
                continuation.resume(throwing: error)
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            guard status != .notDetermined else { return }
            authorizationContinuation?.resume()
            authorizationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let lastLocation = locations.last
        Task { @MainActor in
            guard let location = lastLocation else { return }
            finishLocationRequest(with: .success(location))
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let capturedError = error
        Task { @MainActor in
            if (capturedError as? CLError)?.code == .denied {
                finishLocationRequest(with: .failure(LocationProviderError.denied))
            } else {
                finishLocationRequest(with: .failure(capturedError))
            }
        }
    }
}

struct DisabledLocationProvider: LocationProviding, Sendable {
    func requestWhenInUseAuthorization() async {}

    func currentLocation() async throws -> CLLocation {
        throw LocationProviderError.denied
    }

    func authorizationStatus() async -> CLAuthorizationStatus {
        .denied
    }
}
