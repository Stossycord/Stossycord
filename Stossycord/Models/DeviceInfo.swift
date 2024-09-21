//
//  DeviceInfo.swift
//  Stossycord
//
//  Created by Stossy11 on 19/9/2024.
//

import Foundation

struct DeviceInfo: Codable {
    let os: String
    let browser: String
    let device: String
    let systemLocale: String
    let browserUserAgent: String
    let browserVersion: String
    let osVersion: String
    let referrer: String
    let referringDomain: String
    let referrerCurrent: String
    let referringDomainCurrent: String
    let releaseChannel: String
    let clientBuildNumber: Int
    let clientEventSource: String?
    let designId: Int
    
    func toBase64() -> String? {
        guard let jsonData = try? JSONEncoder().encode(self) else { return nil }
        return jsonData.base64EncodedString()
    }
}
