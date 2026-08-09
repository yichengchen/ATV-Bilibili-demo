//
//  FeedFlowModels.swift
//  BilibiliLive
//

import Foundation

struct FeedFlowItem: Hashable {
    let identityKey: String
    let aid: Int
    let cid: Int?
    let epid: Int?
    let seasonId: Int?
    let subType: Int?
    let title: String
    let ownerName: String
    let coverURL: URL?
    let avatarURL: URL?
    let durationText: String
    let viewCountText: String
    let danmakuCountText: String
    let reasonText: String?

    init(aid: Int,
         cid: Int? = nil,
         epid: Int? = nil,
         seasonId: Int? = nil,
         subType: Int? = nil,
         title: String,
         ownerName: String,
         coverURL: URL?,
         avatarURL: URL? = nil,
         durationText: String = "",
         viewCountText: String = "",
         danmakuCountText: String = "",
         reasonText: String? = nil,
         identityKey: String? = nil)
    {
        self.aid = aid
        self.cid = cid
        self.epid = epid
        self.seasonId = seasonId
        self.subType = subType
        self.title = title
        self.ownerName = ownerName
        self.coverURL = coverURL
        self.avatarURL = avatarURL
        self.durationText = durationText
        self.viewCountText = viewCountText
        self.danmakuCountText = danmakuCountText
        self.reasonText = reasonText
        self.identityKey = identityKey ?? Self.makeIdentityKey(aid: aid, epid: epid, seasonId: seasonId)
    }

    var playInfo: PlayInfo {
        PlayInfo(aid: aid,
                 cid: cid,
                 epid: epid,
                 seasonId: seasonId,
                 subType: subType,
                 title: title,
                 ownerName: ownerName,
                 coverURL: coverURL)
    }

    var metaText: String {
        [ownerName, durationText]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    var listMetaText: String {
        ownerName.isEmpty ? durationText : ownerName
    }

    static func makeIdentityKey(aid: Int, epid: Int? = nil, seasonId: Int? = nil) -> String {
        if let epid, epid > 0 {
            return "epid-\(epid)"
        }
        if let seasonId, seasonId > 0 {
            return "season-\(seasonId)"
        }
        return "aid-\(aid)"
    }

    static func identityKey(for playInfo: PlayInfo) -> String {
        makeIdentityKey(aid: playInfo.aid,
                        epid: playInfo.epid,
                        seasonId: playInfo.seasonId)
    }
}

@MainActor
protocol FeedFlowDataSource: AnyObject {
    var title: String { get }
    var reloadToken: String { get }
    var autoReloadInterval: TimeInterval? { get }
    var defaultPreviewHintText: String { get }
    var loadingHintText: String { get }
    var emptyStateText: String { get }
    var emptyHintText: String { get }
    var loadFailureText: String { get }
    var initialTargetCount: Int { get }
    var initialMaxSourcePages: Int { get }
    var trailingPrefetchTargetCount: Int { get }
    var trailingMaxSourcePages: Int { get }
    func reset()
    func refreshFromStart(targetCount: Int, maxSourcePages: Int) async throws -> [FeedFlowItem]
    func loadMoreItems(targetCount: Int, maxSourcePages: Int) async throws -> [FeedFlowItem]
}

extension FeedFlowDataSource {
    var autoReloadInterval: TimeInterval? { nil }
    var defaultPreviewHintText: String { "停留后自动预览，按确认键进入视频流" }
    var loadingHintText: String { "正在加载视频..." }
    var emptyStateText: String { "当前视频较少，请稍后重试" }
    var emptyHintText: String { "稍后再试" }
    var loadFailureText: String { "加载失败，请稍后重试" }
    var initialTargetCount: Int { 12 }
    var initialMaxSourcePages: Int { 5 }
    var trailingPrefetchTargetCount: Int { 8 }
    var trailingMaxSourcePages: Int { 3 }
}
