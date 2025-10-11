//
//  DateFormatter.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/10/23.
//

import Foundation

extension DateFormatter {
    static let date = {
        let formater = DateFormatter()
        formater.dateFormat = "yyyy-MM-dd"
        return formater
    }()

    static func stringFor(timestamp: Int?) -> String? {
        guard let timestamp = timestamp else { return nil }
        return date.string(from: Date(timeIntervalSince1970: TimeInterval(timestamp)))
    }
}
