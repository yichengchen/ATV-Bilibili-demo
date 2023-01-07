//
//  Settings.swift
//  BilibiliLive
//
//  Created by whw on 2022/10/19.
//

import Foundation

enum FeedDisplayStyle: Codable, CaseIterable {
    case large
    case normal
    case sideBar

    var hideInSetting: Bool {
        self == .sideBar
    }
}

enum Settings {
    @UserDefaultCodable("Settings.displayStyle", defaultValue: .normal)
    static var displayStyle: FeedDisplayStyle

    @UserDefault("Settings.direatlyEnterVideo", defaultValue: false)
    static var direatlyEnterVideo: Bool

    @UserDefaultCodable("Settings.mediaQuality", defaultValue: .quality_1080p)
    static var mediaQuality: MediaQualityEnum

    @UserDefaultCodable("Settings.danmuArea", defaultValue: .style_75)
    static var danmuArea: DanmuArea

    @UserDefault("Settings.losslessAudio", defaultValue: false)
    static var losslessAudio: Bool

    @UserDefault("Settings.preferHevc", defaultValue: false)
    static var preferHevc: Bool

    @UserDefault("Settings.defaultDanmuStatus", defaultValue: true)
    static var defaultDanmuStatus: Bool

    @UserDefault("Settings.danmuMask", defaultValue: true)
    static var danmuMask: Bool

    @UserDefault("Settings.vnMask", defaultValue: false)
    static var vnMask: Bool

    @UserDefault("Settings.loadHighestVideoOnly", defaultValue: false)
    static var loadHighestVideoOnly: Bool

    @UserDefault("Settings.contentMatch", defaultValue: true)
    static var contentMatch: Bool

    @UserDefault("Settings.continuePlay", defaultValue: true)
    static var continuePlay: Bool

    @UserDefault("DLNA.uuid", defaultValue: "")
    static var uuid: String

    @UserDefault("Settings.continouslyPlay", defaultValue: true)
    static var continouslyPlay: Bool
}

struct MediaQuality {
    var qn: Int
    var fnval: Int
}

enum DanmuArea: Codable, CaseIterable {
    case style_75
    case style_50
    case style_25
    case style_0
}

extension DanmuArea {
    var title: String {
        switch self {
        case .style_75:
            return "3/4屏"
        case .style_50:
            return "半屏"
        case .style_25:
            return "1/4屏"
        case .style_0:
            return "不限制"
        }
    }

    var percent: CGFloat {
        switch self {
        case .style_75:
            return 0.75
        case .style_50:
            return 0.5
        case .style_25:
            return 0.25
        case .style_0:
            return 1
        }
    }
}

enum MediaQualityEnum: Codable, CaseIterable {
    case quality_1080p
    case quality_2160p
    case quality_hdr_dolby
}

extension MediaQualityEnum {
    var desp: String {
        switch self {
        case .quality_1080p:
            return "1080p"
        case .quality_2160p:
            return "4K"
        case .quality_hdr_dolby:
            return "杜比视界"
        }
    }

    var qn: Int {
        switch self {
        case .quality_1080p:
            return 116
        case .quality_2160p:
            return 120
        case .quality_hdr_dolby:
            return 126
        }
    }

    var fnval: Int {
        switch self {
        case .quality_1080p:
            return 16
        case .quality_2160p:
            return 144
        case .quality_hdr_dolby:
            return 976
        }
    }
}
