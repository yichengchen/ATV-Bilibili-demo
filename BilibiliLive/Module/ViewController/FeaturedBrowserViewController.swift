//
//  FeaturedBrowserViewController.swift
//  BilibiliLive
//
//  Created by OpenAI on 2026/4/4.
//

import Kingfisher
import SnapKit
import UIKit

struct RecommendedVideoItem: Hashable {
    let aid: Int
    let cid: Int
    let idx: Int
    let title: String
    let ownerName: String
    let coverURL: URL?
    let avatarURL: URL?
    let duration: Int
    let durationText: String
    let viewCountText: String
    let danmakuCountText: String
    let reasonText: String?

    var playInfo: PlayInfo {
        PlayInfo(aid: aid,
                 cid: cid,
                 title: title,
                 ownerName: ownerName,
                 coverURL: coverURL,
                 duration: duration)
    }

    var metaText: String {
        [ownerName, durationText].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    var listMetaText: String {
        ownerName.isEmpty ? durationText : ownerName
    }
}

extension ApiRequest.FeedResp.Items {
    func toRecommendedVideoItem(durationLimit: FeaturedDurationLimit) -> RecommendedVideoItem? {
        guard goto == "av", can_play == 1 else { return nil }
        let aidValue = Int(param) ?? player_args?.aid ?? 0
        let cidValue = player_args?.cid ?? 0
        let durationValue = player_args?.duration ?? 0
        guard aidValue > 0, cidValue > 0, durationValue > 0 else { return nil }
        if let maxDuration = durationLimit.maxDuration, durationValue > maxDuration {
            return nil
        }
        return RecommendedVideoItem(aid: aidValue,
                                    cid: cidValue,
                                    idx: idx,
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

class FeaturedBrowserViewController: UIViewController, BLTabBarContentVCProtocol {
    private let preloadDelayNs: UInt64 = 1_000_000_000
    private let initialFilteredTargetCount = 12
    private let initialMaxSourcePages = 5
    private let trailingPrefetchTargetCount = 8
    private let trailingMaxSourcePages = 3

    private var items = [RecommendedVideoItem]()
    private var focusedIndex = 0
    private var lastSourceIdx: Int?
    private var isLoading = false
    private var activeDurationLimit = Settings.featuredDurationLimit
    private var activePersonalizedEnabled = Settings.featuredPersonalizedRankingEnabled
    private var previewTask: Task<Void, Never>?
    private var dataLoadTask: Task<Void, Never>?
    private let playContextCache = PlayContextCache()
    private let featuredFeedCache = FeaturedFeedCache.shared
    private lazy var mediaWarmupManager = PlayerMediaWarmupManager(playContextCache: playContextCache)
    private lazy var sequenceProvider = VideoSequenceProvider(seq: [])
    private var lastPlayedSequenceKey: String?
    private var hasUserInteractedSinceReload = false
    private var isPresentingFeedFlow = false

    // 智能排序状态
    private var currentInterestProfile: FeaturedInterestProfile?
    private var sessionWatchSignals: [(PlayInfo, Int)] = []

    private var previewController: VideoPlayerViewController?

    private lazy var listCollectionView: UICollectionView = {
        let layout = UICollectionViewCompositionalLayout { _, _ in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(132))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(132))
            let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = 16
            section.contentInsets = NSDirectionalEdgeInsets(top: 24, leading: 0, bottom: 24, trailing: 20)
            return section
        }
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.remembersLastFocusedIndexPath = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.clipsToBounds = false
        collectionView.allowsSelection = true
        collectionView.register(FeaturedVideoListCell.self, forCellWithReuseIdentifier: FeaturedVideoListCell.reuseID)
        return collectionView
    }()

    private let listTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 42, weight: .bold)
        label.textColor = .white
        label.text = "精选"
        return label
    }()

