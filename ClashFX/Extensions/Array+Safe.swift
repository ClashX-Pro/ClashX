//
//  Array+Safe.swift
//  MTEve
//
//  Created by CYC on 2019/6/5.
//  Copyright © 2019 meitu. All rights reserved.
//

extension Collection {
    /// Returns the element at the specified index iff it is within bounds, otherwise nil.
    subscript(safe index: Index) -> Element? {
        if indices.contains(index) {
            return self[index]
        } else {
            return nil
        }
    }
}

extension Array {
    @discardableResult
    mutating func safeRemove(at index: Index) -> Bool {
        if indices.contains(index) {
            remove(at: index)
            return true
        } else {
            return false
        }
    }
}
