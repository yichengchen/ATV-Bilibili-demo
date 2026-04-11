//
//  TVRecommendBrowserViewController.swift
//  BilibiliLive
//
//  Created by OpenAI on 2026/4/9.
//

import Foundation
import UIKit

private extension WebTopFeedRecommendResponse.Item {
    func toTVRecommendItem() -> FeedFlowItem? {
        guard goto == "av" else { return nil }
        guard let aid = id, aid > 0 else { return nil }
        guard let cid, cid > 0 else { return nil }
        guard let title, !title.isEmpty else { return nil }

        let durationValue = duration ?? 0
        let coverURL = pic.flatMap(URL.init(string:))?.addSchemeIfNeed()
        let reasonContent = rcmd_reason?.content?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let avatarURL = owner?.face.flatMap(URL.init(string:))?.addSchemeIfNeed()

        return FeedFlowItem(aid: aid,
                            cid: cid,
                            title: title,
                            ownerName: owner?.name ?? "",
                            coverURL: coverURL,
                            avatarURL: avatarURL,
                            duration: duration,
                            durationText: durationValue > 0 ? TimeInterval(durationValue).timeString() : "",
                            viewCountText: (stat?.view ?? 0).numberString(),
                            danmakuCountText: (stat?.danmaku ?? 0).numberString(),
                            reasonText: reasonContent?.isEmpty == false ? reasonContent : nil,
                            identityKey: FeedFlowItem.makeIdentityKey(aid: aid))
    }
}

final class TVRecommendBrowserViewController: FeedFlowBrowserViewController {
    init() {
        super.init(dataSource: TVRecommendFeedFlowDataSource())
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class TVRecommendFeedFlowDataSource: FeedFlowDataSource {
    private let pageSize = 12

    private var nextPageIndex = 1
    private var hasMore = true
    private var items = [FeedFlowItem]()
    private var seenItemKeys = Set<String>()

    let title = "TV推荐"
    let defaultPreviewHintText = "停留后自动预览，按确认键进入推荐视频流"
    let loadingHintText = "正在加载推荐视频..."
    let emptyStateText = "当前暂无可展示的推荐视频"
    let emptyHintText = "稍后再试或切换账号刷新推荐内容"
    let loadFailureText = "推荐视频加载失败，请稍后重试"
    let refreshFailureHintText = "已展示现有推荐内容，后台刷新失败"

    var reloadToken: String {
        "tv-web-\(currentAccountMID)"
    }

    var playerConfiguration: FeedFlowPlayerConfiguration { .empty }

    func reset() {
        nextPageIndex = 1
        hasMore = true
        items = []
        seenItemKeys = []
    }

    func refreshFromStart(targetCount: Int, maxSourcePages: Int) async throws -> [FeedFlowItem] {
        reset()
        let loadedItems = try await loadMoreUntilTarget(targetCount: targetCount, maxSourcePages: maxSourcePages)
        items = loadedItems
        return loadedItems
    }

    func loadMoreItems(targetCount: Int, maxSourcePages: Int) async throws -> [FeedFlowItem] {
        let appended = try await loadMoreUntilTarget(targetCount: targetCount, maxSourcePages: maxSourcePages)
        items.append(contentsOf: appended)
        return appended
    }

    private var currentAccountMID: Int {
        ApiRequest.getToken()?.mid ?? 0
    }

    private func loadMoreUntilTarget(targetCount: Int, maxSourcePages: Int) async throws -> [FeedFlowItem] {
        guard hasMore else { return [] }

        var pagesScanned = 0
        var accepted = [FeedFlowItem]()

        while accepted.count < targetCount, pagesScanned < maxSourcePages, hasMore {
            let pageIndex = nextPageIndex
            let response = try await WebRequest.requestTopFeedRecommend(pageIndex: pageIndex, pageSize: pageSize)
            nextPageIndex += 1
            pagesScanned += 1

            let pageItems = response.item
            let newItems = pageItems
                .compactMap { $0.toTVRecommendItem() }
                .filter { seenItemKeys.insert($0.identityKey).inserted }

            #if DEBUG
                Logger.debug("[TVRecommend] page=\(pageIndex) raw=\(pageItems.count) accepted=\(newItems.count) totalSeen=\(seenItemKeys.count)")
            #endif

            if pageItems.isEmpty || newItems.isEmpty {
                hasMore = false
            }

            accepted.append(contentsOf: newItems)
        }

        return accepted
    }
}
