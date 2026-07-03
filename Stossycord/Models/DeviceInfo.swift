//
//  DeviceInfo.swift
//  Stossycord
//
//  Created by Stossy11 on 19/9/2024.
//

import Foundation

struct DeviceInfo: Codable {
    var os: String
    var browser: String
    var device: String?
    var release_channel: String?
    var client_version: String?
    var os_version: String?
    var os_arch: String?
    var app_arch: String?
    var system_locale: String?
    var has_client_mods: Bool?
    var client_launch_id: String?
    var launch_signature: String?
    var device_vendor_id: String?
    var browser_user_agent: String
    var browser_version: String?
    var os_sdk_version: String?
    var client_build_number: Int?
    var client_app_state: String?
    var native_build_number: Int?
    var design_id: Int?
    var client_heartbeat_session_id: String?
    var client_event_source: String? = nil

    init(isWebSocket: Bool = false) {
        self.os = DeviceInfo.defaultOS()
        self.browser = DeviceInfo.defaultBrowser()

        self.device = DeviceInfo.defaultDevice()
        self.release_channel = "stable"

        self.client_version = DeviceInfo.defaultClientVersion()
        self.client_build_number = DeviceInfo.defaultClientBuildNumber()
        self.native_build_number = nil

        self.os_version = DeviceInfo.defaultOSVersion()
        self.os_sdk_version = DeviceInfo.defaultOSSDKVersion()
        self.os_arch = DeviceInfo.defaultOSArch()
        self.app_arch = DeviceInfo.defaultAppArch()

        self.system_locale = Locale.current.identifier
        self.has_client_mods = false

        self.client_launch_id = UUID().uuidString.lowercased()
        self.launch_signature = UUID.generateLaunchSignature().uuidString.lowercased()
        self.client_heartbeat_session_id = WebSocketService.clientHeartbeatSessionId.uuidString.lowercased()

        self.device_vendor_id = DeviceInfo.defaultDeviceVendorID()

        self.browser_user_agent = isWebSocket ? "" : DeviceInfo.defaultUserAgent() ?? ""
        self.browser_version = DeviceInfo.defaultBrowserVersion()

        self.client_app_state = DeviceInfo.defaultClientAppState()
        self.design_id = DeviceInfo.defaultDesignID()

        self.client_event_source = nil
    }
    
    enum CodingKeys: String, CodingKey {
        case os, browser, device, release_channel, client_version
        case os_version, os_arch, app_arch, system_locale
        case has_client_mods, client_launch_id, launch_signature
        case device_vendor_id, browser_user_agent, browser_version
        case os_sdk_version, client_build_number, client_app_state
        case native_build_number, design_id
        case client_heartbeat_session_id, client_event_source
    }

    func toBase64() -> String? {
        guard let jsonData = try? JSONEncoder().encode(self) else { return nil }
        return jsonData.base64EncodedString()
    }
    
    func toJson(isWebSocket: Bool = false) -> [String: Any] {
        guard let jsonData = try? JSONEncoder().encode(self) else { return [:] }
        var json = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] ?? [:]
        if isWebSocket {
            json?["browser_user_agent"] = nil
        }
        return json ?? [:]
    }
}

