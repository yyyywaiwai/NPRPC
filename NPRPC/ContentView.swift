//
//  ContentView.swift
//  NPRPC
//
//  Created by yyyywaiwai on 2025/07/05.
//

import SwiftUI
import CoreLocation

struct ContentView: View {
    @StateObject private var musicManager = MusicManager()
    @StateObject private var rpcClient = RPCClient()
    @StateObject private var serverDiscovery = ServerDiscovery()
    @StateObject private var backgroundLocationManager = BackgroundLocationManager()
    @State private var isAutoSync = true
    @State private var isBackgroundModeEnabled = false
    @State private var showServerPicker = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 現在の楽曲情報表示 - メイン表示
                CurrentTrackView(track: musicManager.currentTrack)
                
                // コントロールエリア
                VStack(spacing: 16) {
                    // サーバー設定とステータス
                    ServerConfigurationView(
                        serverURL: $rpcClient.serverURL,
                        isConnected: rpcClient.isConnected,
                        onDiscoverServers: {
                            showServerPicker = true
                        }
                    )
                    
                    // 同期コントロール
                    SyncControlView(
                        musicManager: musicManager,
                        rpcClient: rpcClient,
                        isAutoSync: $isAutoSync
                    )
                    
                    // バックグラウンドモード設定
                    BackgroundModeToggleView(
                        isEnabled: $isBackgroundModeEnabled,
                        isActive: backgroundLocationManager.isBackgroundModeEnabled,
                        authStatus: backgroundLocationManager.authorizationStatus
                    )
                }
                
                Spacer()
            }
            .padding()
            .navigationBarHidden(true)
            .onAppear {
                AudioSessionManager.shared.setupBackgroundAudio()
            }
            .sheet(isPresented: $showServerPicker) {
                ServerPickerView(
                    serverDiscovery: serverDiscovery,
                    selectedURL: $rpcClient.serverURL,
                    isPresented: $showServerPicker
                )
            }
            .onChange(of: musicManager.currentTrack) { oldTrack, newTrack in
                // Auto Syncが有効な場合の処理
                if isAutoSync {
                    if let track = newTrack, track.isPlaying {
                        Task {
                            await rpcClient.updatePresence(track: track)
                        }
                    } else if newTrack?.isPlaying == false {
                        Task {
                            await rpcClient.clearPresence()
                        }
                    }
                }
                // Auto Syncが無効でも、曲が変わった場合は一度だけ更新
                else if let newTrack = newTrack, let oldTrack = oldTrack {
                    if newTrack.title != oldTrack.title || newTrack.artist != oldTrack.artist {
                        Task {
                            await rpcClient.updatePresence(track: newTrack)
                        }
                    }
                }
                // 最初の曲が検出された場合
                else if oldTrack == nil, let newTrack = newTrack {
                    Task {
                        await rpcClient.updatePresence(track: newTrack)
                    }
                }
                
            }
            .onChange(of: isBackgroundModeEnabled) { _, isEnabled in
                if isEnabled {
                    backgroundLocationManager.startBackgroundMode()
                } else {
                    backgroundLocationManager.stopBackgroundMode()
                }
            }
        }
    }
}

struct ConnectionStatusView: View {
    let isConnected: Bool
    
    var body: some View {
        HStack {
            Circle()
                .fill(isConnected ? .green : .red)
                .frame(width: 12, height: 12)
            Text(isConnected ? "Connected" : "Disconnected")
                .font(.headline)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}


struct CurrentTrackView: View {
    let track: MusicTrack?
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "music.note")
                    .foregroundColor(.blue)
                Text("Current Track")
                    .font(.headline)
                Spacer()
            }
            
            if let track = track {
                HStack(alignment: .top, spacing: 16) {
                    // アートワーク（左側）
                    if let artworkBase64 = track.artworkBase64,
                       let imageData = Data(base64Encoded: artworkBase64),
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    } else {
                        VStack {
                            Image(systemName: "photo")
                                .font(.system(size: 24))
                                .foregroundColor(.gray)
                            Text("JPEG")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.gray)
                        }
                        .frame(width: 80, height: 80)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    // 楽曲情報（右側）
                    VStack(alignment: .leading, spacing: 6) {
                        Text(track.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Text(track.artist)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        Text(track.album)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                HStack(alignment: .top, spacing: 16) {
                    // アートワーク（左側）
                    VStack {
                        Image(systemName: "photo")
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                        Text("JPEG")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.gray)
                    }
                    .frame(width: 80, height: 80)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    // 楽曲情報（右側）
                    VStack(alignment: .leading, spacing: 6) {
                        Text("No music playing")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

struct ServerConfigurationView: View {
    @Binding var serverURL: String
    let isConnected: Bool
    let onDiscoverServers: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "server.rack")
                    .foregroundColor(.blue)
                Text("Server")
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(isConnected ? .green : .red)
                    .frame(width: 12, height: 12)
                Text(isConnected ? "Connected" : "Disconnected")
                    .font(.caption)
                    .foregroundColor(isConnected ? .green : .red)
            }
            
            VStack(spacing: 8) {
                HStack {
                    TextField("Enter your server URL", text: $serverURL)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    Button(action: onDiscoverServers) {
                        Image(systemName: "magnifyingglass.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct SyncControlView: View {
    let musicManager: MusicManager
    let rpcClient: RPCClient
    @Binding var isAutoSync: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                if let track = musicManager.currentTrack {
                    Button(action: {
                        Task {
                            await rpcClient.updatePresence(track: track)
                        }
                    }) {
                        Label("Sync", systemImage: "arrow.up.circle")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                
                Button(action: {
                    Task {
                        await rpcClient.clearPresence()
                    }
                }) {
                    Label("Clear", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}


struct ServerPickerView: View {
    @ObservedObject var serverDiscovery: ServerDiscovery
    @Binding var selectedURL: String
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            VStack {
                if serverDiscovery.isScanning {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Scanning for servers...")
                            .font(.headline)
                            .padding()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if serverDiscovery.discoveredServers.isEmpty {
                    VStack {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("No servers found")
                            .font(.headline)
                        Text("Make sure the RPC server is running on your network")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(serverDiscovery.discoveredServers) { server in
                        ServerRowView(server: server) {
                            selectedURL = server.serverURL
                            isPresented = false
                        }
                    }
                }
            }
            .navigationTitle("Discover Servers")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Scan") {
                        Task {
                            await serverDiscovery.startDiscovery()
                        }
                    }
                    .disabled(serverDiscovery.isScanning)
                }
            }
            .onAppear {
                Task {
                    await serverDiscovery.startDiscovery()
                }
            }
        }
    }
}

struct BackgroundModeToggleView: View {
    @Binding var isEnabled: Bool
    let isActive: Bool
    let authStatus: CLAuthorizationStatus
    
    private var locationIconColor: Color {
        if !isEnabled {
            return .red
        } else if authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways {
            return isActive ? .green : .orange
        } else {
            return .orange
        }
    }
    
    var body: some View {
        HStack {
            Image(systemName: "location.fill")
                .foregroundColor(locationIconColor)
                .font(.title2)
            
            Toggle("Background Mode", isOn: $isEnabled)
                .font(.headline)
            
            Spacer()
        }
        .padding(.horizontal)
    }
}

struct ServerRowView: View {
    let server: DiscoveredServer
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(server.serviceName)
                            .font(.headline)
                        Text(server.serverURL)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack {
                        Circle()
                            .fill(server.discordConnected ? .green : .orange)
                            .frame(width: 12, height: 12)
                        Text("v\(server.version)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

