//
//  TVRecommendBrowserViewController.swift
//  BilibiliLive
//
//  Created by OpenAI on 2026/4/9.
//

import Foundation
import UIKit

private extension TvOTTAutonomyResponse.Card {
    func toTVRecommendItem() -> FeedFlowItem? {
        guard cardType == "small_popular_ugc" else { return nil }
        guard let jumpId, jumpId > 0 else { return nil }
        guard let title, !title.isEmpty else { return nil }

        return FeedFlowItem(aid: jumpId,
                            title: title,
                            ownerName: "",
                            coverURL: cover,
                            reasonText: nil,
                            identityKey: FeedFlowItem.makeIdentityKey(aid: jumpId))
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
    let title = "TV推荐"
    let defaultPreviewHintText = "停留后自动预览，按确认键进入推荐视频流"
    let loadingHintText = "正在加载TV推荐..."
    let emptyStateText = "当前 TV 推荐视频较少，请稍后重试"
    let emptyHintText = "云视听首页接口当前未返回推荐视频卡片"
    let loadFailureText = "TV推荐加载失败，请稍后重试"
    let refreshFailureHintText = "TV推荐刷新失败"

    var reloadToken: String {
        "tv-ott-\(currentAccountMID)"
    }

    var playerConfiguration: FeedFlowPlayerConfiguration { .empty }

    func reset() {}

    func refreshFromStart(targetCount _: Int, maxSourcePages _: Int) async throws -> [FeedFlowItem] {
        let response = try await TvOTTApiRequest.requestAutonomyIndex()
        return uniqueItems(from: response.data ?? [])
    }

    func loadMoreItems(targetCount _: Int, maxSourcePages _: Int) async throws -> [FeedFlowItem] {
        []
    }

    private var currentAccountMID: Int {
        ApiRequest.getToken()?.mid ?? 0
    }

    private func uniqueItems(from cards: [TvOTTAutonomyResponse.Card]) -> [FeedFlowItem] {
        var seenIdentityKeys = Set<String>()
        return cards
            .compactMap { $0.toTVRecommendItem() }
            .filter { seenIdentityKeys.insert($0.identityKey).inserted }
    }
}
