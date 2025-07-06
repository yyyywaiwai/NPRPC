//
//  BackgroundLocationManager.swift
//  NPRPC
//
//  Created by yyyywaiwai on 2025/07/07.
//

import Foundation
import CoreLocation

class BackgroundLocationManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    
    @Published var isBackgroundModeEnabled = false
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        locationManager.distanceFilter = 1000 // 1km以上移動したら更新
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestLocationPermission() {
        print("📍 Requesting location permission for background mode")
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startBackgroundMode() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            print("❌ Location permission not granted")
            requestLocationPermission()
            return
        }
        
        print("🟢 Starting background location updates")
        locationManager.startUpdatingLocation()
        isBackgroundModeEnabled = true
    }
    
    func stopBackgroundMode() {
        print("🔴 Stopping background location updates")
        locationManager.stopUpdatingLocation()
        isBackgroundModeEnabled = false
    }
}

extension BackgroundLocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // 位置情報の更新を受信（実際には位置情報は使用しない）
        // バックグラウンドでの実行継続のためのトリガーとしてのみ使用
        print("📍 Location updated (background mode active)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.authorizationStatus = status
        }
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            print("✅ Location permission granted: \(status)")
        case .denied, .restricted:
            print("❌ Location permission denied")
            DispatchQueue.main.async {
                self.isBackgroundModeEnabled = false
            }
        case .notDetermined:
            print("❓ Location permission not determined")
        @unknown default:
            print("❓ Unknown location permission status")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location manager error: \(error.localizedDescription)")
    }
}