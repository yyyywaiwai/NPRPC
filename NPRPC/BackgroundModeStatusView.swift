//
//  BackgroundModeStatusView.swift
//  NPRPC
//
//  Created by yyyywaiwai on 2025/07/07.
//

import SwiftUI
import CoreLocation

struct BackgroundModeStatusView: View {
    let isActive: Bool
    let authStatus: CLAuthorizationStatus
    
    var body: some View {
        HStack {
            Image(systemName: backgroundIcon)
                .foregroundColor(backgroundColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("バックグラウンドモード")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(statusText)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(backgroundColor)
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(backgroundColor.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var backgroundIcon: String {
        switch authStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return isActive ? "location.fill" : "location"
        case .denied, .restricted:
            return "location.slash"
        case .notDetermined:
            return "location.circle"
        @unknown default:
            return "location.circle"
        }
    }
    
    private var backgroundColor: Color {
        switch authStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return isActive ? .green : .orange
        case .denied, .restricted:
            return .red
        case .notDetermined:
            return .gray
        @unknown default:
            return .gray
        }
    }
    
    private var statusText: String {
        switch authStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return isActive ? "アクティブ" : "利用可能"
        case .denied, .restricted:
            return "権限が拒否されています"
        case .notDetermined:
            return "権限が未設定"
        @unknown default:
            return "不明"
        }
    }
}