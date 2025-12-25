//
//  SearchRequest.swift
//  BilibiliLive
//
//  Created by Claude on 2024/12/24.
//

import Alamofire
import Foundation
import SwiftyJSON

// MARK: - Hot Search API

extension WebRequest {
    /// 获取B站热搜榜关键词
    static func requestHotSearch() async throws -> [HotSearchResult.HotWord] {
        let result: HotSearchResult = try await request(
            url: "https://s.search.bilibili.com/main/hotword"
        )
        return result.list
    }

    /// 搜索视频/番剧/用户等 (支持分页)
    /// - Parameters:
    ///   - key: 搜索关键词
    ///   - page: 页码 (1-50)
    /// - Returns: 搜索结果
    static func requestSearchResultPaginated(key: String, page: Int = 1) async throws -> SearchResult {
        try await request(
            url: "https://api.bilibili.com/x/web-interface/wbi/search/all/v2",
            parameters: ["keyword": key, "page": page]
        )
    }

    /// 按类型搜索 (视频/直播/番剧/用户) 支持分页
    /// - Parameters:
    ///   - key: 搜索关键词
    ///   - type: 搜索类型
    ///   - page: 页码
    /// - Returns: 搜索结果数组
    static func requestSearchByType(
        key: String,
        type: SearchContentType,
        page: Int = 1
    ) async throws -> TypedSearchResult {
        try await request(
            url: "https://api.bilibili.com/x/web-interface/wbi/search/type",
            parameters: [
                "keyword": key,
                "search_type": type.rawValue,
                "page": page,
            ]
        )
    }
}

// MARK: - Data Models

/// 热搜榜结果
struct HotSearchResult: Codable {
    let list: [HotWord]

    struct HotWord: Codable, Hashable, Identifiable {
        let keyword: String
        let show_name: String
        let pos: Int
        let icon: String?
        let hot_id: Int

        var id: Int { hot_id }

        /// 是否为前三名 (用于特殊颜色显示)
        var isTop3: Bool { pos <= 3 }
    }
}

/// 搜索内容类型
enum SearchContentType: String, CaseIterable {
    case video
    case bangumi = "media_bangumi"
    case movie = "media_ft"
    case live
    case user = "bili_user"
    case article

    var title: String {
        switch self {
        case .video: return "视频"
        case .bangumi: return "番剧"
        case .movie: return "影视"
        case .live: return "直播"
        case .user: return "用户"
        case .article: return "专栏"
        }
    }

    /// 是否支持分页加载更多
    var supportsPagination: Bool {
        switch self {
        case .video, .live: return true
        case .bangumi, .movie, .user, .article: return false
        }
    }
}

/// 分页状态
struct SearchPaginationState {
    var currentPage: Int = 1
    var hasMore: Bool = true
    var isLoading: Bool = false
    var totalResults: Int = 0

    mutating func reset() {
        currentPage = 1
        hasMore = true
        isLoading = false
        totalResults = 0
    }

    mutating func loadNextPage() {
        currentPage += 1
    }
}

/// 按类型搜索结果
struct TypedSearchResult: Decodable {
    let numResults: Int?
    let numPages: Int?
    let page: Int?
    let pagesize: Int?
    let result: [TypedResultItem]?

    var hasMore: Bool {
        guard let page = page, let numPages = numPages else { return false }
        return page < numPages
    }

    /// 解码时根据实际类型返回
    struct TypedResultItem: Decodable, Hashable {
        // 视频字段
        let aid: Int?
        let author: String?
        let title: String?
        let pic: String?
        let play: Int?
        let danmaku: Int?
        let duration: String?
        let pubdate: Int?
        let upic: String?

        // 直播字段
        let roomid: Int?
        let uname: String?
        let uface: String?
        let cover: String?
        let user_cover: String?
        let cate_name: String?
        let live_status: Int?

        // 用户字段
        let mid: Int?
        let usign: String?

        /// 转换为直播LiveRoom
        func toLiveRoom() -> SearchLiveResult.Result.LiveRoom? {
            guard let roomid = roomid,
                  let uname = uname else { return nil }
            return SearchLiveResult.Result.LiveRoom(
                uname: uname,
                uface: uface.flatMap { URL(string: $0.hasPrefix("//") ? "https:\($0)" : $0) },
                user_cover: user_cover.flatMap { URL(string: $0.hasPrefix("//") ? "https:\($0)" : $0) },
                cover: cover.flatMap { URL(string: $0.hasPrefix("//") ? "https:\($0)" : $0) },
                roomid: roomid,
                cate_name: cate_name ?? "",
                titleWithHtml: title ?? ""
            )
        }
    }
}

// MARK: - Pagination Video Result

/// 分页视频搜索结果 (用于加载更多)
struct PaginatedVideoResult: Decodable {
    let result: [VideoItem]?
    let numResults: Int?
    let numPages: Int?
    let page: Int?

    var hasMore: Bool {
        guard let page = page, let numPages = numPages else { return false }
        return page < numPages
    }

    struct VideoItem: Decodable, Hashable, DisplayData {
        let type: String?
        let author: String?
        let upic: String?
        let aid: Int
        let pubdate: Int?
        let danmaku: Int?
        let play: Int?
        let duration: String?
        private var titleRaw: String?
        private var picRaw: String?

        var title: String { (titleRaw ?? "").removingHTMLTags() }
        var ownerName: String { author ?? "" }
        var pic: URL? {
            guard let p = picRaw else { return nil }
            return URL(string: p.hasPrefix("//") ? "https:\(p)" : p)
        }

        var avatar: URL? {
            guard let u = upic else { return nil }
            return URL(string: u)
        }

        var date: String? { DateFormatter.stringFor(timestamp: pubdate) }
        var overlay: DisplayOverlay? {
            var leftItems = [DisplayOverlay.DisplayOverlayItem]()
            var rightItems = [DisplayOverlay.DisplayOverlayItem]()
            leftItems.append(DisplayOverlay.DisplayOverlayItem(icon: "play.rectangle", text: play == 0 ? "-" : play?.numberString() ?? "-"))
            leftItems.append(DisplayOverlay.DisplayOverlayItem(icon: "list.bullet.rectangle", text: (danmaku ?? 0) == 0 ? "-" : (danmaku ?? 0).numberString()))
            if let duration {
                rightItems.append(DisplayOverlay.DisplayOverlayItem(icon: nil, text: duration))
            }
            return DisplayOverlay(leftItems: leftItems, rightItems: rightItems)
        }

        enum CodingKeys: String, CodingKey {
            case type, author, upic, aid, pubdate, danmaku, play, duration
            case titleRaw = "title"
            case picRaw = "pic"
        }
    }
}

extension WebRequest {
    /// 分页搜索视频 (用于加载更多)
    static func requestMoreVideos(key: String, page: Int) async throws -> PaginatedVideoResult {
        try await request(
            url: "https://api.bilibili.com/x/web-interface/wbi/search/type",
            parameters: [
                "keyword": key,
                "search_type": "video",
                "page": page,
            ]
        )
    }

    /// 分页搜索直播 (用于加载更多)
    static func requestMoreLiveRooms(key: String, page: Int) async throws -> SearchLiveResult {
        try await request(
            url: "https://api.bilibili.com/x/web-interface/wbi/search/type",
            parameters: [
                "keyword": key,
                "search_type": "live",
                "page": page,
            ]
        )
    }
}
