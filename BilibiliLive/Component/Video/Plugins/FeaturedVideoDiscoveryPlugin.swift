//
//  FeaturedVideoDiscoveryPlugin.swift
//  BilibiliLive
//
//  Created by OpenAI on 2026/4/5.
//

import AVKit
import UIKit

private final class FeaturedVideoDiscoveryInfoViewController: UIViewController {
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

extension FeaturedVideoDiscoveryInfoViewController: UICollectionViewDataSource, UICollectionViewDelegate {
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

final class FeaturedVideoDiscoveryPlugin: NSObject, CommonPlayerPlugin {
    private enum DiscoverySource {
        case uploader
        case related

        var tabTitle: String {
            switch self {
            case .uploader:
                return "博主视频"
            case .related:
                return "推荐视频"
            }
        }

        var emptyText: String {
            switch self {
            case .uploader:
                return "当前没有可展示的博主视频"
            case .related:
                return "当前没有可展示的推荐视频"
            }
        }
    }

    private struct DiscoveryEntry: Hashable {
        let playInfo: PlayInfo
    }

    var onPlayTemporary: ((PlayInfo) -> Void)?

    private let detail: VideoDetail?
    private let currentPlayInfo: PlayInfo
    private let sequenceProvider: VideoSequenceProvider?
    private let uploaderInfoViewController = FeaturedVideoDiscoveryInfoViewController(title: DiscoverySource.uploader.tabTitle,
                                                                                      emptyText: DiscoverySource.uploader.emptyText)
    private let relatedInfoViewController = FeaturedVideoDiscoveryInfoViewController(title: DiscoverySource.related.tabTitle,
                                                                                     emptyText: DiscoverySource.related.emptyText)
    private let relatedCandidates: [DiscoveryEntry]
    private var uploaderEntries = [DiscoveryEntry]()
    private var uploaderLoadTask: Task<Void, Never>?
    private weak var playerVC: AVPlayerViewController?

    init(detail: VideoDetail?, currentPlayInfo: PlayInfo, sequenceProvider: VideoSequenceProvider?) {
        self.detail = detail
        self.currentPlayInfo = currentPlayInfo
        self.sequenceProvider = sequenceProvider
        relatedCandidates = Self.makeRelatedEntries(detail: detail, currentPlayInfo: currentPlayInfo)
        super.init()
        let onSelect: (PlayInfo) -> Void = { [weak self] playInfo in
            guard let self else { return }
            let currentSequenceKey = self.sequenceProvider.flatMap { provider in
                MainActor.assumeIsolated {
                    provider.current()?.sequenceKey
                }
            } ?? self.currentPlayInfo.sequenceKey
            guard currentSequenceKey != playInfo.sequenceKey else { return }
            self.onPlayTemporary?(playInfo)
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
        guard let mid = detail?.View.owner.mid, mid > 0 else { return }
        uploaderLoadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let records = try await ApiRequest.requestUpSpaceVideo(mid: mid, lastAid: nil, pageSize: 18)
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

    private func makeViewEntry(from entry: DiscoveryEntry) -> FeaturedVideoDiscoveryInfoViewController.Entry {
        FeaturedVideoDiscoveryInfoViewController.Entry(playInfo: entry.playInfo,
                                                       displayData: FeaturedVideoDiscoveryInfoViewController.DiscoveryDisplayData(title: entry.playInfo.title ?? "",
                                                                                                                                  ownerName: entry.playInfo.ownerName ?? "",
                                                                                                                                  pic: entry.playInfo.coverURL))
    }

    private func refreshCustomInfoViewControllers() {
        guard let playerVC else { return }
        var controllers = playerVC.customInfoViewControllers.filter {
            $0 !== uploaderInfoViewController && $0 !== relatedInfoViewController
        }
        controllers.append(uploaderInfoViewController)
        controllers.append(relatedInfoViewController)
        playerVC.customInfoViewControllers = controllers
    }

    private func removeCustomInfoViewControllers() {
        guard let playerVC else { return }
        playerVC.customInfoViewControllers.removeAll {
            $0 === uploaderInfoViewController || $0 === relatedInfoViewController
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
