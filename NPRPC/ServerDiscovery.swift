//
//  ServerDiscovery.swift
//  NPRPC
//
//  Created by yyyywaiwai on 2025/07/05.
//

import Foundation
import Network

#if canImport(Darwin)
import Darwin
#endif

@MainActor
class ServerDiscovery: ObservableObject {
    @Published var discoveredServers: [DiscoveredServer] = []
    @Published var isScanning = false
    
    private let discoveryPort: UInt16 = 8080
    private let timeout: TimeInterval = 3.0
    
    func startDiscovery() async {
        isScanning = true
        discoveredServers.removeAll()
        
        // ローカルネットワークの範囲を取得
        let networkRanges = getLocalNetworkRanges()
        
        await withTaskGroup(of: DiscoveredServer?.self) { group in
            for range in networkRanges {
                for i in 1...254 {
                    let ip = "\(range).\(i)"
                    group.addTask {
                        await self.checkServer(ip: ip)
                    }
                }
            }
            
            for await server in group {
                if let server = server {
                    discoveredServers.append(server)
                }
            }
        }
        
        isScanning = false
    }
    
    private func getLocalNetworkRanges() -> [String] {
        var ranges: [String] = []
        
        // 一般的なローカルネットワーク範囲
        let commonRanges = [
            "192.168.1",
            "192.168.0",
            "10.0.0",
            "172.16.0"
        ]
        
        // 実際のネットワークインターフェースから取得
        if let currentIP = getCurrentIPAddress() {
            let components = currentIP.split(separator: ".")
            if components.count >= 3 {
                let networkRange = "\(components[0]).\(components[1]).\(components[2])"
                if !ranges.contains(networkRange) {
                    ranges.append(networkRange)
                }
            }
        }
        
        // 一般的な範囲を追加
        for range in commonRanges {
            if !ranges.contains(range) {
                ranges.append(range)
            }
        }
        
        return ranges
    }
    
    private func getCurrentIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                
                let interface = ptr?.pointee
                let addrFamily = interface?.ifa_addr.pointee.sa_family
                
                if addrFamily == UInt8(AF_INET) {
                    if let name = interface?.ifa_name,
                       let addr = interface?.ifa_addr {
                        let hostname = String(cString: name)
                        
                        if hostname == "en0" || hostname.hasPrefix("en") {
                            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                            if getnameinfo(addr, socklen_t(addr.pointee.sa_len),
                                         &hostname, socklen_t(hostname.count),
                                         nil, socklen_t(0), NI_NUMERICHOST) == 0 {
                                address = String(cString: hostname)
                                break
                            }
                        }
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        
        return address
    }
    
    private func checkServer(ip: String) async -> DiscoveredServer? {
        let url = URL(string: "http://\(ip):\(discoveryPort)/discovery")!
        
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.httpMethod = "GET"
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }
            
            let serverInfo = try JSONDecoder().decode(ServerInfo.self, from: data)
            
            return DiscoveredServer(
                ip: ip,
                port: discoveryPort,
                serverURL: serverInfo.server_url,
                serviceName: serverInfo.service,
                version: serverInfo.version,
                status: serverInfo.status,
                discordConnected: serverInfo.discord_connected
            )
            
        } catch {
            return nil
        }
    }
}

struct DiscoveredServer: Identifiable, Hashable {
    let id = UUID()
    let ip: String
    let port: UInt16
    let serverURL: String
    let serviceName: String
    let version: String
    let status: String
    let discordConnected: Bool
    
    var displayName: String {
        return "\(serviceName) (\(ip))"
    }
}

struct ServerInfo: Codable {
    let service: String
    let version: String
    let server_url: String
    let endpoints: [String: String]
    let status: String
    let discord_connected: Bool
}