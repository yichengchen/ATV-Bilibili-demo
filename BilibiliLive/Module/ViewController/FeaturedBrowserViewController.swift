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
                                    reasonText: top_rcmd_reason ?? bottom_rcmd_reason)
    }
}

class FeaturedBrowserViewController: UIViewController, BLTabBarContentVCProtocol {
    private let preloadDelayNs: UInt64 = 400_000_000
    private let initialFilteredTargetCount = 12
    private let initialMaxSourcePages = 5
    private let trailingPrefetchTargetCount = 8
    private let trailingMaxSourcePages = 3

    private var items = [RecommendedVideoItem]()
    private var focusedIndex = 0
    private var lastSourceIdx: Int?
    private var isLoading = false
    private var activeDurationLimit = Settings.featuredDurationLimit
    private var previewTask: Task<Void, Never>?
    private let playContextCache = PlayContextCache()
    private lazy var sequenceProvider = VideoSequenceProvider(seq: [])

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

    private let previewCardView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0.08, alpha: 1)
        view.layer.cornerRadius = 28
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true
        return view
    }()

    private let previewHostView = UIView()
    private let previewPlaceholderView = UIImageView()
    private let previewLoadingView = UIActivityIndicatorView(style: .large)

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
        label.text = "左侧停留后静音预览，按确认键进入短视频流"
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
        view.backgroundColor = UIColor.black
        setupUI()
        sequenceProvider.onNeedMore = { [weak self] in
            await self?.loadMoreShortVideosIfNeeded(targetCount: self?.trailingPrefetchTargetCount ?? 8,
                                                    maxSourcePages: self?.trailingMaxSourcePages ?? 3)
        }
        reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if activeDurationLimit != Settings.featuredDurationLimit {
            reloadData()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        suspendPreview()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        syncSelectionFromSequenceProvider()
        resumePreviewIfNeeded()
    }

    func reloadData() {
        activeDurationLimit = Settings.featuredDurationLimit
        suspendPreview()
        items = []
        focusedIndex = 0
        lastSourceIdx = nil
        sequenceProvider = VideoSequenceProvider(seq: [])
        sequenceProvider.onNeedMore = { [weak self] in
            await self?.loadMoreShortVideosIfNeeded(targetCount: self?.trailingPrefetchTargetCount ?? 8,
                                                    maxSourcePages: self?.trailingMaxSourcePages ?? 3)
        }
        listCollectionView.reloadData()
        emptyStateLabel.isHidden = true
        previewHintLabel.text = "正在加载精选短视频..."
        previewLoadingView.startAnimating()
        Task {
            await loadMoreShortVideosIfNeeded(targetCount: initialFilteredTargetCount, maxSourcePages: initialMaxSourcePages)
            await MainActor.run {
                if self.items.isEmpty {
                    self.previewLoadingView.stopAnimating()
                    self.emptyStateLabel.text = "当前精选短视频较少，请稍后重试"
                    self.emptyStateLabel.isHidden = false
                    self.previewHintLabel.text = "可以在设置里调整精选视频时长上限"
                    return
                }
                self.listCollectionView.reloadData()
                self.listCollectionView.selectItem(at: IndexPath(item: self.focusedIndex, section: 0), animated: false, scrollPosition: .centeredVertically)
                self.schedulePreview(for: self.items[self.focusedIndex])
                self.setNeedsFocusUpdate()
                self.updateFocusIfNeeded()
            }
        }
    }

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
                items.append(contentsOf: appended)
                sequenceProvider.append(appended.map(\.playInfo))
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

    private func setupUI() {
        view.addSubview(listTitleLabel)
        view.addSubview(listCollectionView)
        view.addSubview(previewCardView)

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

        previewCardView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(28)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-28)
            make.leading.equalTo(listCollectionView.snp.trailing).offset(24)
            make.trailing.equalToSuperview().offset(-36)
        }

        previewCardView.addSubview(previewHostView)
        previewCardView.addSubview(previewPlaceholderView)
        previewCardView.addSubview(previewLoadingView)
        previewCardView.addSubview(previewTitleLabel)
        previewCardView.addSubview(previewMetaLabel)
        previewCardView.addSubview(previewHintLabel)
        previewCardView.addSubview(emptyStateLabel)

        previewHostView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(previewHostView.snp.width).multipliedBy(9.0 / 16.0)
        }

        previewPlaceholderView.snp.makeConstraints { make in
            make.edges.equalTo(previewHostView)
        }
        previewPlaceholderView.contentMode = .scaleAspectFill
        previewPlaceholderView.clipsToBounds = true

        previewLoadingView.snp.makeConstraints { make in
            make.center.equalTo(previewHostView)
        }

        previewTitleLabel.snp.makeConstraints { make in
            make.top.equalTo(previewHostView.snp.bottom).offset(28)
            make.leading.trailing.equalToSuperview().inset(28)
        }

        previewMetaLabel.snp.makeConstraints { make in
            make.top.equalTo(previewTitleLabel.snp.bottom).offset(14)
            make.leading.trailing.equalToSuperview().inset(28)
        }

        previewHintLabel.snp.makeConstraints { make in
            make.top.equalTo(previewMetaLabel.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(28)
        }

        emptyStateLabel.snp.makeConstraints { make in
            make.center.equalTo(previewHostView)
            make.leading.trailing.equalToSuperview().inset(36)
        }
    }

    private func schedulePreview(for item: RecommendedVideoItem) {
        previewTask?.cancel()
        updatePreviewTexts(with: item)
        previewLoadingView.startAnimating()
        emptyStateLabel.isHidden = true
        previewTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: preloadDelayNs)
            guard !Task.isCancelled else { return }
            await playContextCache.preload(playInfo: item.playInfo, includeDetail: false)
            let neighboringItems = self.neighborPlayInfos(around: self.focusedIndex)
            for neighbor in neighboringItems {
                await playContextCache.preload(playInfo: neighbor, includeDetail: false)
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
                                                   playContextCache: playContextCache)
        controller.onLoadFailure = { [weak self] _ in
            self?.previewLoadingView.stopAnimating()
            self?.previewHintLabel.text = "预览加载失败，按确认键可直接进入播放"
        }
        addChild(controller)
        previewHostView.addSubview(controller.view)
        controller.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        controller.didMove(toParent: self)
        controller.view.isUserInteractionEnabled = false
        previewController = controller
        previewLoadingView.stopAnimating()
    }

    private func removePreviewController() {
        previewController?.stopPlayback()
        previewController?.willMove(toParent: nil)
        previewController?.view.removeFromSuperview()
        previewController?.removeFromParent()
        previewController = nil
    }

    private func suspendPreview() {
        previewTask?.cancel()
        previewTask = nil
        removePreviewController()
    }

    private func updatePreviewTexts(with item: RecommendedVideoItem) {
        previewTitleLabel.text = item.title
        previewMetaLabel.text = item.metaText
        previewHintLabel.text = item.reasonText?.isEmpty == false
            ? "\(item.reasonText ?? "") · 按确认键进入短视频流"
            : "左侧停留后静音预览，按确认键进入短视频流"
        if let coverURL = item.coverURL {
            previewPlaceholderView.kf.setImage(with: coverURL)
        } else {
            previewPlaceholderView.image = nil
        }
    }

    private func neighborPlayInfos(around index: Int) -> [PlayInfo] {
        let lower = max(0, index - 1)
        let upper = min(items.count - 1, index + 1)
        guard lower <= upper else { return [] }
        return Array(items[lower...upper]).map(\.playInfo)
    }

    private func syncSelectionFromSequenceProvider() {
        guard !items.isEmpty else { return }
        let targetIndex = min(sequenceProvider.currentIndex, items.count - 1)
        guard targetIndex != focusedIndex else { return }
        focusedIndex = targetIndex
        listCollectionView.selectItem(at: IndexPath(item: targetIndex, section: 0), animated: false, scrollPosition: .centeredVertically)
        listCollectionView.scrollToItem(at: IndexPath(item: targetIndex, section: 0), at: .centeredVertically, animated: false)
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
        focusedIndex = index
        sequenceProvider.setCurrentIndex(index)
        suspendPreview()
        let player = VideoPlayerViewController(playInfo: items[index].playInfo,
                                               playMode: .feedFlow,
                                               playContextCache: playContextCache)
        player.sequenceProvider = sequenceProvider
        present(player, animated: true)
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
        guard !items.isEmpty else { return nil }
        return IndexPath(item: min(focusedIndex, items.count - 1), section: 0)
    }
}

