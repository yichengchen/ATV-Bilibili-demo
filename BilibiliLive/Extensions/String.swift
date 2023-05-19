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

    func isMatch(pattern: String) -> Bool {
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        return regex.firstMatch(in: self, options: [], range: NSMakeRange(0, utf16.count)) != nil
    }
}
