//
//  BackgroundLocationService.swift
//  Stossycord
//

#if os(iOS)
import CoreLocation
import Foundation

@MainActor
final class BackgroundLocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = BackgroundLocationService()
    
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    
    private let locationManager = CLLocationManager()
    
    private override init() {
        authorizationStatus = locationManager.authorizationStatus
        super.init()
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        locationManager.distanceFilter = 1_000
        locationManager.pausesLocationUpdatesAutomatically = false
    }
    
    func startIfNeeded() {
        guard UserDefaults.standard.bool(forKey: "backgroundLocationSupportEnabled") else {
            stop()
            return
        }
        
        requestAuthorizationAndStart()
    }
    
    func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "backgroundLocationSupportEnabled")
        
        if enabled {
            requestAuthorizationAndStart()
        } else {
            stop()
        }
    }
    
    func requestAuthorizationAndStart() {
        authorizationStatus = locationManager.authorizationStatus
        
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestAlwaysAuthorization()
        case .authorizedAlways:
            startUpdatingLocation()
        case .authorizedWhenInUse:
            locationManager.requestAlwaysAuthorization()
            startUpdatingLocation()
        case .denied, .restricted:
            stop()
        @unknown default:
            stop()
        }
    }
    
    func stop() {
        locationManager.stopUpdatingLocation()
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.showsBackgroundLocationIndicator = false
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        if UserDefaults.standard.bool(forKey: "backgroundLocationSupportEnabled"),
           authorizationStatus == .authorizedAlways {
            startUpdatingLocation()
        } else if authorizationStatus == .denied || authorizationStatus == .restricted {
            stop()
        }
    }
    
    private func startUpdatingLocation() {
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.showsBackgroundLocationIndicator = true
        locationManager.startUpdatingLocation()
    }
}
#endif
