//
//  Settings+TabBar.swift
//  BilibiliLive
//
//  Created by yicheng on 2026/3/5.
//

import Foundation

extension Settings {
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
        } else {
            tabBarPagePlacements = normalize(tabBarPagePlacements)
        }
    }

    static func setPlacements(_ placements: [TabBarPagePlacement]) {
        tabBarPagePlacements = normalize(placements)
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
}
