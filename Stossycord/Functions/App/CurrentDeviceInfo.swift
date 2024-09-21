//
//  CurrentDeviceInfo.swift
//  Stossycord
//
//  Created by Stossy11 on 19/9/2024.
//

import Foundation
import UIKit


class CurrentDeviceInfo {
    
    public static let shared = CurrentDeviceInfo()
    
    public init() {}
    
    var Country: String = Locale.current.region?.identifier ?? "US"
    
    let currentTimeZone = TimeZone.current

    // Get the time zone identifier (e.g., "America/New_York")
    let timeZoneIdentifier = TimeZone.current.identifier
    
    let preferredLanguages = Locale.preferredLanguages
    
    public var deviceInfo: DeviceInfo {
        let deviceInfo = DeviceInfo(
            os: "Mac OS X",
            browser: "Safari",
            device: "",
            systemLocale: "\(currentTimeZone)-\(Country))",
            browserUserAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X \(UIDevice.current.systemVersion)) AppleWebKit/\(getWebKitVersion()) (KHTML, like Gecko) Version/17.4 Safari/\(getWebKitVersion())",
            browserVersion: "17.4",
            osVersion: UIDevice.current.systemVersion,
            referrer: "",
            referringDomain: "",
            referrerCurrent: "",
            referringDomainCurrent: "",
            releaseChannel: "stable",
            clientBuildNumber: 318966,
            clientEventSource: "nil",
            designId: 0
        )
        return deviceInfo
    }
    
    
}
