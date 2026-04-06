//
//  FeaturedBrowserViewController.swift
//  BilibiliLive
//
//  Created by OpenAI on 2026/4/4.
//

import Foundation
import UIKit

private extension ApiRequest.FeedResp.Items {
    func toFeaturedFeedFlowItem(durationLimit: FeaturedDurationLimit) -> FeedFlowItem? {
        guard goto == "av", can_play == 1 else { return nil }
        guard FeaturedContentSafetyFilter.allows(feedItem: self) else { return nil }

        let aidValue = Int(param) ?? player_args?.aid ?? 0
        let cidValue = player_args?.cid ?? 0
        let durationValue = player_args?.duration ?? 0
        guard aidValue > 0, cidValue > 0, durationValue > 0 else { return nil }
        if let maxDuration = durationLimit.maxDuration, durationValue > maxDuration {
            return nil
        }

        return FeedFlowItem(aid: aidValue,
                            cid: cidValue,
                            title: title,
                            ownerName: ownerName,
                            coverURL: pic,
                            avatarURL: avatar,
                            duration: durationValue,
                            durationText: cover_right_text ?? TimeInterval(durationValue).timeString(),
                            viewCountText: cover_left_text_1 ?? "",
                            danmakuCountText: cover_left_text_2 ?? "",
                            reasonText: top_rcmd_reason ?? bottom_rcmd_reason)
    }
}

