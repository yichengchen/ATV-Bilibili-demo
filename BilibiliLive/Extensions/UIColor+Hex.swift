//
//  UIColor+Hex.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/8/19.
//

import UIKit

extension UIColor {
    public convenience init(number: Int) {
        let r, g, b: CGFloat
        r = CGFloat((number & 0x00ff0000) >> 16) / 255
        g = CGFloat((number & 0x0000ff00) >> 8) / 255
        b = CGFloat(number & 0x000000ff) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
