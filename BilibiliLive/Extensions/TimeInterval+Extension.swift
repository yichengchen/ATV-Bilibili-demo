//
//  TimeInterval+Extension.swift
//  BilibiliLive
//
//  Created by AI on 2025/11/21.
//

import Foundation

extension TimeInterval {
    enum DurationStyle {
        case positional // 位置样式: "1:23:45" 或 "12:34"
        case brief // 简短样式: "1h 23m 45s"
    }

    /// 将时间间隔格式化为时长字符串
    /// - Parameter style: 格式化样式,默认为 .positional
    /// - Returns: 格式化后的时长字符串
    func timeString(style: DurationStyle = .positional) -> String {
        let formatter = DateComponentsFormatter()

        switch style {
        case .positional:
            if self >= 3600 {
                formatter.allowedUnits = [.hour, .minute, .second]
            } else {
                formatter.allowedUnits = [.minute, .second]
            }
            formatter.zeroFormattingBehavior = .pad
            formatter.unitsStyle = .positional
        case .brief:
            formatter.allowedUnits = [.hour, .minute, .second]
            formatter.unitsStyle = .brief
        }

        return formatter.string(from: self) ?? ""
    }
}
