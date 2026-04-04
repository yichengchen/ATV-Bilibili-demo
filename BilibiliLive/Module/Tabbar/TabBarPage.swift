//
//  TabBarPage.swift
//  BilibiliLive
//

import Foundation
import UIKit

enum TabBarPage: String, CaseIterable, Codable {
    case live
    case feed
    case featured
    case hot
    case ranking
    case follows
    case favorite
    case personal
    case search
    case followBangumi
    case followUps
    case toView
    case history
    case weeklyWatch

    var title: String {
        switch self {
        case .live:
            return "直播"
        case .feed:
            return "推荐"
        case .featured:
            return "精选"
        case .hot:
            return "热门"
        case .ranking:
            return "排行榜"
        case .follows:
            return "关注"
        case .favorite:
            return "收藏"
        case .personal:
            return "我的"
        case .search:
            return "搜索"
        case .followBangumi:
            return "追番追剧"
        case .followUps:
            return "关注UP"
        case .toView:
            return "稍后再看"
        case .history:
            return "历史记录"
        case .weeklyWatch:
            return "每周必看"
        }
    }

    var isFixedInTabBar: Bool {
        self == .personal
    }

    var requirePresentInPersonalPage: Bool {
        switch self {
        case .favorite, .search, .followBangumi:
            return true
        default:
            return false
        }
    }

    static var defaultTabBarPages: [TabBarPage] {
        [.live, .feed, .featured, .hot, .ranking, .follows, .favorite, .personal, .search]
    }

    static var allConfigurablePages: [TabBarPage] {
        return allCases
    }
}