extension FeaturedBrowserViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        enterFlow(at: indexPath.item)
    }

    func collectionView(_ collectionView: UICollectionView,
                        didUpdateFocusIn context: UICollectionViewFocusUpdateContext,
                        with coordinator: UIFocusAnimationCoordinator)
    {
        guard let nextIndexPath = context.nextFocusedIndexPath,
              items.indices.contains(nextIndexPath.item)
        else { return }
        focusedIndex = nextIndexPath.item
        collectionView.selectItem(at: nextIndexPath, animated: true, scrollPosition: .centeredVertically)
        sequenceProvider.setCurrentIndex(focusedIndex)
        schedulePreview(for: items[focusedIndex])
        collectionView.visibleCells.compactMap { $0 as? FeaturedVideoListCell }.forEach { cell in
            if let indexPath = collectionView.indexPath(for: cell), items.indices.contains(indexPath.item) {
                cell.configure(with: items[indexPath.item], isCurrent: indexPath.item == focusedIndex)
            }
        }
        if items.count - focusedIndex - 1 < trailingPrefetchTargetCount {
            Task {
                await loadMoreShortVideosIfNeeded(targetCount: trailingPrefetchTargetCount, maxSourcePages: trailingMaxSourcePages)
                await MainActor.run {
                    collectionView.reloadData()
                }
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard indexPath.item >= items.count - 4 else { return }
        Task {
            await loadMoreShortVideosIfNeeded(targetCount: trailingPrefetchTargetCount, maxSourcePages: trailingMaxSourcePages)
            await MainActor.run {
                collectionView.reloadData()
            }
        }
    }
}

final class FeaturedVideoListCell: BLMotionCollectionViewCell {
    static let reuseID = String(describing: FeaturedVideoListCell.self)

    private let blurBackgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    private let imageView = UIImageView()
    private let titleLabel = UILabel()
    private let metaLabel = UILabel()
    private let currentBadgeLabel = UILabel()
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

        blurBackgroundView.contentView.addSubview(titleLabel)
        blurBackgroundView.contentView.addSubview(metaLabel)
        blurBackgroundView.contentView.addSubview(currentBadgeLabel)

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

        currentBadgeLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-18)
            make.bottom.equalToSuperview().offset(-18)
        }
        currentBadgeLabel.font = .systemFont(ofSize: 20, weight: .bold)
        currentBadgeLabel.textColor = .black
        currentBadgeLabel.backgroundColor = UIColor.white
        currentBadgeLabel.layer.cornerRadius = 10
        currentBadgeLabel.layer.cornerCurve = .continuous
        currentBadgeLabel.clipsToBounds = true
        currentBadgeLabel.textAlignment = .center
        currentBadgeLabel.text = "当前"
    }

    func configure(with item: RecommendedVideoItem, isCurrent: Bool) {
        titleLabel.text = item.title
        metaLabel.text = item.metaText
        currentBadgeLabel.isHidden = !isCurrent
        self.isCurrent = isCurrent
        if let coverURL = item.coverURL {
            imageView.kf.setImage(with: coverURL)
        } else {
            imageView.image = nil
        }
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
