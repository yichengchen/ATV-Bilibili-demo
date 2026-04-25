//
//  VideoPlayerInfoTabsPlugin.swift
//  BilibiliLive
//
//  Created by OpenAI on 2026/4/5.
//

import AVKit
import UIKit

private final class VideoPlayerDiscoveryInfoViewController: UIViewController {
    private enum Layout {
        static let cardWidth: CGFloat = 320
        static let cardHeight: CGFloat = 248
        static let sectionInsets = NSDirectionalEdgeInsets(top: 28, leading: 32, bottom: 28, trailing: 32)
        static let interGroupSpacing: CGFloat = 28
        static let preferredHeight: CGFloat = 360
    }

    fileprivate struct Entry: Hashable {
        let playInfo: PlayInfo
        let displayData: DiscoveryDisplayData
    }

    fileprivate struct DiscoveryDisplayData: DisplayData {
        let title: String
        let ownerName: String
        let pic: URL?
    }

    var onSelect: ((PlayInfo) -> Void)?

    private let emptyText: String
    private var entries = [Entry]()

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewCompositionalLayout { _, _ in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                  heightDimension: .fractionalHeight(1.0))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let groupSize = NSCollectionLayoutSize(widthDimension: .absolute(Layout.cardWidth),
                                                   heightDimension: .absolute(Layout.cardHeight))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = Layout.sectionInsets
            section.interGroupSpacing = Layout.interGroupSpacing
            section.orthogonalScrollingBehavior = .continuousGroupLeadingBoundary
            return section
        }

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.remembersLastFocusedIndexPath = true
        collectionView.alwaysBounceVertical = false
        collectionView.register(RelatedVideoCell.self, forCellWithReuseIdentifier: String(describing: RelatedVideoCell.self))
        return collectionView
    }()

    private let emptyLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 28, weight: .medium)
        label.textColor = UIColor.white.withAlphaComponent(0.75)
        label.numberOfLines = 2
        label.textAlignment = .center
        label.isHidden = true
        return label
    }()

    init(title: String, emptyText: String) {
        self.emptyText = emptyText
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        preferredContentSize = CGSize(width: 0, height: Layout.preferredHeight)
        view.backgroundColor = .clear
        emptyLabel.text = emptyText

        view.addSubview(collectionView)
        view.addSubview(emptyLabel)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            emptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32),
        ])
        updateEmptyState()
    }

    fileprivate func update(entries: [Entry]) {
        self.entries = entries
        guard isViewLoaded else { return }
        collectionView.reloadData()
        updateEmptyState()
    }

    private func updateEmptyState() {
        let isEmpty = entries.isEmpty
        emptyLabel.isHidden = !isEmpty
        collectionView.isHidden = isEmpty
    }
}

extension VideoPlayerDiscoveryInfoViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        entries.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let entry = entries[indexPath.item]
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: RelatedVideoCell.self),
                                                      for: indexPath) as! RelatedVideoCell
        cell.update(data: entry.displayData)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        onSelect?(entries[indexPath.item].playInfo)
    }
}

private final class VideoPlayerInfoActionCell: BLMotionCollectionViewCell {
    struct ViewModel: Hashable {
        let title: String
        let valueText: String
        let imageName: String
        let selectedImageName: String
        let isOn: Bool
    }

    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    private let focusedBackgroundView = UIView()
    private let imageView = UIImageView()
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private var viewModel: ViewModel?

