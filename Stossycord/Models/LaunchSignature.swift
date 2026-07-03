//
//  LaunchSignature.swift
//  Stossycord
//
//  Created by Stossy11 on 20/1/2026.
//

import Foundation

struct UInt128 {
    var high: UInt64
    var low: UInt64

    static let max = UInt128(high: .max, low: .max)

    static prefix func ~(v: UInt128) -> UInt128 {
        .init(high: ~v.high, low: ~v.low)
    }

    static func &(lhs: UInt128, rhs: UInt128) -> UInt128 {
        .init(high: lhs.high & rhs.high, low: lhs.low & rhs.low)
    }

    static func |(lhs: UInt128, rhs: UInt128) -> UInt128 {
        .init(high: lhs.high | rhs.high, low: lhs.low | rhs.low)
    }
    
    static func fromBinary(_ string: String) -> UInt128 {
         let s: Substring
         if string.hasPrefix("0b") {
             s = string.dropFirst(2)
         } else {
             s = Substring(string)
         }

         precondition(s.count == 128, "UInt128 binary literal must be exactly 128 bits")

         var high: UInt64 = 0
         var low: UInt64 = 0

         for (i, char) in s.enumerated() {
             let bit: UInt64
             switch char {
             case "0": bit = 0
             case "1": bit = 1
             default:
                 fatalError("Invalid character in binary literal: \(char)")
             }

             if i < 64 {
                 high = (high << 1) | bit
             } else {
                 low = (low << 1) | bit
             }
         }

         return UInt128(high: high, low: low)
     }
    

}
extension UUID {


    func toUInt128() -> UInt128 {
        let bytes = withUnsafeBytes(of: uuid) { Array($0) }
        var high: UInt64 = 0
        var low: UInt64 = 0

        for i in 0..<8 { high = (high << 8) | UInt64(bytes[i]) }
        for i in 8..<16 { low = (low << 8) | UInt64(bytes[i]) }

        return UInt128(high: high, low: low)
    }
    
    init(_ value: UInt128) {
        var bytes = [UInt8](repeating: 0, count: 16)
        var h = value.high
        var l = value.low

        for i in (0..<8).reversed() {
            bytes[i] = UInt8(h & 0xff)
            h >>= 8
        }
        for i in (8..<16).reversed() {
            bytes[i] = UInt8(l & 0xff)
            l >>= 8
        }

        self = UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}


extension UUID {
    static func generateLaunchSignature() -> UUID {
        let bitsString =
        "0b00000000100000000001000000010000000010000001000000001000000000000010000010000001000000000100000000000001000000000000100000000000"

        let bits = UInt128.fromBinary(bitsString)
        let random = UUID().toUInt128()
        let masked = (random & ~bits) | bits
        return UUID(masked)
    }
}
