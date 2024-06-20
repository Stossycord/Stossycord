//
//  VoiceChatClass.swift
//  Stossycord
//
//  Created by Stossy11 on 31/5/2024.
//

import Foundation
import Network
import Starscream

class VoiceWebSocketClient: WebSocketDelegate, ObservableObject {
    var socket: WebSocket?
    var websockeclient = WebSocketClient()
    var isConnected = false
    var endpoint: String
    var token: String
    var guildID: String
    var isclosedproper = false
    var udpConnectionManager: UDPConnectionManager? // Add UDP connection manager
    
    init(endpoint: String, token: String, guildID: String) {
        self.endpoint = endpoint
        self.token = token
        self.guildID = guildID
    }
    
    func disconnect() {
        isclosedproper = true
        socket?.disconnect()
        websockeclient.isconnecedtoVC = false
        udpConnectionManager?.closeConnection() // Close UDP connection
    }
    
    func connect() {
        guard let url = URL(string: "wss://\(endpoint)/?v=4") else {
            print("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("Discord-Client", forHTTPHeaderField: "User-Agent")
        
        socket = WebSocket(request: request)
        socket?.delegate = self
        socket?.connect()
    }
    
    func sendJSONRequest(_ request: [String: Any]) {
        guard isConnected else {
            print("WebSocket is not connected")
            return
        }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: request, options: [])
            socket?.write(data: data)
        } catch {
            print("Failed to serialize JSON: \(error.localizedDescription)")
        }
    }
    
    func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocketClient) {
        switch event {
        case .connected(let headers):
            isConnected = true
            let identifyPayload: [String: Any] = [
                "op": 0,
                "d": [
                    "server_id": guildID,
                    "user_id": websockeclient.currentuserid,
                    "session_id": token,
                    "token": websockeclient.token
                ]
            ]
            sendJSONRequest(identifyPayload)
            
            // Perform UDP IP Discovery
            performIPDiscovery()
        case .disconnected(let reason, let code):
            isConnected = false
            print("Disconnected: \(reason) with code: \(code)")
            udpConnectionManager?.closeConnection() // Close UDP connection
        case .text(let string):
            handleVoiceMessage(string)
        case .binary(let data):
            print("Received data: \(data.count)")
        case .ping(_):
            socket?.write(ping: Data())
        case .pong(_):
            socket?.write(pong: Data())
        case .viabilityChanged(_):
            break
        case .reconnectSuggested(_):
            connect()
        case .cancelled:
            if isclosedproper {
                isConnected = false
                udpConnectionManager?.closeConnection() // Close UDP connection
            } else {
                udpConnectionManager?.closeConnection()
                connect()
            }
        case .error(let error):
            print("WebSocket encountered an error: \(error?.localizedDescription ?? "Unknown error")")
            if isclosedproper {
                isConnected = false
                udpConnectionManager?.closeConnection() // Close UDP connection
            } else {
                udpConnectionManager?.closeConnection()
                connect()
            }
        case .peerClosed:
            if isclosedproper {
                isConnected = false
                udpConnectionManager?.closeConnection() // Close UDP connection
            } else {
                udpConnectionManager?.closeConnection()
                connect()
            }
        }
    }
    
    func handleVoiceData(_ data: Data) {
        // Process the voice data here
        print("Received voice data: \(data.count) bytes")
        
        // You may need to decrypt, decode, and process the voice data further
    }
    
    func handleVoiceMessage(_ string: String) {
        print("Voice WebSocket message received: \(string)")
        // Check if this is the Opcode 2 Ready payload
        if let jsonData = string.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any],
           let op = jsonObject["op"] as? Int, op == 2,
           let data = jsonObject["d"] as? [String: Any],
           let address = data["ip"] as? String,
           let port = data["port"] as? UInt16,
           let mode = (data["modes"] as? [String])?.first {
            // Opcode 2 Ready payload received, send Select Protocol payload
            sendSelectProtocolPayload(address: address, port: port, mode: mode)
        }
    }

    // Modify performIPDiscovery method in VoiceWebSocketClient class
    func performIPDiscovery() {
        // Get local IP address
        let localIPAddress = getLocalIPAddress()
        
        // Use Discord's IP Discovery format to send a UDP request for external IP and port
        let discoveryData: Data = {
            var data = Data()
            let type: UInt16 = 0x1 // Request
            let length: UInt16 = 70
            let ssrc: UInt32 = 123456 // Example SSRC, replace with actual value
            
            data.append(type.bigEndianData)
            data.append(length.bigEndianData)
            data.append(ssrc.bigEndianData)
            data.append(localIPAddress)
            data.append(UInt16(443).bigEndianData) // Port (443 in this case)
            return data
        }()
        
        // Send UDP request
        udpConnectionManager = UDPConnectionManager(serverAddress: endpoint)
        udpConnectionManager?.sendData(discoveryData)
    }

    // Modify sendData method in UDPConnectionManager class
    private func getLocalIPAddress() -> Data {
        var addressData = Data()
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return addressData }
        guard let firstAddr = ifaddr else { return addressData }
        
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            guard let interface = ptr.pointee.ifa_addr.pointee as? sockaddr_in else { continue }
            if interface.sin_family == __uint8_t(AF_INET) {
                let address = interface.sin_addr.s_addr
                let addressBytes = withUnsafeBytes(of: address) { Data($0) }
                addressData.append(addressBytes)
            }
        }
        
        freeifaddrs(ifaddr)
        return addressData
    }
    
    
    func sendSelectProtocolPayload(address: String, port: UInt16, mode: String) {
        let selectProtocolPayload: [String: Any] = [
            "op": 1,
            "d": [
                "protocol": "udp",
                "data": [
                    "address": address,
                    "port": port,
                    "mode": mode
                ]
            ]
        ]
        sendJSONRequest(selectProtocolPayload)
    }
}

extension UInt16 {
    var bigEndianData: Data {
        var int = self.bigEndian
        return Data(bytes: &int, count: MemoryLayout<UInt16>.size)
    }
}

extension UInt32 {
    var bigEndianData: Data {
        var int = self.bigEndian
        return Data(bytes: &int, count: MemoryLayout<UInt32>.size)
    }
}


