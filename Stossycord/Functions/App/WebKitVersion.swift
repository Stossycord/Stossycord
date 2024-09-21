//
//  WebKitVersion.swift
//  Stossycord
//
//  Created by Stossy11 on 19/9/2024.
//

import Foundation

func getWebKitVersion() -> String {
    if let webKitBundle = Bundle(identifier: "com.apple.WebKit") {
        if let webKitVersion = webKitBundle.infoDictionary?["CFBundleVersion"] as? String {
            return webKitVersion
        }
    }
    return "605.1.15"
}

