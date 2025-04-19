//
//  Keys.swift
//  BilibiliLive
//
//  Created by yicheng on 2024/5/13.
//

import Foundation

enum Keys {
    static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15"
    static let liveReferer = "https://live.bilibili.com"
    static let referer = "https://www.bilibili.com"
    static func referer(for aid: Int) -> String {
        return "https://www.bilibili.com/video/av\(aid)"
    }
}
