//
//  String.swift
//  BilibiliLive
//
//  Created by whw on 2022/10/31.
//

import Foundation

extension String {
    static func += (lhs: inout String, rhs: Int) {
        if let number = Int(lhs) {
            lhs = String(number + rhs)
        }
    }

    static func -= (lhs: inout String, rhs: Int) {
        if let number = Int(lhs) {
            lhs = String(number - rhs)
        }
    }
}
