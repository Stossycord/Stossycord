//
//  SafeIndex.swift
//  Stossycord
//
//  Created by Stossy11 on 14/1/2026.
//

import Foundation

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

extension Dictionary where Value: RangeReplaceableCollection {
    subscript(array key: Key) -> Value {
        get {
            return self[key] ?? Value()
        }
        set {
            self[key] = newValue
        }
    }
}
