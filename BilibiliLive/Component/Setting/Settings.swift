//
//  Settings.swift
//  BilibiliLive
//
//  Created by whw on 2022/10/19.
//

import Foundation

enum FeedDisplayStyle {
    case large
    case normal
}

enum Settings {
    static let displayStyle = FeedDisplayStyle.normal

    static var direatlyEnterVideo: Bool {
        set {
            UserDefaults.standard.set(newValue, forKey: "Settings.direatlyEnterVideo")
        }
        get {
            return UserDefaults.standard.bool(forKey: "Settings.direatlyEnterVideo")
        }
    }
}
