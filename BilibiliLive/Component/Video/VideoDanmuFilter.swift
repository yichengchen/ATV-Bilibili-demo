//
//  VideoDanmuFilter.swift
//  BilibiliLive
//
//  Created by yicheng on 2024/12/13.
//

import UIKit

class VideoDanmuFilter {
    static let shared = VideoDanmuFilter()

    private var stringFilters = [String]()
    private var regexFilters = [Regex<AnyRegexOutput>]()
    private init() {
        refreshCache(rules: VideoDanmuFilterStorage.filters)
    }

    func accept(_ danmu: String) -> Bool {
        for filter in stringFilters {
            if danmu.contains(filter) {
                return false
            }
        }

        for filter in regexFilters {
            if danmu.contains(filter) {
                return false
            }
        }
        return true
    }

    func autoUpdate() {
        if Date().timeIntervalSince(VideoDanmuFilterStorage.lastUpdate) > 60 * 60 * 24 {
            Task {
                await update()
            }
        }
    }

    @discardableResult
    func update() async -> String {
        VideoDanmuFilterStorage.lastUpdate = Date()
        let data = await WebRequest.requestDanmuFilterList()
        let rules = data.rule.filter({ $0.type == 0 || $0.type == 1 })
        if !rules.isEmpty {
            VideoDanmuFilterStorage.filters = rules
            refreshCache(rules: rules)
        }
        return data.toast ?? ""
    }

    private func refreshCache(rules: [VideoDanmuFilterData.Rule]) {
        stringFilters.removeAll()
        regexFilters.removeAll()
        for filter in rules {
            switch filter.type {
            case 0:
                stringFilters.append(filter.filter)
            case 1:
                if let regex = try? Regex(filter.filter) {
                    regexFilters.append(regex)
                }
            default:
                break
            }
        }
    }
}

private enum VideoDanmuFilterStorage {
    @UserDefaultCodable("VideoDanmuFilter.filters", defaultValue: [])
    static var filters: [VideoDanmuFilterData.Rule]

    @UserDefault("VideoDanmuFilter.lastUpdate", defaultValue: Date(timeIntervalSince1970: 0))
    static var lastUpdate: Date
}

private extension WebRequest.EndPoint {
    static let danmuFilter = "https://api.bilibili.com/x/dm/filter/user"
}

private struct VideoDanmuFilterData: Codable {
    struct Rule: Codable {
        let filter: String
        let type: Int
    }

    let rule: [Rule]
    let toast: String?
}

private extension WebRequest {
    static func requestDanmuFilterList() async -> VideoDanmuFilterData {
        do {
            let resp: VideoDanmuFilterData = try await request(url: EndPoint.danmuFilter)
            return resp
        } catch let err {
            return VideoDanmuFilterData(rule: [], toast: "\(err)")
        }
    }
}
