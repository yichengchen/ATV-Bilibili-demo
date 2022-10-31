//
//  String.swift
//  BilibiliLive
//
//  Created by whw on 2022/10/31.
//

import Foundation

extension String {
    static func += (lhs: inout String, rhs: Int) {
        lhs = String((Int(lhs) ?? 0) + rhs)
    }

    static func -= (lhs: inout String, rhs: Int) {
        lhs = String((Int(lhs) ?? 0) - rhs)
    }
}