    override func setup() {
        super.setup()
        scaleFactor = 1.08
        contentView.addSubview(blurView)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.layer.cornerRadius = 18
        blurView.layer.cornerCurve = .continuous
        blurView.clipsToBounds = true

        focusedBackgroundView.backgroundColor = .white
        focusedBackgroundView.isHidden = true
        blurView.contentView.addSubview(focusedBackgroundView)
        focusedBackgroundView.translatesAutoresizingMaskIntoConstraints = false

        imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 40, weight: .semibold)
        imageView.contentMode = .scaleAspectFit
        blurView.contentView.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: 30, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2
        blurView.contentView.addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        valueLabel.font = .systemFont(ofSize: 24, weight: .medium)
        valueLabel.textAlignment = .center
        valueLabel.numberOfLines = 1
        blurView.contentView.addSubview(valueLabel)
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            blurView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            blurView.topAnchor.constraint(equalTo: contentView.topAnchor),
            blurView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            focusedBackgroundView.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor),
            focusedBackgroundView.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor),
            focusedBackgroundView.topAnchor.constraint(equalTo: blurView.contentView.topAnchor),
            focusedBackgroundView.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor),

            imageView.centerXAnchor.constraint(equalTo: blurView.contentView.centerXAnchor),
            imageView.topAnchor.constraint(equalTo: blurView.contentView.topAnchor, constant: 34),
            imageView.widthAnchor.constraint(equalToConstant: 54),
            imageView.heightAnchor.constraint(equalToConstant: 54),

            titleLabel.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: 18),
            titleLabel.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor, constant: -18),
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 18),

            valueLabel.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: 18),
            valueLabel.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor, constant: -18),
            valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            valueLabel.bottomAnchor.constraint(lessThanOrEqualTo: blurView.contentView.bottomAnchor, constant: -24),
        ])
    }

    func update(viewModel: ViewModel) {
        self.viewModel = viewModel
        titleLabel.text = viewModel.title
        valueLabel.text = viewModel.valueText
        updateAppearance()
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        updateAppearance()
    }

    private func updateAppearance() {
        guard let viewModel else { return }
        focusedBackgroundView.isHidden = !isFocused
        let iconName = viewModel.isOn ? viewModel.selectedImageName : viewModel.imageName
        imageView.image = UIImage(systemName: iconName)
        let foregroundColor: UIColor = isFocused ? .black : .white
        imageView.tintColor = foregroundColor
        titleLabel.textColor = foregroundColor
        valueLabel.textColor = isFocused ? UIColor.black.withAlphaComponent(0.85) : UIColor.white.withAlphaComponent(0.8)
    }
}

private final class VideoPlayerActionInfoViewController: UIViewController {
    private enum Layout {
        static let cardWidth: CGFloat = 260
        static let cardHeight: CGFloat = 210
        static let sectionInsets = NSDirectionalEdgeInsets(top: 28, leading: 32, bottom: 28, trailing: 32)
        static let interGroupSpacing: CGFloat = 24
        static let preferredHeight: CGFloat = 320
    }

    enum ActionKind: Hashable {
        case follow
        case like
        case favorite

        var title: String {
            switch self {
            case .follow:
                return "关注博主"
            case .like:
                return "点赞视频"
            case .favorite:
                return "收藏视频"
            }
        }

        var imageName: String {
            switch self {
            case .follow:
                return "heart"
            case .like:
                return "hand.thumbsup"
            case .favorite:
                return "star"
            }
        }

        var selectedImageName: String {
            switch self {
            case .follow:
                return "heart.fill"
            case .like:
                return "hand.thumbsup.fill"
            case .favorite:
                return "star.fill"
            }
        }
    }

    private struct Entry: Hashable {
        let kind: ActionKind
        var isOn: Bool
        var valueText: String
        var countValue: Int?
    }

