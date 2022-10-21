//
//  Colors.swift
//  BilibiliLive
//
//  Created by whw on 2022/10/21.
//

import UIKit

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1.0) {
        let r: CGFloat = CGFloat((hex & 0x00FF0000) >> 16) / 255.0
        let g: CGFloat = CGFloat((hex & 0x0000FF00) >> 8) / 255.0
        let b: CGFloat = CGFloat(hex & 0x000000FF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }
    
    static var biliblue: UIColor {
        get {
            UIColor(hex: 0x00aeec)
        }
    }
    
    static var bilipink: UIColor {
        get {
            UIColor(hex: 0xff6699)
        }
    }
}

