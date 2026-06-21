import CoreLocation
import Foundation

enum LocationProviderError: LocalizedError, Sendable {
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
}

@MainActor
final class LiveLocationProvider: NSObject, LocationProviding, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var authorizationContinuation: CheckedContinuation<Void, Never>?
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    func requestWhenInUseAuthorization() async {
        guard manager.authorizationStatus == .notDetermined else { return }

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

        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
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
            locationContinuation?.resume(returning: location)
            locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let capturedError = error
        Task { @MainActor in
            if (capturedError as? CLError)?.code == .denied {
                locationContinuation?.resume(throwing: LocationProviderError.denied)
            } else {
                locationContinuation?.resume(throwing: capturedError)
            }
            locationContinuation = nil
        }
    }
}

struct DisabledLocationProvider: LocationProviding, Sendable {
    func requestWhenInUseAuthorization() async {}

    func currentLocation() async throws -> CLLocation {
        throw LocationProviderError.denied
    }
}
