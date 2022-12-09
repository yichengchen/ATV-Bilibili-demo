//
//  Logger.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/12/9.
//

import CocoaLumberjackSwift
import Foundation

class Logger {
    private static let fileLogger = DDFileLogger()
    static func setup() {
        DDLog.add(DDOSLogger.sharedInstance)
        let dataFormatter = DateFormatter()
        dataFormatter.setLocalizedDateFormatFromTemplate("YYYY/MM/dd HH:mm:ss:SSS")
        fileLogger.logFormatter = DDLogFileFormatterDefault(dateFormatter: dataFormatter)
        fileLogger.rollingFrequency = 60 * 60 * 24 // 24 hours
        fileLogger.logFileManager.maximumNumberOfLogFiles = 2
        fileLogger.doNotReuseLogFiles = true
        fileLogger.maximumFileSize = 1024 * 1024 * 5
        DDLog.add(fileLogger)
    }

    static func debug(_ items: Any...) {
        DDLogDebug(items.map { String(describing: $0) }.joined(separator: ","))
    }

    static func info(_ items: Any...) {
        DDLogInfo(items.map { String(describing: $0) }.joined(separator: ","))
    }

    static func warn(_ items: Any...) {
        DDLogWarn(items.map { String(describing: $0) }.joined(separator: ","))
    }

    static func latestLogPath() -> String? {
        fileLogger.logFileManager.sortedLogFilePaths.first
    }

    static func oldestLogPath() -> String? {
        fileLogger.logFileManager.sortedLogFilePaths.last
    }
}
