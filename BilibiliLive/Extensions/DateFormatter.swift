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

    /// 将时间戳转换为用户友好的相对时间格式（如"刚刚"、"3分钟前"、"2天前"）
    /// - Parameter timestamp: Unix时间戳（秒）
    /// - Returns: 格式化后的相对时间字符串，如果timestamp为nil则返回nil
    static func relativeTimeStringFor(timestamp: Int?) -> String? {
        guard let timestamp = timestamp else { return nil }

        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let now = Date()
        let interval = now.timeIntervalSince(date)

        // 确保是过去的时间
        guard interval >= 0 else {
            return self.date.string(from: date)
        }

        let seconds = Int(interval)
        let minutes = seconds / 60
        let hours = minutes / 60
        let days = hours / 24
        let weeks = days / 7
        let months = days / 30
        let years = days / 365

        switch seconds {
        case 0..<10:
            return "刚刚"
        case 10..<60:
            return "\(seconds)秒前"
        case 60..<3600:
            return "\(minutes)分钟前"
        case 3600..<86400:
            return "\(hours)小时前"
        case 86400..<604800:
            return "\(days)天前"
        case 604800..<2592000:
            return "\(weeks)周前"
        case 2592000..<31536000:
            return "\(months)个月前"
        default:
            if years >= 1 {
                return "\(years)年前"
            }
            return self.date.string(from: date)
        }
    }
}