final class FeaturedBrowserViewController: FeedFlowBrowserViewController {
    init() {
        super.init(dataSource: FeaturedFeedFlowDataSource())
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class FeaturedFeedFlowDataSource: FeedFlowDataSource {
    let title = "精选"
    let defaultPreviewHintText = "停留后自动预览，按确认键进入短视频流"
    let loadingHintText = "正在加载精选短视频..."
    let emptyStateText = "当前精选短视频较少，请稍后重试"
    let emptyHintText = "可以在设置里调整精选视频时长上限"
    let loadFailureText = "精选加载失败，请稍后重试"
    let refreshFailureHintText = "已展示缓存内容，后台刷新失败"

    var reloadToken: String {
        "\(currentAccountMID)-\(Settings.featuredDurationLimit.title)-\(Settings.featuredPersonalizedRankingEnabled)-\(FeaturedRanker.rankVersion)-\(FeaturedContentSafetyFilter.version)"
    }

    var playerConfiguration: FeedFlowPlayerConfiguration {
        FeedFlowPlayerConfiguration { context in
            let discovery = FeaturedVideoDiscoveryPlugin(detail: context.detail,
                                                         currentPlayInfo: context.currentPlayInfo,
                                                         sequenceProvider: context.sequenceProvider)
            discovery.onPlayTemporary = context.playTemporaryOverride
            return [discovery]
        }
    }

    private let featuredFeedCache = FeaturedFeedCache.shared

    private var activeDurationLimit = Settings.featuredDurationLimit
    private var activePersonalizedEnabled = Settings.featuredPersonalizedRankingEnabled
    private var lastSourceIdx: Int?
    private var currentInterestProfile: FeaturedInterestProfile?
    private var sessionWatchSignals = [(PlayInfo, Int)]()
    private var items = [FeedFlowItem]()
    private var seenItemKeys = Set<String>()

    func reset() {
        activeDurationLimit = Settings.featuredDurationLimit
        activePersonalizedEnabled = Settings.featuredPersonalizedRankingEnabled
        lastSourceIdx = nil
        sessionWatchSignals = []
        items = []
        seenItemKeys = []

        if activePersonalizedEnabled {
            currentInterestProfile = FeaturedInterestProfileCache.shared.load(mid: currentAccountMID,
                                                                              rankVersion: FeaturedRanker.rankVersion)
        } else {
            currentInterestProfile = nil
        }
    }

    func loadCachedItems() -> [FeedFlowItem]? {
        guard let cachedSnapshot = featuredFeedCache.load(durationLimit: activeDurationLimit,
                                                          accountMID: currentAccountMID,
                                                          personalizedEnabled: activePersonalizedEnabled)
        else {
            return nil
        }

        lastSourceIdx = cachedSnapshot.lastSourceIdx
        items = cachedSnapshot.items
            .filter(FeaturedContentSafetyFilter.allows(cachedItem:))
            .map(FeedFlowItem.init(cached:))
        seenItemKeys = Set(items.map(\.identityKey))
        return items
    }

    func refreshFromStart(targetCount: Int, maxSourcePages: Int) async throws -> [FeedFlowItem] {
        if activePersonalizedEnabled, currentInterestProfile == nil {
            await refreshInterestProfileInBackground()
        }

        let freshItems = try await buildFreshItems(targetCount: targetCount, maxSourcePages: maxSourcePages)
        var visibleItems = freshItems

        if activePersonalizedEnabled {
            let profile = effectiveProfile()
            if profile.sampleTier != .none {
                visibleItems = FeaturedRanker.rank(freshItems, profile: profile)
            }
        }

        items = visibleItems
        seenItemKeys = Set(visibleItems.map(\.identityKey))
        featuredFeedCache.save(items: visibleItems,
                               lastSourceIdx: lastSourceIdx,
                               durationLimit: activeDurationLimit,
                               accountMID: currentAccountMID,
                               personalizedEnabled: activePersonalizedEnabled)
        return visibleItems
    }

    func loadMoreItems(targetCount: Int, maxSourcePages: Int) async throws -> [FeedFlowItem] {
        var pagesScanned = 0
        var accepted = [FeedFlowItem]()

        while accepted.count < targetCount, pagesScanned < maxSourcePages {
            let sourceItems = try await requestNextSourcePage()
            pagesScanned += 1

            let newItems = sourceItems
                .compactMap { $0.toFeaturedFeedFlowItem(durationLimit: activeDurationLimit) }
                .filter { seenItemKeys.insert($0.identityKey).inserted }

            guard !newItems.isEmpty else { continue }
            accepted.append(contentsOf: newItems)
        }

        guard !accepted.isEmpty else { return [] }

        let sorted: [FeedFlowItem]
        if activePersonalizedEnabled {
            sorted = FeaturedRanker.rankBatch(accepted, profile: effectiveProfile())
        } else {
            sorted = accepted
        }

        items.append(contentsOf: sorted)
        featuredFeedCache.save(items: items,
                               lastSourceIdx: lastSourceIdx,
                               durationLimit: activeDurationLimit,
                               accountMID: currentAccountMID,
                               personalizedEnabled: activePersonalizedEnabled)
        return sorted
    }

    func didRecordPositiveWatchSignal(playInfo: PlayInfo, watchedSeconds: Int) {
        let identityKey = FeedFlowItem.identityKey(for: playInfo)
        if sessionWatchSignals.contains(where: { FeedFlowItem.identityKey(for: $0.0) == identityKey }) {
            return
        }
        sessionWatchSignals.append((playInfo, watchedSeconds))
    }

    private func buildFreshItems(targetCount: Int, maxSourcePages: Int) async throws -> [FeedFlowItem] {
        var loadedItems = [FeedFlowItem]()
        var nextSourceIdx: Int?
        var seenKeys = Set<String>()
        var pagesScanned = 0

        while loadedItems.count < targetCount, pagesScanned < maxSourcePages {
            let sourceItems: [ApiRequest.FeedResp.Items]
            if let nextSourceIdx {
                sourceItems = try await ApiRequest.getFeeds(lastIdx: nextSourceIdx)
            } else {
                sourceItems = try await ApiRequest.getFeeds()
            }
            pagesScanned += 1
            nextSourceIdx = sourceItems.last?.idx

            let filtered = sourceItems
                .compactMap { $0.toFeaturedFeedFlowItem(durationLimit: activeDurationLimit) }
                .filter { seenKeys.insert($0.identityKey).inserted }
            loadedItems.append(contentsOf: filtered)
        }

        lastSourceIdx = nextSourceIdx
        return loadedItems
    }

    private func requestNextSourcePage() async throws -> [ApiRequest.FeedResp.Items] {
        let sourceItems: [ApiRequest.FeedResp.Items]
        if let lastSourceIdx {
            sourceItems = try await ApiRequest.getFeeds(lastIdx: lastSourceIdx)
        } else {
            sourceItems = try await ApiRequest.getFeeds()
        }
        lastSourceIdx = sourceItems.last?.idx
        return sourceItems
    }

    private var currentAccountMID: Int {
        ApiRequest.getToken()?.mid ?? 0
    }

    private func effectiveProfile() -> FeaturedInterestProfile {
        let base = currentInterestProfile ?? .empty
        return base.boosted(with: sessionWatchSignals)
    }

    private func refreshInterestProfileInBackground() async {
        let history: [HistoryData]
        do {
            history = try await WebRequest.requestHistory()
        } catch {
            Logger.warn("featured personalized ranking profile refresh failed: \(error)")
            return
        }
        guard !Task.isCancelled else { return }

        let profile = FeaturedInterestProfileBuilder.build(from: history)
        currentInterestProfile = profile

        if profile.sampleTier != .none {
            FeaturedInterestProfileCache.shared.save(profile,
                                                     mid: currentAccountMID,
                                                     rankVersion: FeaturedRanker.rankVersion)
        }
    }
}
