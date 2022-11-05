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

    @UserDefault("Settings.livePlayerHack", defaultValue: true)
    static var livePlayerHack: Bool

    @UserDefaultCodable("Settings.mediaQuality", defaultValue: .quality_1080p)
    static var mediaQuality: MediaQualityEnum

    @UserDefault("Settings.losslessAudio", defaultValue: false)
    static var losslessAudio: Bool

    @UserDefault("Settings.preferHevc", defaultValue: false)
    static var preferHevc: Bool

    @UserDefault("Settings.defaultDanmuStatus", defaultValue: true)
    static var defaultDanmuStatus: Bool
}

struct MediaQuality {
    var qn: Int
    var fnval: Int
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
