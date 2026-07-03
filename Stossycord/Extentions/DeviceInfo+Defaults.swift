//
//  DeviceInfo+Defaults.swift
//  Stossycord
//
//  Created by Stossy11 on 20/1/2026.
//

import Foundation
import UIKit

extension DeviceInfo {

    static func defaultOS() -> String {
        #if os(iOS)
        return "iOS"
        #elseif os(macOS)
        return "Mac OS X"
        #elseif os(watchOS)
        return "watchOS"
        #else
        return "Unknown"
        #endif
    }

    static func defaultBrowser() -> String {
        #if os(iOS) || os(watchOS)
        return "Discord iOS"
        #elseif os(macOS)
        return "Discord Client"
        #else
        return "Safari"
        #endif
    }

    static func defaultBrowserVersion() -> String? {
        #if os(macOS)
        return "35.3.0"
        #else
        return ""
        #endif
    }

    static func defaultClientVersion() -> String? {
        #if os(iOS) || os(watchOS)
        return "300.0"
        #elseif os(macOS)
        return "0.0.364"
        #else
        return nil
        #endif
    }

    static func defaultClientBuildNumber() -> Int? {
        #if os(iOS) || os(watchOS)
        return 86251
        #elseif os(macOS)
        return 459631
        #else
        return nil
        #endif
    }

    static func defaultOSVersion() -> String? {
        ProcessInfo.processInfo.operatingSystemVersionString
    }

    static func defaultOSSDKVersion() -> String? {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion)"
    }

    static func defaultOSArch() -> String? {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x64"
        #else
        return nil
        #endif
    }

    static func defaultAppArch() -> String? {
        defaultOSArch()
    }

    static func defaultClientAppState() -> String {
        #if os(iOS) || os(watchOS)
        return "active"
        #elseif os(macOS)
        return "focused"
        #else
        return "unknown"
        #endif
    }

    static func defaultDevice() -> String? {
        #if os(iOS)
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
        #else
        return nil
        #endif
    }

    static func defaultDeviceVendorID() -> String? {
        #if os(iOS)
        return UIDevice.current.identifierForVendor?.uuidString.uppercased()
        #else
        return nil
        #endif
    }

    static func defaultDesignID() -> Int? {
        #if os(iOS) || os(watchOS)
        return 2
        #else
        return nil
        #endif
        
    }

    static func defaultUserAgent() -> String? {
        #if os(macOS)
        return "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) discord/0.0.364 Chrome/134.0.6998.205 Electron/35.3.0 Safari/537.36"
        #elseif os(iOS)
        return "Discord/300.0"
        #else
        return nil
        #endif
    }
}

