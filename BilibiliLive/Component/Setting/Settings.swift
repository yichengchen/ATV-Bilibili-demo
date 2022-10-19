//
//  Settings.swift
//  BilibiliLive
//
//  Created by whw on 2022/10/19.
//

import Foundation

class Settings {
    static var direatlyEnterVideo: Bool {
        set {
            UserDefaults.standard.set(newValue, forKey: "Settings.direatlyEnterVideo")
        }
        get {
            return UserDefaults.standard.bool(forKey: "Settings.direatlyEnterVideo")
        }
    }
}
