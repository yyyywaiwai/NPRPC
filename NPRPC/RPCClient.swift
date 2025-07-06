//
//  RPCClient.swift
//  NPRPC
//
//  Created by yyyywaiwai on 2025/07/05.
//

import Foundation

@MainActor
class RPCClient: ObservableObject {
    @Published var isConnected = false
    @Published var serverURL = "http://192.168.1.100:8080"
    
    private var requestId = 0
    
    func updatePresence(track: MusicTrack) async {
        do {
            let request = RPCRequest(
                method: "updatePresence",
                params: [
                    "title": track.title,
                    "artist": track.artist,
                    "album": track.album,
                    "artwork": track.artworkBase64 as Any
                ],
                id: getNextRequestId()
            )
            
            let response = await sendRPCRequest(request)
            isConnected = response != nil
            
        } catch {
            print("RPC Error: \(error)")
            isConnected = false
        }
    }
    
    func clearPresence() async {
        do {
            let request = RPCRequest(
                method: "clearPresence",
                params: [:],
                id: getNextRequestId()
            )
            
            let response = await sendRPCRequest(request)
            isConnected = response != nil
            
        } catch {
            print("RPC Error: \(error)")
            isConnected = false
        }
    }
    
    func checkStatus() async {
        do {
            let request = RPCRequest(
                method: "getStatus",
                params: [:],
                id: getNextRequestId()
            )
            
            let response = await sendRPCRequest(request)
            isConnected = response != nil
            
        } catch {
            print("RPC Error: \(error)")
            isConnected = false
        }
    }
    
    private func sendRPCRequest(_ request: RPCRequest) async -> RPCResponse? {
        guard let url = URL(string: "\(serverURL)/rpc") else {
            print("Invalid server URL")
            return nil
        }
        
        do {
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let encoder = JSONEncoder()
            urlRequest.httpBody = try encoder.encode(request)
            
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("HTTP Error: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return nil
            }
            
            let decoder = JSONDecoder()
            let rpcResponse = try decoder.decode(RPCResponse.self, from: data)
            return rpcResponse
            
        } catch {
            print("Network Error: \(error)")
            return nil
        }
    }
    
    private func getNextRequestId() -> Int {
        requestId += 1
        return requestId
    }
}

struct RPCRequest: Codable {
    let jsonrpc = "2.0"
    let method: String
    let params: [String: Any]
    let id: Int
    
    enum CodingKeys: String, CodingKey {
        case jsonrpc, method, params, id
    }
    
    init(method: String, params: [String: Any], id: Int) {
        self.method = method
        self.params = params
        self.id = id
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        method = try container.decode(String.self, forKey: .method)
        id = try container.decode(Int.self, forKey: .id)
        
        let paramsAnyCodable = try container.decode(AnyCodable.self, forKey: .params)
        if let paramsDict = paramsAnyCodable.value as? [String: Any] {
            params = paramsDict
        } else {
            params = [:]
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(jsonrpc, forKey: .jsonrpc)
        try container.encode(method, forKey: .method)
        try container.encode(id, forKey: .id)
        
        let paramsData = try JSONSerialization.data(withJSONObject: params)
        let paramsJson = try JSONSerialization.jsonObject(with: paramsData)
        try container.encode(AnyCodable(paramsJson), forKey: .params)
    }
}

struct RPCResponse: Codable {
    let jsonrpc: String
    let result: AnyCodable?
    let error: RPCError?
    let id: Int?
}

struct RPCError: Codable {
    let code: Int
    let message: String
}

struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else if container.decodeNil() {
            value = NSNull()
        } else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unknown type"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let string as String:
            try container.encode(string)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let bool as Bool:
            try container.encode(bool)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        case is NSNull:
            try container.encodeNil()
        default:
            throw EncodingError.invalidValue(value, .init(codingPath: encoder.codingPath, debugDescription: "Cannot encode value"))
        }
    }
}