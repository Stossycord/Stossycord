//
//  utf8.swift
//  Stossycord
//
//  Created by Stossy11 on 26/12/2024.
//

import Foundation

extension Data {
    var utf8String: String? {
        return String(data: self, encoding: .utf8)
    }
}
