import CoreLocation
import Combine

final class LocationPermissionManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()

    var authorizationStatus: CLAuthorizationStatus {
        locationManager.authorizationStatus
    }

    @Published var isAuthorized: Bool = false

    override init() {
        super.init()
        locationManager.delegate = self
        let status = locationManager.authorizationStatus
        isAuthorized = status == .authorizedAlways || status == .authorized
    }

    func requestPermissionIfNeeded() {
        guard !isAuthorized else { return }
        locationManager.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        isAuthorized = status == .authorizedAlways || status == .authorized
    }
}