    private let aid: Int
    private let ownerMid: Int
    private var entries: [Entry]
    private var inFlightKinds = Set<ActionKind>()
    private var locallyMutatedKinds = Set<ActionKind>()

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewCompositionalLayout { _, _ in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                  heightDimension: .fractionalHeight(1.0))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let groupSize = NSCollectionLayoutSize(widthDimension: .absolute(Layout.cardWidth),
                                                   heightDimension: .absolute(Layout.cardHeight))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = Layout.sectionInsets
            section.interGroupSpacing = Layout.interGroupSpacing
            section.orthogonalScrollingBehavior = .continuousGroupLeadingBoundary
            return section
        }

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.remembersLastFocusedIndexPath = true
        collectionView.alwaysBounceVertical = false
        collectionView.register(VideoPlayerInfoActionCell.self,
                                forCellWithReuseIdentifier: String(describing: VideoPlayerInfoActionCell.self))
        return collectionView
    }()

    init(detail: VideoDetail?) {
        aid = detail?.View.aid ?? 0
        ownerMid = detail?.View.owner.mid ?? 0
        let followerText = "\((detail?.Card.follower ?? 0).numberString())粉丝"
        let likeCount = detail?.View.stat.like ?? 0
        let favoriteCount = detail?.View.stat.favorite ?? 0
        entries = [
            Entry(kind: .follow, isOn: detail?.Card.following ?? false, valueText: followerText, countValue: nil),
            Entry(kind: .like, isOn: false, valueText: likeCount.numberString(), countValue: likeCount),
            Entry(kind: .favorite, isOn: false, valueText: favoriteCount.numberString(), countValue: favoriteCount),
        ]
        super.init(nibName: nil, bundle: nil)
        title = "互动"
        loadRemoteStatesIfNeeded()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        preferredContentSize = CGSize(width: 0, height: Layout.preferredHeight)
        view.backgroundColor = .clear
        view.addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func loadRemoteStatesIfNeeded() {
        guard aid > 0 else { return }
        WebRequest.requestLikeStatus(aid: aid) { [weak self] isLiked in
            Task { @MainActor in
                self?.applyRemoteState(for: .like, isOn: isLiked)
            }
        }
        WebRequest.requestFavoriteStatus(aid: aid) { [weak self] isFavorited in
            Task { @MainActor in
                self?.applyRemoteState(for: .favorite, isOn: isFavorited)
            }
        }
    }

    private func applyRemoteState(for kind: ActionKind, isOn: Bool) {
        guard !inFlightKinds.contains(kind),
              !locallyMutatedKinds.contains(kind)
        else {
            return
        }
        updateState(for: kind, isOn: isOn)
    }

    private func updateState(for kind: ActionKind, isOn: Bool) {
        guard let index = entries.firstIndex(where: { $0.kind == kind }) else { return }
        entries[index].isOn = isOn
        if isViewLoaded {
            collectionView.reloadData()
        }
    }

    private func updateCount(for kind: ActionKind, delta: Int) {
        guard let index = entries.firstIndex(where: { $0.kind == kind }) else { return }
        let currentCount = entries[index].countValue ?? 0
        let nextCount = max(0, currentCount + delta)
        entries[index].countValue = nextCount
        entries[index].valueText = nextCount.numberString()
    }

    private func handleFollow() {
        guard ownerMid > 0,
              let index = entries.firstIndex(where: { $0.kind == .follow })
        else { return }

        entries[index].isOn.toggle()
        collectionView.reloadData()
        WebRequest.follow(mid: ownerMid, follow: entries[index].isOn)
    }

    private func handleLike() {
        guard aid > 0,
              !inFlightKinds.contains(.like),
              let index = entries.firstIndex(where: { $0.kind == .like })
        else { return }

        inFlightKinds.insert(.like)
        locallyMutatedKinds.insert(.like)
        let previous = entries[index]
        entries[index].isOn.toggle()
        updateCount(for: .like, delta: entries[index].isOn ? 1 : -1)
        collectionView.reloadData()

        let nextState = entries[index].isOn
        Task { [weak self] in
            guard let self else { return }
            let success = await WebRequest.requestLike(aid: self.aid, like: nextState)
            await MainActor.run {
                self.inFlightKinds.remove(.like)
                guard !success else { return }
                if let rollbackIndex = self.entries.firstIndex(where: { $0.kind == .like }) {
                    self.entries[rollbackIndex] = previous
                    self.collectionView.reloadData()
                }
            }
        }
    }

    private func handleFavorite() {
        guard aid > 0, !inFlightKinds.contains(.favorite) else { return }
        inFlightKinds.insert(.favorite)

        Task { [weak self] in
            guard let self else { return }
            guard let favList = try? await WebRequest.requestFavVideosList() else {
                _ = await MainActor.run {
                    self.inFlightKinds.remove(.favorite)
                }
                return
            }

            await MainActor.run {
                if let index = self.entries.firstIndex(where: { $0.kind == .favorite }),
                   self.entries[index].isOn
                {
                    self.locallyMutatedKinds.insert(.favorite)
                    self.entries[index].isOn = false
                    self.updateCount(for: .favorite, delta: -1)
                    self.collectionView.reloadData()
                    self.inFlightKinds.remove(.favorite)
                    WebRequest.removeFavorite(aid: self.aid, mid: favList.map(\.id))
                    return
                }

                self.presentFavoritePicker(favList: favList)
            }
        }
    }

    private func presentFavoritePicker(favList: [FavListData]) {
        guard let presenter = activePresenterForFavoritePicker() else {
            inFlightKinds.remove(.favorite)
            return
        }

        let alert = UIAlertController(title: "收藏", message: nil, preferredStyle: .actionSheet)
        for fav in favList {
            alert.addAction(UIAlertAction(title: fav.title, style: .default) { [weak self] _ in
                guard let self else { return }
                if let index = self.entries.firstIndex(where: { $0.kind == .favorite }) {
                    self.locallyMutatedKinds.insert(.favorite)
                    self.entries[index].isOn = true
                    self.updateCount(for: .favorite, delta: 1)
                    self.collectionView.reloadData()
                }
                self.inFlightKinds.remove(.favorite)
                WebRequest.requestFavorite(aid: self.aid, mid: fav.id)
            })
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { [weak self] _ in
            self?.inFlightKinds.remove(.favorite)
        })

        presenter.present(alert, animated: true)
    }

    private func activePresenterForFavoritePicker() -> UIViewController? {
        guard isViewLoaded, view.window != nil else { return nil }
        var presenter: UIViewController = self
        while let parent = presenter.parent, parent.viewIfLoaded?.window != nil {
            presenter = parent
        }
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        return presenter
    }
}

extension VideoPlayerActionInfoViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        entries.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let entry = entries[indexPath.item]
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: VideoPlayerInfoActionCell.self),
                                                      for: indexPath) as! VideoPlayerInfoActionCell
        cell.update(viewModel: .init(title: entry.kind.title,
                                     valueText: entry.valueText,
                                     imageName: entry.kind.imageName,
                                     selectedImageName: entry.kind.selectedImageName,
                                     isOn: entry.isOn))
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let entry = entries[indexPath.item]
        switch entry.kind {
        case .follow:
            handleFollow()
        case .like:
            handleLike()
        case .favorite:
            handleFavorite()
        }
    }
}

final class VideoPlayerInfoTabsPlugin: NSObject, CommonPlayerPlugin {
    private enum DiscoverySource {
        case uploader
        case related

        var tabTitle: String {
            switch self {
            case .uploader:
                return "博主视频"
            case .related:
                return "相关视频"
            }
        }

        var emptyText: String {
            switch self {
            case .uploader:
                return "当前没有可展示的博主视频"
            case .related:
                return "当前没有可展示的相关视频"
            }
        }
    }

    private struct DiscoveryEntry: Hashable {
        let playInfo: PlayInfo
    }

    var onSelectDiscovery: ((PlayInfo) -> Void)?

    private let currentPlayInfo: PlayInfo
    private let sequenceProvider: VideoSequenceProvider?
    private let uploaderInfoViewController = VideoPlayerDiscoveryInfoViewController(title: DiscoverySource.uploader.tabTitle,
                                                                                    emptyText: DiscoverySource.uploader.emptyText)
    private let relatedInfoViewController = VideoPlayerDiscoveryInfoViewController(title: DiscoverySource.related.tabTitle,
                                                                                   emptyText: DiscoverySource.related.emptyText)
    private let actionInfoViewController: VideoPlayerActionInfoViewController
    private let relatedCandidates: [DiscoveryEntry]
    private let ownerMid: Int
    private var uploaderEntries = [DiscoveryEntry]()
    private var uploaderLoadTask: Task<Void, Never>?
    private weak var playerVC: AVPlayerViewController?

    init(detail: VideoDetail?, currentPlayInfo: PlayInfo, sequenceProvider: VideoSequenceProvider?) {
        self.currentPlayInfo = currentPlayInfo
        self.sequenceProvider = sequenceProvider
        ownerMid = detail?.View.owner.mid ?? 0
        relatedCandidates = Self.makeRelatedEntries(detail: detail, currentPlayInfo: currentPlayInfo)
        actionInfoViewController = VideoPlayerActionInfoViewController(detail: detail)
        super.init()

        let onSelect: (PlayInfo) -> Void = { [weak self] playInfo in
            guard let self else { return }
            let currentSequenceKey = self.sequenceProvider.flatMap { provider in
                MainActor.assumeIsolated {
                    provider.current()?.sequenceKey
                }
            } ?? self.currentPlayInfo.sequenceKey
            guard currentSequenceKey != playInfo.sequenceKey else { return }
            self.onSelectDiscovery?(playInfo)
        }
        uploaderInfoViewController.onSelect = onSelect
        relatedInfoViewController.onSelect = onSelect
        refreshDiscoveryTabs()
        loadUploaderEntriesIfNeeded()
    }

