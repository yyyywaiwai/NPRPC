//
//  ContentView.swift
//  NPRPC
//
//  Created by yyyywaiwai on 2025/07/05.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var musicManager = MusicManager()
    @StateObject private var rpcClient = RPCClient()
    @StateObject private var serverDiscovery = ServerDiscovery()
    @StateObject private var backgroundLocationManager = BackgroundLocationManager()
    @State private var isAutoSync = false
    @State private var isBackgroundModeEnabled = false
    @State private var showServerPicker = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 接続状態表示
                ConnectionStatusView(isConnected: rpcClient.isConnected)
                
                // バックグラウンドモード状態表示
                if isBackgroundModeEnabled {
                    BackgroundModeStatusView(
                        isActive: backgroundLocationManager.isBackgroundModeEnabled,
                        authStatus: backgroundLocationManager.authorizationStatus
                    )
                }
                
                // 現在の楽曲情報表示
                CurrentTrackView(track: musicManager.currentTrack)
                
                // 設定セクション
                SettingsView(
                    serverURL: $rpcClient.serverURL,
                    isAutoSync: $isAutoSync,
                    isBackgroundModeEnabled: $isBackgroundModeEnabled,
                    onDiscoverServers: {
                        showServerPicker = true
                    }
                )
                
                // 手動制御ボタン
                ControlButtonsView(
                    musicManager: musicManager,
                    rpcClient: rpcClient,
                    isAutoSync: $isAutoSync
                )
                
                Spacer()
            }
            .padding()
            .navigationTitle("Music Discord RPC")
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
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "music.note")
                    .foregroundColor(.blue)
                Text("Current Track")
                    .font(.headline)
                Spacer()
            }
            
            if let track = track {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(track.title)
                                .font(.title2)
                                .fontWeight(.semibold)
                            Text(track.artist)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(track.album)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack {
                            // Display actual artwork if available
                            if let artworkBase64 = track.artworkBase64,
                               let imageData = Data(base64Encoded: artworkBase64),
                               let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 60, height: 60)
                                    .cornerRadius(8)
                            } else {
                                Image(systemName: "music.note")
                                    .font(.title)
                                    .foregroundColor(.gray)
                                    .frame(width: 60, height: 60)
                            }
                            
                            Image(systemName: track.isPlaying ? "play.circle.fill" : "pause.circle.fill")
                                .font(.title2)
                                .foregroundColor(track.isPlaying ? .green : .orange)
                        }
                    }
                }
            } else {
                Text("No music playing")
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}

struct SettingsView: View {
    @Binding var serverURL: String
    @Binding var isAutoSync: Bool
    @Binding var isBackgroundModeEnabled: Bool
    let onDiscoverServers: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "gear")
                    .foregroundColor(.blue)
                Text("Settings")
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 8) {
                HStack {
                    Text("Server URL:")
                        .font(.subheadline)
                    Spacer()
                }
                
                HStack {
                    TextField("http://192.168.1.100:8080", text: $serverURL)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    Button("🔍") {
                        onDiscoverServers()
                    }
                    .font(.title2)
                }
                
                Toggle("Auto Sync", isOn: $isAutoSync)
                
                Toggle("Background Mode (位置情報)", isOn: $isBackgroundModeEnabled)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}

struct ControlButtonsView: View {
    let musicManager: MusicManager
    let rpcClient: RPCClient
    @Binding var isAutoSync: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            Button(action: {
                Task {
                    await rpcClient.checkStatus()
                }
            }) {
                HStack {
                    Image(systemName: "network")
                    Text("Check Connection")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            if let track = musicManager.currentTrack {
                Button(action: {
                    Task {
                        await rpcClient.updatePresence(track: track)
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.up.circle")
                        Text("Update Now")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
            
            Button(action: {
                Task {
                    await rpcClient.clearPresence()
                }
            }) {
                HStack {
                    Image(systemName: "clear")
                    Text("Clear Presence")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
        }
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

