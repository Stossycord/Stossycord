//
//  UDPSocket.swift
//  Stossycord
//
//  Created by Stossy11 on 31/5/2024.
//

import Foundation
import CocoaAsyncSocket // Import GCDAsyncUdpSocket framework

class UDPConnectionManager: NSObject, GCDAsyncUdpSocketDelegate {
    
    var udpSocket: GCDAsyncUdpSocket!
    let serverPort: UInt16 = 443 // Default port for HTTPS
    var serveraddress: String?
    
    init(serverAddress: String) {
        super.init()
        
        // Initialize UDP socket
        udpSocket = GCDAsyncUdpSocket(delegate: self, delegateQueue: DispatchQueue.main)
        
        let stringWithoutColon = String(serverAddress.split(separator: ":")[0])
        
        // Start listening for incoming data
        do {
            try udpSocket.bind(toPort: 0) // Bind to any available port
            try udpSocket.beginReceiving()
            print("UDP Socket Started")
        } catch {
            print("Error starting UDP socket: \(error)")
        }
        
        
        serveraddress = serverAddress
        // Connect to the specified server address and port
        do {
            try udpSocket.connect(toHost: stringWithoutColon, onPort: serverPort)
        } catch {
            print("Error connecting to \(stringWithoutColon):\(serverPort): \(error)")
        }
    }
    
    // MARK: - GCDAsyncUdpSocketDelegate methods
    
    func udpSocket(_ sock: GCDAsyncUdpSocket, didConnectToAddress address: Data) {
        print("Connected to \(sock.connectedHost):\(sock.connectedPort)")
    }
    
    func udpSocket(_ sock: GCDAsyncUdpSocket, didNotConnect error: Error?) {
        print("Failed to connect with UDP: \(error?.localizedDescription ?? "") and \(serveraddress ?? "No Server Addeess")")
    }
    
    func udpSocket(_ sock: GCDAsyncUdpSocket, didSendDataWithTag tag: Int) {
        print("Data sent successfully")
    }
    
    func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive data: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {
        let receivedData = String(data: data, encoding: .utf8)
        print("Received data: \(receivedData ?? "Unable to decode data")")
        
        // Handle received data here
    }
    
    // MARK: - Public methods
    
    func sendData(_ data: Data) {
        udpSocket.send(data, withTimeout: -1, tag: 0)
    }
    
    // MARK: - Close connection
    
    func closeConnection() {
        udpSocket.close()
    }
}