    private let previewHostView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.clipsToBounds = true
        return view
    }()

    private let previewPlaceholderView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        return iv
    }()

    private let previewLoadingView = UIActivityIndicatorView(style: .large)

    /// 左侧从左到右的渐变 scrim，保证列表在动态视频背景上的可读性
    private let leftGradientScrimView: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = false
        return view
    }()

    /// 底部从下到上的渐变 scrim，保证右下信息浮层的可读性
    private let bottomGradientScrimView: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = false
        return view
    }()

    /// 右下角信息浮层容器
    private let infoOverlayView: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = false
        return view
    }()

    private let previewTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 44, weight: .bold)
        label.textColor = .white
        label.numberOfLines = 2
        return label
    }()

    private let previewMetaLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 28, weight: .medium)
        label.textColor = UIColor.white.withAlphaComponent(0.85)
        label.numberOfLines = 1
        return label
    }()

    private let previewHintLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 24, weight: .medium)
        label.textColor = UIColor.white.withAlphaComponent(0.72)
        label.numberOfLines = 2
        label.text = "停留后自动预览，按确认键进入短视频流"
        return label
    }()

    private let emptyStateLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 30, weight: .medium)
        label.textColor = UIColor.white.withAlphaComponent(0.72)
        label.numberOfLines = 2
        label.textAlignment = .center
        label.isHidden = true
        return label
    }()

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        [listCollectionView]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        restoresFocusAfterTransition = false
        view.backgroundColor = UIColor.black
        setupUI()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleAppWillResignActive),
                                               name: UIApplication.willResignActiveNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleAppDidBecomeActive),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)
        sequenceProvider.onNeedMore = { [weak self] in
            await self?.loadMoreShortVideosIfNeeded(targetCount: self?.trailingPrefetchTargetCount ?? 8,
                                                    maxSourcePages: self?.trailingMaxSourcePages ?? 3)
        }
        reloadData()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if activeDurationLimit != Settings.featuredDurationLimit
            || activePersonalizedEnabled != Settings.featuredPersonalizedRankingEnabled
        {
            reloadData()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        suspendPreview(cancelWarmups: !isPresentingFeedFlow)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isPresentingFeedFlow = false
        syncSelectionFromSequenceProvider()
        resumePreviewIfNeeded()
    }

    @objc private func handleAppWillResignActive() {
        guard isViewLoaded, view.window != nil else { return }
        suspendPreview(cancelWarmups: true)
    }

    @objc private func handleAppDidBecomeActive() {
        guard isViewLoaded, view.window != nil else { return }
        resumePreviewIfNeeded()
    }

    func reloadData() {
        dataLoadTask?.cancel()
        activeDurationLimit = Settings.featuredDurationLimit
        activePersonalizedEnabled = Settings.featuredPersonalizedRankingEnabled
        suspendPreview(cancelWarmups: true)
        items = []
        focusedIndex = 0
        lastSourceIdx = nil
        lastPlayedSequenceKey = nil
        hasUserInteractedSinceReload = false
        sessionWatchSignals = []
        currentInterestProfile = nil
        configureSequenceProvider(with: [])
        listCollectionView.reloadData()
        emptyStateLabel.isHidden = true

        // 尝试从缓存加载画像
        if activePersonalizedEnabled {
            let mid = currentAccountMID
            currentInterestProfile = FeaturedInterestProfileCache.shared.load(
                mid: mid, rankVersion: FeaturedRanker.rankVersion
            )
        }

        if let cachedSnapshot = featuredFeedCache.load(
            durationLimit: activeDurationLimit,
            accountMID: currentAccountMID,
            personalizedEnabled: activePersonalizedEnabled
        ), !cachedSnapshot.items.isEmpty {
            applyCachedSnapshot(cachedSnapshot)
            dataLoadTask = Task { [weak self] in
                await self?.refreshFeaturedFeedFromStart(replaceVisibleContentIfIdle: true, showLoading: false)
            }
            return
        }
        previewHintLabel.text = "正在加载精选短视频..."
        previewLoadingView.startAnimating()
        dataLoadTask = Task { [weak self] in
            await self?.refreshFeaturedFeedFromStart(replaceVisibleContentIfIdle: true, showLoading: true)
        }
    }

    @MainActor
    private func loadMoreShortVideosIfNeeded(targetCount: Int, maxSourcePages: Int) async {
        guard !isLoading else { return }
        let activeIndex = max(focusedIndex, sequenceProvider.currentIndex)
        guard items.count < targetCount || items.count - activeIndex - 1 < trailingPrefetchTargetCount else { return }
        isLoading = true
        defer { isLoading = false }

        var pagesScanned = 0
        var acceptedCount = 0
        while acceptedCount < targetCount && pagesScanned < maxSourcePages {
            do {
                let sourceItems: [ApiRequest.FeedResp.Items]
                if let lastSourceIdx {
                    sourceItems = try await ApiRequest.getFeeds(lastIdx: lastSourceIdx)
                } else {
                    sourceItems = try await ApiRequest.getFeeds()
                }
                pagesScanned += 1
                lastSourceIdx = sourceItems.last?.idx

                let newItems = sourceItems.compactMap { $0.toRecommendedVideoItem(durationLimit: Settings.featuredDurationLimit) }
                if newItems.isEmpty {
                    continue
                }
                let existing = Set(items.map { "\($0.aid)-\($0.cid)" })
                let appended = newItems.filter { !existing.contains("\($0.aid)-\($0.cid)") }
                guard !appended.isEmpty else { continue }
                appendLoadedItems(appended)
                acceptedCount += appended.count
                await playContextCache.trim(keeping: sequenceProvider.neighborItems(radius: 2))
            } catch {
                await MainActor.run {
                    self.previewLoadingView.stopAnimating()
                    self.emptyStateLabel.text = "精选加载失败，请稍后重试"
                    self.emptyStateLabel.isHidden = false
                    self.previewHintLabel.text = "\(error)"
                }
                break
            }
        }
    }

    private func configureSequenceProvider(with items: [RecommendedVideoItem]) {
        sequenceProvider = VideoSequenceProvider(seq: items.map(\.playInfo))
        sequenceProvider.onNeedMore = { [weak self] in
            await self?.loadMoreShortVideosIfNeeded(targetCount: self?.trailingPrefetchTargetCount ?? 8,
                                                    maxSourcePages: self?.trailingMaxSourcePages ?? 3)
        }
    }

    @MainActor
    private func refreshFeaturedFeedFromStart(replaceVisibleContentIfIdle: Bool, showLoading: Bool) async {
        // 智能排序开启时后台刷新画像
        if activePersonalizedEnabled, currentInterestProfile == nil {
            await refreshInterestProfileInBackground()
        }

        do {
            var snapshot = try await buildFreshSnapshot(targetCount: initialFilteredTargetCount, maxSourcePages: initialMaxSourcePages)
            guard !Task.isCancelled else { return }

            // 智能排序
            if activePersonalizedEnabled {
                let profile = effectiveProfile()
                if profile.sampleTier != .none {
                    let rankedItems = FeaturedRanker.rank(
                        snapshot.items.map(RecommendedVideoItem.init(cached:)),
                        profile: profile
                    )
                    snapshot = FeaturedFeedCacheSnapshot(
                        savedAt: snapshot.savedAt,
                        durationLimit: snapshot.durationLimit,
                        lastSourceIdx: snapshot.lastSourceIdx,
                        items: rankedItems.map(\.cachedValue),
                        accountMID: currentAccountMID,
                        personalizedEnabled: true,
                        rankVersion: FeaturedRanker.rankVersion
                    )
                }
            }

            featuredFeedCache.save(items: snapshot.items.map(RecommendedVideoItem.init(cached:)),
                                   lastSourceIdx: snapshot.lastSourceIdx,
                                   durationLimit: snapshot.durationLimit,
                                   accountMID: currentAccountMID,
                                   personalizedEnabled: activePersonalizedEnabled)
            if snapshot.items.isEmpty {
                guard items.isEmpty else { return }
                restoreEmptyState()
                return
            }
            if items.isEmpty || replaceVisibleContentIfIdle && !hasUserInteractedSinceReload {
                applyFreshSnapshot(snapshot)
            } else {
                previewLoadingView.stopAnimating()
            }
        } catch {
            guard !Task.isCancelled else { return }
            if items.isEmpty {
                previewLoadingView.stopAnimating()
                emptyStateLabel.text = "精选加载失败，请稍后重试"
                emptyStateLabel.isHidden = false
                previewHintLabel.text = "\(error)"
            } else if showLoading == false {
                previewHintLabel.text = "已展示缓存内容，后台刷新失败"
            }
        }
    }

    private func buildFreshSnapshot(targetCount: Int, maxSourcePages: Int) async throws -> FeaturedFeedCacheSnapshot {
        var loadedItems = [RecommendedVideoItem]()
        var nextSourceIdx: Int?
        var pagesScanned = 0
        while loadedItems.count < targetCount && pagesScanned < maxSourcePages {
            let sourceItems: [ApiRequest.FeedResp.Items]
            if let nextSourceIdx {
                sourceItems = try await ApiRequest.getFeeds(lastIdx: nextSourceIdx)
            } else {
                sourceItems = try await ApiRequest.getFeeds()
            }
            pagesScanned += 1
            nextSourceIdx = sourceItems.last?.idx
            let filtered = sourceItems.compactMap { $0.toRecommendedVideoItem(durationLimit: activeDurationLimit) }
            guard !filtered.isEmpty else { continue }
            let existing = Set(loadedItems.map { "\($0.aid)-\($0.cid)" })
            loadedItems.append(contentsOf: filtered.filter { !existing.contains("\($0.aid)-\($0.cid)") })
        }
        return FeaturedFeedCacheSnapshot(savedAt: Date(),
                                         durationLimit: activeDurationLimit,
                                         lastSourceIdx: nextSourceIdx,
                                         items: loadedItems.map(\.cachedValue),
                                         accountMID: currentAccountMID,
                                         personalizedEnabled: activePersonalizedEnabled,
                                         rankVersion: FeaturedRanker.rankVersion)
    }

    @MainActor
    private func applyCachedSnapshot(_ snapshot: FeaturedFeedCacheSnapshot) {
        items = snapshot.items.map(RecommendedVideoItem.init(cached:))
        lastSourceIdx = snapshot.lastSourceIdx
        configureSequenceProvider(with: items)
        previewLoadingView.stopAnimating()
        guard !items.isEmpty else {
            restoreEmptyState()
            return
        }
        listCollectionView.reloadData()
        syncSelectionFromSequenceProvider()
    }

    @MainActor
    private func applyFreshSnapshot(_ snapshot: FeaturedFeedCacheSnapshot) {
        items = snapshot.items.map(RecommendedVideoItem.init(cached:))
        lastSourceIdx = snapshot.lastSourceIdx
        configureSequenceProvider(with: items)
        previewLoadingView.stopAnimating()
        emptyStateLabel.isHidden = true
        listCollectionView.reloadData()
        syncSelectionFromSequenceProvider()
    }

    @MainActor
    private func restoreEmptyState() {
        previewLoadingView.stopAnimating()
        emptyStateLabel.text = "当前精选短视频较少，请稍后重试"
        emptyStateLabel.isHidden = false
        previewHintLabel.text = "可以在设置里调整精选视频时长上限"
    }

    @MainActor
    private func appendLoadedItems(_ appended: [RecommendedVideoItem]) {
        guard !appended.isEmpty else { return }
        // 智能排序：只排新 batch
        let sorted: [RecommendedVideoItem]
        if activePersonalizedEnabled {
            let profile = effectiveProfile()
            sorted = FeaturedRanker.rankBatch(appended, profile: profile)
        } else {
            sorted = appended
        }
        let start = items.count
        items.append(contentsOf: sorted)
        sequenceProvider.append(sorted.map(\.playInfo))
        featuredFeedCache.save(items: items, lastSourceIdx: lastSourceIdx,
                               durationLimit: activeDurationLimit,
                               accountMID: currentAccountMID,
                               personalizedEnabled: activePersonalizedEnabled)
        let indexPaths = (start..<(start + sorted.count)).map { IndexPath(item: $0, section: 0) }
        guard listCollectionView.numberOfItems(inSection: 0) == start else {
            listCollectionView.reloadData()
            return
        }
        listCollectionView.performBatchUpdates {
            listCollectionView.insertItems(at: indexPaths)
        }
    }

    private func setupUI() {
        // 1. 全屏背景层（最底层）
        view.addSubview(previewHostView)
        previewHostView.addSubview(previewPlaceholderView)
        view.addSubview(previewLoadingView)

        previewHostView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        previewPlaceholderView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        previewLoadingView.hidesWhenStopped = true
        previewLoadingView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        // 2. 渐变 scrim 层
        view.addSubview(leftGradientScrimView)
        view.addSubview(bottomGradientScrimView)

        leftGradientScrimView.snp.makeConstraints { make in
            make.top.leading.bottom.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(0.5)
        }

        bottomGradientScrimView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalToSuperview().multipliedBy(0.35)
        }

        // 3. 左侧列表层（在 scrim 之上）
        view.addSubview(listTitleLabel)
        view.addSubview(listCollectionView)

        listTitleLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(12)
            make.leading.equalToSuperview().offset(48)
        }

        listCollectionView.snp.makeConstraints { make in
            make.top.equalTo(listTitleLabel.snp.bottom).offset(18)
            make.leading.equalToSuperview().offset(36)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-24)
            make.width.equalTo(470)
        }

        // 4. 右下角信息浮层
        view.addSubview(infoOverlayView)
        infoOverlayView.addSubview(previewTitleLabel)
        infoOverlayView.addSubview(previewMetaLabel)
        infoOverlayView.addSubview(previewHintLabel)

        infoOverlayView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-60)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-40)
            make.width.equalTo(500)
        }

        previewTitleLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }

        previewMetaLabel.snp.makeConstraints { make in
            make.top.equalTo(previewTitleLabel.snp.bottom).offset(10)
            make.leading.trailing.equalToSuperview()
        }

        previewHintLabel.snp.makeConstraints { make in
            make.top.equalTo(previewMetaLabel.snp.bottom).offset(8)
            make.leading.trailing.bottom.equalToSuperview()
        }

        // 5. Empty state（居中在全屏上）
        view.addSubview(emptyStateLabel)
        emptyStateLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(60)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        installGradientLayers()
    }

    private func installGradientLayers() {
        // 左侧渐变 scrim
        if leftGradientScrimView.layer.sublayers?.first(where: { $0 is CAGradientLayer }) == nil {
            let leftGradient = CAGradientLayer()
            leftGradient.colors = [UIColor.black.withAlphaComponent(0.35).cgColor,
                                   UIColor.black.withAlphaComponent(0.0).cgColor]
            leftGradient.startPoint = CGPoint(x: 0, y: 0.5)
            leftGradient.endPoint = CGPoint(x: 1, y: 0.5)
            leftGradientScrimView.layer.insertSublayer(leftGradient, at: 0)
        }
        if let leftGradient = leftGradientScrimView.layer.sublayers?.first as? CAGradientLayer {
            leftGradient.frame = leftGradientScrimView.bounds
        }

        // 底部渐变 scrim
        if bottomGradientScrimView.layer.sublayers?.first(where: { $0 is CAGradientLayer }) == nil {
            let bottomGradient = CAGradientLayer()
            bottomGradient.colors = [UIColor.black.withAlphaComponent(0.0).cgColor,
                                     UIColor.black.withAlphaComponent(0.55).cgColor]
            bottomGradient.startPoint = CGPoint(x: 0.5, y: 0)
            bottomGradient.endPoint = CGPoint(x: 0.5, y: 1)
            bottomGradientScrimView.layer.insertSublayer(bottomGradient, at: 0)
        }
        if let bottomGradient = bottomGradientScrimView.layer.sublayers?.first as? CAGradientLayer {
            bottomGradient.frame = bottomGradientScrimView.bounds
        }
    }

    private func restorePreviewPlaceholder(animated: Bool) {
        let animations = {
            self.previewPlaceholderView.alpha = 1
            self.previewController?.view.alpha = 0
        }
        if animated {
            UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut, animations: animations)
        } else {
            animations()
        }
    }

    private func revealPreviewPlaybackStarted(controller: VideoPlayerViewController) {
        previewLoadingView.stopAnimating()
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
            controller.view.alpha = 1
            self.previewPlaceholderView.alpha = 0
        }
    }

    private func schedulePreview(for item: RecommendedVideoItem) {
        previewTask?.cancel()
        Task { [mediaWarmupManager] in
            await mediaWarmupManager.cancelAll()
        }
        removePreviewController() // 立即销毁旧预览，杜绝串音
        restorePreviewPlaceholder(animated: false)
        updatePreviewTexts(with: item)
        previewLoadingView.startAnimating()
        emptyStateLabel.isHidden = true
        previewTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: preloadDelayNs)
            guard !Task.isCancelled else { return }
            await playContextCache.preload(playInfo: item.playInfo, mode: .preview)
            let neighboringItems = self.neighborPlayInfos(around: self.focusedIndex)
            for neighbor in neighboringItems {
                await playContextCache.preload(playInfo: neighbor, mode: .preview)
            }
            await playContextCache.trim(keeping: neighboringItems)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard !Task.isCancelled,
                      self.presentedViewController == nil,
                      self.isViewLoaded,
                      self.view.window != nil
                else { return }
                guard self.items.indices.contains(self.focusedIndex),
                      self.items[self.focusedIndex] == item
                else { return }
                self.installPreviewController(for: item)
            }
        }
    }

    private func installPreviewController(for item: RecommendedVideoItem) {
        removePreviewController()
        let controller = VideoPlayerViewController(playInfo: item.playInfo,
                                                   playMode: .preview,
                                                   playContextCache: playContextCache,
                                                   previewMuted: false)
        controller.onLoadFailure = { [weak self, weak controller] _ in
            guard let self, let controller, self.previewController === controller else { return }
            self.previewLoadingView.stopAnimating()
            self.previewHintLabel.text = "预览加载失败，按确认键可直接进入播放"
            self.restorePreviewPlaceholder(animated: false)
        }
        controller.onPlaybackStarted = { [weak self, weak controller] in
            guard let self, let controller, self.previewController === controller else { return }
            self.revealPreviewPlaybackStarted(controller: controller)
            Task { [weak self] in
                await self?.warmupPlaybackMedia(for: item)
            }
        }
        addChild(controller)
        controller.view.alpha = 0
        previewHostView.addSubview(controller.view)
        controller.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        controller.didMove(toParent: self)
        controller.view.isUserInteractionEnabled = false
        previewController = controller
    }

    private func removePreviewController() {
        previewController?.onPlaybackStarted = nil
        previewController?.onLoadFailure = nil
        previewController?.stopPlayback()
        previewController?.willMove(toParent: nil)
        previewController?.view.removeFromSuperview()
        previewController?.removeFromParent()
        previewController = nil
    }

    private func suspendPreview(cancelWarmups: Bool = true) {
        previewTask?.cancel()
        previewTask = nil
        previewLoadingView.stopAnimating()
        removePreviewController()
        restorePreviewPlaceholder(animated: false)
        if cancelWarmups {
            Task { [mediaWarmupManager] in
                await mediaWarmupManager.cancelAll()
            }
        }
    }

    private func updatePreviewTexts(with item: RecommendedVideoItem) {
        previewTitleLabel.text = item.title
        previewMetaLabel.text = item.metaText
        previewHintLabel.text = item.reasonText?.isEmpty == false
            ? "\(item.reasonText ?? "") · 按确认键进入短视频流"
            : "停留后自动预览，按确认键进入短视频流"
        // 封面切换 crossfade
        if let coverURL = item.coverURL {
            UIView.transition(with: previewPlaceholderView, duration: 0.25, options: .transitionCrossDissolve) {
                self.previewPlaceholderView.kf.setImage(with: coverURL)
            }
        } else {
            UIView.transition(with: previewPlaceholderView, duration: 0.25, options: .transitionCrossDissolve) {
                self.previewPlaceholderView.image = nil
            }
        }
    }

    private func neighborPlayInfos(around index: Int) -> [PlayInfo] {
        let lower = max(0, index - 1)
        let upper = min(items.count - 1, index + 1)
        guard lower <= upper else { return [] }
        return Array(items[lower...upper]).map(\.playInfo)
    }

    private func prioritizedPlaybackWarmupInfos(for item: RecommendedVideoItem) -> [PlayInfo] {
        guard let index = items.firstIndex(of: item) else { return [item.playInfo] }
        var warmupInfos = [PlayInfo]()
        warmupInfos.append(items[index].playInfo)
        if items.indices.contains(index + 1) {
            warmupInfos.append(items[index + 1].playInfo)
        }
        if items.indices.contains(index - 1) {
            warmupInfos.append(items[index - 1].playInfo)
        }
        return warmupInfos.uniqued()
    }

    private func warmupPlaybackMedia(for item: RecommendedVideoItem) async {
        let warmupInfos = prioritizedPlaybackWarmupInfos(for: item)
        await playContextCache.trim(keeping: warmupInfos)
        await mediaWarmupManager.retain(playInfos: warmupInfos)
        for info in warmupInfos {
            await playContextCache.preload(playInfo: info, mode: .regular)
            await mediaWarmupManager.preload(playInfo: info)
        }
    }

    private func resolvedSelectionIndex() -> Int? {
        guard !items.isEmpty else { return nil }
        if let lastPlayedSequenceKey,
           let matchedIndex = items.firstIndex(where: { $0.playInfo.sequenceKey == lastPlayedSequenceKey })
        {
            return matchedIndex
        }
        return min(sequenceProvider.currentIndex, items.count - 1)
    }

    private func ensureListCollectionViewIsSynced() {
        guard listCollectionView.numberOfItems(inSection: 0) != items.count else { return }
        listCollectionView.reloadData()
        listCollectionView.layoutIfNeeded()
    }

    private func refreshVisibleListCells() {
        listCollectionView.visibleCells.compactMap { $0 as? FeaturedVideoListCell }.forEach { cell in
            guard let indexPath = listCollectionView.indexPath(for: cell),
                  items.indices.contains(indexPath.item)
            else { return }
            cell.configure(with: items[indexPath.item], isCurrent: indexPath.item == focusedIndex)
        }
    }

    private func updateSelectionFromPlayInfo(_ playInfo: PlayInfo) {
        lastPlayedSequenceKey = playInfo.sequenceKey
        guard let matchedIndex = items.firstIndex(where: { $0.playInfo.sequenceKey == playInfo.sequenceKey }) else { return }
        focusedIndex = matchedIndex
        sequenceProvider.setCurrentIndex(matchedIndex)
    }

    private func applyReturnedPlaybackSelection(_ playInfo: PlayInfo) {
        updateSelectionFromPlayInfo(playInfo)
        guard isViewLoaded, view.window != nil, presentedViewController == nil else { return }
        syncSelectionFromSequenceProvider()
    }

    private func syncSelectionFromSequenceProvider() {
        guard let targetIndex = resolvedSelectionIndex() else { return }
        ensureListCollectionViewIsSynced()
        guard listCollectionView.numberOfItems(inSection: 0) > targetIndex else { return }
        focusedIndex = targetIndex
        sequenceProvider.setCurrentIndex(targetIndex)
        let targetIndexPath = IndexPath(item: targetIndex, section: 0)
        listCollectionView.selectItem(at: targetIndexPath, animated: false, scrollPosition: .centeredVertically)
        listCollectionView.scrollToItem(at: targetIndexPath, at: .centeredVertically, animated: false)
        refreshVisibleListCells()
        schedulePreview(for: items[targetIndex])
        setNeedsFocusUpdate()
        updateFocusIfNeeded()
    }

    private func resumePreviewIfNeeded() {
        guard previewController == nil,
              previewTask == nil,
              presentedViewController == nil,
              isViewLoaded,
              view.window != nil,
              !items.isEmpty
        else { return }
        let targetIndex = min(focusedIndex, items.count - 1)
        schedulePreview(for: items[targetIndex])
    }

    private func enterFlow(at index: Int) {
        guard items.indices.contains(index) else { return }
        hasUserInteractedSinceReload = true
        isPresentingFeedFlow = true
        focusedIndex = index
        sequenceProvider.setCurrentIndex(index)
        lastPlayedSequenceKey = items[index].playInfo.sequenceKey
        let startTimeOverride = previewStartTimeForFlowEntry(at: index)
        suspendPreview(cancelWarmups: false)
        let player = VideoPlayerViewController(playInfo: items[index].playInfo,
                                               playMode: .feedFlow,
                                               playContextCache: playContextCache,
                                               mediaWarmupManager: mediaWarmupManager,
                                               startTimeOverride: startTimeOverride)
        player.sequenceProvider = sequenceProvider
        player.onPlayInfoChanged = { [weak self] info in
            MainActor.callSafely {
                self?.updateSelectionFromPlayInfo(info)
            }
        }
        player.onDismissWithPlayInfo = { [weak self] info in
            MainActor.callSafely {
                self?.applyReturnedPlaybackSelection(info)
            }
        }
        // 智能排序：收集会话内正向观看信号
        if activePersonalizedEnabled {
            player.onItemWatched = { [weak self] playInfo, watchedSeconds in
                self?.handleItemWatched(playInfo: playInfo, watchedSeconds: watchedSeconds)
            }
        }
        present(player, animated: true)
    }

    private func previewStartTimeForFlowEntry(at index: Int) -> Int? {
        guard let previewController,
              items.indices.contains(index),
              previewController.currentPlayInfo.sequenceKey == items[index].playInfo.sequenceKey
        else {
            return nil
        }
        return previewController.currentPlaybackTimeInSeconds()
    }

    // MARK: - 智能排序辅助

    private var currentAccountMID: Int {
        ApiRequest.getToken()?.mid ?? 0
    }

    /// 返回叠加了会话信号的有效画像
    private func effectiveProfile() -> FeaturedInterestProfile {
        let base = currentInterestProfile ?? .empty
        return base.boosted(with: sessionWatchSignals)
    }

    /// 后台加载历史记录并构建兴趣画像
    private func refreshInterestProfileInBackground() async {
        let mid = currentAccountMID
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
            FeaturedInterestProfileCache.shared.save(profile, mid: mid, rankVersion: FeaturedRanker.rankVersion)
        }
    }

    /// 处理播放器回报的观看信号
    private func handleItemWatched(playInfo: PlayInfo, watchedSeconds: Int) {
        // 正向阈值: >= 8s 或 >= 25% duration
        let duration = playInfo.duration ?? 0
        let isPositive = watchedSeconds >= 8 || (duration > 0 && Double(watchedSeconds) >= Double(duration) * 0.25)
        guard isPositive else { return }

        // 检查是否已记录过相同 item
        if sessionWatchSignals.contains(where: { $0.0.sequenceKey == playInfo.sequenceKey }) { return }

        sessionWatchSignals.append((playInfo, watchedSeconds))
    }
}

