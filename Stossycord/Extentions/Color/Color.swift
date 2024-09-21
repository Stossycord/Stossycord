//
//  Color.swift
//  Stossycord
//
//  Created by Stossy11 on 20/9/2024.
//

import SwiftUI
import Foundation

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r, g, b: Double
        switch hexSanitized.count {
        case 3: // RGB (12-bit)
            (r, g, b) = (
                Double((rgb & 0xF00) >> 8) / 15.0,
                Double((rgb & 0x0F0) >> 4) / 15.0,
                Double(rgb & 0x00F) / 15.0
            )
        case 6: // RGB (24-bit)
            (r, g, b) = (
                Double((rgb & 0xFF0000) >> 16) / 255.0,
                Double((rgb & 0x00FF00) >> 8) / 255.0,
                Double(rgb & 0x0000FF) / 255.0
            )
        default:
            return nil
        }
        
        self.init(red: r, green: g, blue: b)
    }
}