    deinit {
        uploaderLoadTask?.cancel()
    }

    func playerDidLoad(playerVC: AVPlayerViewController) {
        self.playerVC = playerVC
        refreshCustomInfoViewControllers()
    }

    func playerDidDismiss(playerVC: AVPlayerViewController) {
        removeCustomInfoViewControllers()
        uploaderLoadTask?.cancel()
        uploaderLoadTask = nil
    }

    func playerWillCleanUp(playerVC: AVPlayerViewController) {
        removeCustomInfoViewControllers()
        uploaderLoadTask?.cancel()
        uploaderLoadTask = nil
    }

    private func loadUploaderEntriesIfNeeded() {
        guard ownerMid > 0 else { return }
        uploaderLoadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let records = try await ApiRequest.requestUpSpaceVideo(mid: self.ownerMid, lastAid: nil, pageSize: 18)
                guard !Task.isCancelled else { return }

                var seenAids = Set<Int>()
                let entries = records.compactMap { record -> DiscoveryEntry? in
                    guard record.aid > 0,
                          record.aid != self.currentPlayInfo.aid,
                          seenAids.insert(record.aid).inserted
                    else {
                        return nil
                    }
                    let playInfo = PlayInfo(aid: record.aid,
                                            title: record.title,
                                            ownerName: record.ownerName,
                                            coverURL: record.pic,
                                            duration: record.duration)
                    return DiscoveryEntry(playInfo: playInfo)
                }

                await MainActor.run {
                    self.uploaderEntries = Array(entries.prefix(6))
                    self.refreshDiscoveryTabs()
                }
            } catch {
                await MainActor.run {
                    self.uploaderEntries = []
                    self.refreshDiscoveryTabs()
                }
            }
        }
    }

    private func refreshDiscoveryTabs() {
        uploaderInfoViewController.update(entries: uploaderEntries.prefix(6).map(makeViewEntry(from:)))
        relatedInfoViewController.update(entries: relatedCandidates.prefix(6).map(makeViewEntry(from:)))
    }

    private func makeViewEntry(from entry: DiscoveryEntry) -> VideoPlayerDiscoveryInfoViewController.Entry {
        VideoPlayerDiscoveryInfoViewController.Entry(playInfo: entry.playInfo,
                                                     displayData: VideoPlayerDiscoveryInfoViewController.DiscoveryDisplayData(title: entry.playInfo.title ?? "",
                                                                                                                              ownerName: entry.playInfo.ownerName ?? "",
                                                                                                                              pic: entry.playInfo.coverURL))
    }

    private func refreshCustomInfoViewControllers() {
        guard let playerVC else { return }
        var controllers = playerVC.customInfoViewControllers.filter {
            $0 !== uploaderInfoViewController &&
                $0 !== relatedInfoViewController &&
                $0 !== actionInfoViewController
        }
        controllers.append(uploaderInfoViewController)
        controllers.append(relatedInfoViewController)
        controllers.append(actionInfoViewController)
        playerVC.customInfoViewControllers = controllers
    }

    private func removeCustomInfoViewControllers() {
        guard let playerVC else { return }
        playerVC.customInfoViewControllers.removeAll {
            $0 === uploaderInfoViewController ||
                $0 === relatedInfoViewController ||
                $0 === actionInfoViewController
        }
    }

    private static func makeRelatedEntries(detail: VideoDetail?, currentPlayInfo: PlayInfo) -> [DiscoveryEntry] {
        let related = detail?.Related ?? []
        var seenAids = Set<Int>()
        return related.compactMap { info -> DiscoveryEntry? in
            guard info.aid > 0,
                  info.aid != currentPlayInfo.aid,
                  seenAids.insert(info.aid).inserted
            else {
                return nil
            }

            let playInfo = PlayInfo(aid: info.aid,
                                    cid: info.cid,
                                    title: info.title,
                                    ownerName: info.ownerName,
                                    coverURL: info.pic,
                                    duration: info.duration)
            return DiscoveryEntry(playInfo: playInfo)
        }
    }
}