extension FeaturedBrowserViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FeaturedVideoListCell.reuseID, for: indexPath) as! FeaturedVideoListCell
        cell.configure(with: items[indexPath.item], isCurrent: indexPath.item == focusedIndex)
        return cell
    }

    func indexPathForPreferredFocusedView(in collectionView: UICollectionView) -> IndexPath? {
        guard let targetIndex = resolvedSelectionIndex() else { return nil }
        return IndexPath(item: targetIndex, section: 0)
    }
}

extension FeaturedBrowserViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        hasUserInteractedSinceReload = true
        enterFlow(at: indexPath.item)
    }

    func collectionView(_ collectionView: UICollectionView,
                        didUpdateFocusIn context: UICollectionViewFocusUpdateContext,
                        with coordinator: UIFocusAnimationCoordinator)
    {
        guard let nextIndexPath = context.nextFocusedIndexPath,
              items.indices.contains(nextIndexPath.item)
        else { return }
        hasUserInteractedSinceReload = true
        focusedIndex = nextIndexPath.item
        collectionView.selectItem(at: nextIndexPath, animated: true, scrollPosition: .centeredVertically)
        sequenceProvider.setCurrentIndex(focusedIndex)
        schedulePreview(for: items[focusedIndex])
        refreshVisibleListCells()
        if items.count - focusedIndex - 1 < trailingPrefetchTargetCount {
            Task {
                await loadMoreShortVideosIfNeeded(targetCount: trailingPrefetchTargetCount, maxSourcePages: trailingMaxSourcePages)
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard indexPath.item >= items.count - 4 else { return }
        Task {
            await loadMoreShortVideosIfNeeded(targetCount: trailingPrefetchTargetCount, maxSourcePages: trailingMaxSourcePages)
        }
    }
}

final class FeaturedVideoListCell: BLMotionCollectionViewCell {
    static let reuseID = String(describing: FeaturedVideoListCell.self)

    private let blurBackgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    private let imageView = UIImageView()
    private let titleLabel = UILabel()
    private let metaLabel = UILabel()
    private let overlayView = BLOverlayView()
    private var isCurrent = false

    override func setup() {
        super.setup()
        scaleFactor = 1.06

        contentView.addSubview(blurBackgroundView)
        blurBackgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        blurBackgroundView.layer.cornerRadius = 20
        blurBackgroundView.layer.cornerCurve = .continuous
        blurBackgroundView.clipsToBounds = true

        blurBackgroundView.contentView.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview().inset(14)
            make.width.equalTo(170)
        }
        imageView.layer.cornerRadius = 14
        imageView.layer.cornerCurve = .continuous
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill

        imageView.addSubview(overlayView)
        overlayView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        overlayView.fontSize = 14

        blurBackgroundView.contentView.addSubview(titleLabel)
        blurBackgroundView.contentView.addSubview(metaLabel)

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(18)
            make.leading.equalTo(imageView.snp.trailing).offset(18)
            make.trailing.equalToSuperview().offset(-18)
        }
        titleLabel.font = .systemFont(ofSize: 28, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2

        metaLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.trailing.equalTo(titleLabel)
            make.bottom.equalToSuperview().offset(-18)
        }
        metaLabel.font = .systemFont(ofSize: 22, weight: .medium)
        metaLabel.textColor = UIColor.white.withAlphaComponent(0.78)
        metaLabel.numberOfLines = 1
    }

    func configure(with item: RecommendedVideoItem, isCurrent: Bool) {
        titleLabel.text = item.title
        metaLabel.text = item.listMetaText

        self.isCurrent = isCurrent
        if let coverURL = item.coverURL {
            imageView.kf.setImage(with: coverURL)
        } else {
            imageView.image = nil
        }

        var leftItems = [DisplayOverlay.DisplayOverlayItem]()
        var rightItems = [DisplayOverlay.DisplayOverlayItem]()

        if !item.viewCountText.isEmpty && !item.viewCountText.contains(":") {
            leftItems.append(DisplayOverlay.DisplayOverlayItem(icon: "play.rectangle", text: item.viewCountText.replacingOccurrences(of: "观看", with: "")))
        } else if !item.danmakuCountText.isEmpty && !item.danmakuCountText.contains(":") {
            leftItems.append(DisplayOverlay.DisplayOverlayItem(icon: "play.rectangle", text: item.danmakuCountText.replacingOccurrences(of: "观看", with: "")))
        }

        if !item.durationText.isEmpty {
            rightItems.append(DisplayOverlay.DisplayOverlayItem(icon: nil, text: item.durationText))
        }

        let overlay = DisplayOverlay(leftItems: leftItems, rightItems: rightItems)
        overlayView.configure(overlay)
        overlayView.isHidden = leftItems.isEmpty && rightItems.isEmpty

        updateAppearance()
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        coordinator.addCoordinatedAnimations {
            self.updateAppearance()
        }
    }

    private func updateAppearance() {
        blurBackgroundView.effect = UIBlurEffect(style: isFocused || isCurrent ? .light : .dark)
        titleLabel.textColor = isFocused || isCurrent ? .black : .white
        metaLabel.textColor = isFocused || isCurrent ? UIColor.black.withAlphaComponent(0.75) : UIColor.white.withAlphaComponent(0.78)
    }
}
