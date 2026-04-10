//
//  Settings+TabBar.swift
//  BilibiliLive
//
//  Created by yicheng on 2026/3/5.
//

import Foundation

extension Settings {
    private static let tabBarPlacementSchemaCurrent = 3
    static let maxTabBarPageCount = 9
    static let minTabBarPageCount = 3

    enum TabBarPageSection: String, Codable, CaseIterable {
        case tabBar
        case personal

        var title: String {
            switch self {
            case .tabBar:
                return "导航栏"
            case .personal:
                return "我的页面"
            }
        }
    }

    struct TabBarPagePlacement: Codable, Hashable {
        var page: TabBarPage
        var section: TabBarPageSection
    }

    @UserDefaultCodable("Settings.tabBarPagePlacements", defaultValue: [])
    static var tabBarPagePlacements: [TabBarPagePlacement]

    @UserDefault("Settings.tabBarPagePlacementsSchemaVersion", defaultValue: 0)
    static var tabBarPagePlacementsSchemaVersion: Int

    // 导航栏
    static var tabBarPages: [TabBarPage] {
        normalizedPlacements.filter { $0.section == .tabBar }.map(\.page)
    }

    // 个人中心
    static var personalPages: [TabBarPage] {
        normalizedPlacements.filter { $0.section == .personal }.map(\.page)
    }

    // 初始化
    static func bootstrapTabBarPlacementModelIfNeeded() {
        if tabBarPagePlacements.isEmpty {
            tabBarPagePlacements = defaultPlacements
            tabBarPagePlacementsSchemaVersion = tabBarPlacementSchemaCurrent
        } else if tabBarPagePlacementsSchemaVersion < tabBarPlacementSchemaCurrent {
            tabBarPagePlacements = migratePlacementsIfNeeded(tabBarPagePlacements,
                                                             from: tabBarPagePlacementsSchemaVersion)
            tabBarPagePlacementsSchemaVersion = tabBarPlacementSchemaCurrent
        } else {
            tabBarPagePlacements = normalize(tabBarPagePlacements)
        }
    }

    static func setPlacements(_ placements: [TabBarPagePlacement]) {
        tabBarPagePlacements = normalize(placements)
        tabBarPagePlacementsSchemaVersion = tabBarPlacementSchemaCurrent
        NotificationCenter.default.post(name: .tabBarPagesDidChange, object: nil)
    }

    static var currentPlacements: [TabBarPagePlacement] {
        normalizedPlacements
    }

    static var defaultPlacements: [TabBarPagePlacement] {
        TabBarPage.allConfigurablePages.map { page in
            let section: TabBarPageSection = TabBarPage.defaultTabBarPages.contains(page) ? .tabBar : .personal
            return .init(page: page, section: page.isFixedInTabBar ? .tabBar : section)
        }
    }

    // MARK: - Private

    private static var normalizedPlacements: [TabBarPagePlacement] {
        let source = tabBarPagePlacements.isEmpty ? defaultPlacements : tabBarPagePlacements
        let normalized = normalize(source)
        if normalized != source {
            tabBarPagePlacements = normalized
        }
        return normalized
    }

    // 标准化
    private static func normalize(_ placements: [TabBarPagePlacement]) -> [TabBarPagePlacement] {
        var result = [TabBarPagePlacement]()
        var used = Set<TabBarPage>()

        for placement in placements {
            guard TabBarPage.allConfigurablePages.contains(placement.page), !used.contains(placement.page) else { continue }
            let section: TabBarPageSection = placement.page.isFixedInTabBar ? .tabBar : placement.section
            result.append(.init(page: placement.page, section: section))
            used.insert(placement.page)
        }

        for page in TabBarPage.allConfigurablePages where !used.contains(page) {
            let section: TabBarPageSection = TabBarPage.defaultTabBarPages.contains(page) ? .tabBar : .personal
            result.append(.init(page: page, section: page.isFixedInTabBar ? .tabBar : section))
        }

        if !result.contains(where: { $0.page == .personal && $0.section == .tabBar }) {
            result.removeAll { $0.page == .personal }
            result.append(.init(page: .personal, section: .tabBar))
        }

        return result
    }

    private static var legacyDefaultTabBarPages: [TabBarPage] {
        [.live, .feed, .hot, .ranking, .follows, .favorite, .personal, .search]
    }

    private static var legacyAllConfigurablePages: [TabBarPage] {
        TabBarPage.allConfigurablePages.filter { $0 != .featured }
    }

    private static var legacyDefaultPlacements: [TabBarPagePlacement] {
        legacyAllConfigurablePages.map { page in
            let section: TabBarPageSection = legacyDefaultTabBarPages.contains(page) ? .tabBar : .personal
            return .init(page: page, section: page.isFixedInTabBar ? .tabBar : section)
        }
    }

    private static var preTVRecommendDefaultTabBarPages: [TabBarPage] {
        [.live, .feed, .featured, .hot, .ranking, .follows, .favorite, .personal, .search]
    }

    private static var preTVRecommendAllConfigurablePages: [TabBarPage] {
        TabBarPage.allConfigurablePages.filter { $0 != .tvRecommend }
    }

    private static var preTVRecommendDefaultPlacements: [TabBarPagePlacement] {
        preTVRecommendAllConfigurablePages.map { page in
            let section: TabBarPageSection = preTVRecommendDefaultTabBarPages.contains(page) ? .tabBar : .personal
            return .init(page: page, section: page.isFixedInTabBar ? .tabBar : section)
        }
    }

    private static func migratePlacementsIfNeeded(_ placements: [TabBarPagePlacement], from version: Int) -> [TabBarPagePlacement] {
        var migrated = placements
        if version < 2 {
            migrated = migratePlacementsAddingFeatured(migrated)
        }
        if version < 3 {
            migrated = migratePlacementsAddingTVRecommend(migrated)
        }
        return normalize(migrated)
    }

    private static func migratePlacementsAddingFeatured(_ placements: [TabBarPagePlacement]) -> [TabBarPagePlacement] {
        let isLegacyDefault = normalizeLegacy(placements) == legacyDefaultPlacements
        var migrated = placements.filter { $0.page != .featured }

        let featuredPlacement = TabBarPagePlacement(page: .featured, section: isLegacyDefault ? .tabBar : .personal)
        if isLegacyDefault {
            if let feedIndex = migrated.firstIndex(where: { $0.page == .feed }) {
                migrated.insert(featuredPlacement, at: feedIndex + 1)
            } else {
                migrated.append(featuredPlacement)
            }
        } else {
            migrated.append(featuredPlacement)
        }

        return normalize(migrated)
    }

    private static func migratePlacementsAddingTVRecommend(_ placements: [TabBarPagePlacement]) -> [TabBarPagePlacement] {
        let isPreTVRecommendDefault = normalizeBeforeTVRecommend(placements) == preTVRecommendDefaultPlacements
        var migrated = placements.filter { $0.page != .tvRecommend }

        let tvRecommendPlacement = TabBarPagePlacement(page: .tvRecommend, section: isPreTVRecommendDefault ? .tabBar : .personal)
        if isPreTVRecommendDefault {
            // Keep the upgraded default layout within the 9-tab limit.
            migrated = migrated.map { placement in
                guard placement.page == .search else { return placement }
                return .init(page: .search, section: .personal)
            }
            if let featuredIndex = migrated.firstIndex(where: { $0.page == .featured }) {
                migrated.insert(tvRecommendPlacement, at: featuredIndex + 1)
            } else {
                migrated.append(tvRecommendPlacement)
            }
        } else {
            migrated.append(tvRecommendPlacement)
        }

        return normalize(migrated)
    }

    private static func normalizeLegacy(_ placements: [TabBarPagePlacement]) -> [TabBarPagePlacement] {
        var result = [TabBarPagePlacement]()
        var used = Set<TabBarPage>()

        for placement in placements {
            guard legacyAllConfigurablePages.contains(placement.page), !used.contains(placement.page) else { continue }
            let section: TabBarPageSection = placement.page.isFixedInTabBar ? .tabBar : placement.section
            result.append(.init(page: placement.page, section: section))
            used.insert(placement.page)
        }

        for page in legacyAllConfigurablePages where !used.contains(page) {
            let section: TabBarPageSection = legacyDefaultTabBarPages.contains(page) ? .tabBar : .personal
            result.append(.init(page: page, section: page.isFixedInTabBar ? .tabBar : section))
        }

        if !result.contains(where: { $0.page == .personal && $0.section == .tabBar }) {
            result.removeAll { $0.page == .personal }
            result.append(.init(page: .personal, section: .tabBar))
        }

        return result
    }

    private static func normalizeBeforeTVRecommend(_ placements: [TabBarPagePlacement]) -> [TabBarPagePlacement] {
        var result = [TabBarPagePlacement]()
        var used = Set<TabBarPage>()

        for placement in placements {
            guard preTVRecommendAllConfigurablePages.contains(placement.page), !used.contains(placement.page) else { continue }
            let section: TabBarPageSection = placement.page.isFixedInTabBar ? .tabBar : placement.section
            result.append(.init(page: placement.page, section: section))
            used.insert(placement.page)
        }

        for page in preTVRecommendAllConfigurablePages where !used.contains(page) {
            let section: TabBarPageSection = preTVRecommendDefaultTabBarPages.contains(page) ? .tabBar : .personal
            result.append(.init(page: page, section: page.isFixedInTabBar ? .tabBar : section))
        }

        if !result.contains(where: { $0.page == .personal && $0.section == .tabBar }) {
            result.removeAll { $0.page == .personal }
            result.append(.init(page: .personal, section: .tabBar))
        }

        return result
    }
}
