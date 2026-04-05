//
//  FeaturedVideoDiscoveryPlugin.swift
//  BilibiliLive
//
//  Created by OpenAI on 2026/4/5.
//

import AVKit
import UIKit

private final class FeaturedVideoDiscoveryHeaderView: UICollectionReusableView {
    static let reuseIdentifier = "FeaturedVideoDiscoveryHeaderView"

    let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        titleLabel.font = .systemFont(ofSize: 30, weight: .bold)
        titleLabel.textColor = .white
        addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class FeaturedVideoDiscoveryInfoViewController: UIViewController {
    fileprivate enum Section: Int, CaseIterable {
        case uploader
        case related

        var title: String {
            switch self {
            case .uploader:
                return "博主视频"
            case .related:
                return "推荐视频"
            }
        }
    }

    fileprivate struct Entry: Hashable {
        let section: Section
        let playInfo: PlayInfo
        let displayData: DiscoveryDisplayData
    }

    fileprivate struct DiscoveryDisplayData: DisplayData {
        let title: String
        let ownerName: String
        let pic: URL?
    }

    var onSelect: ((PlayInfo) -> Void)?

    private var uploaderEntries = [Entry]()
    private var relatedEntries = [Entry]()

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, _ in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                  heightDimension: .estimated(220))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.3),
                                                   heightDimension: .estimated(220))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = 24
            section.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 32, bottom: 24, trailing: 32)
            let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                    heightDimension: .absolute(44))
            let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize,
                                                                     elementKind: UICollectionView.elementKindSectionHeader,
                                                                     alignment: .top)
            section.boundarySupplementaryItems = [header]
            return section
        }

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.remembersLastFocusedIndexPath = true
        collectionView.register(RelatedVideoCell.self, forCellWithReuseIdentifier: String(describing: RelatedVideoCell.self))
        collectionView.register(FeaturedVideoDiscoveryHeaderView.self,
                                forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                                withReuseIdentifier: FeaturedVideoDiscoveryHeaderView.reuseIdentifier)
        return collectionView
    }()

    private let emptyLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 28, weight: .medium)
        label.textColor = UIColor.white.withAlphaComponent(0.75)
        label.numberOfLines = 2
        label.textAlignment = .center
        label.text = "当前没有可展示的推荐内容"
        label.isHidden = true
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "推荐"
        preferredContentSize = CGSize(width: 0, height: 560)
        view.backgroundColor = .clear

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

    fileprivate func update(uploaderEntries: [Entry], relatedEntries: [Entry]) {
        self.uploaderEntries = uploaderEntries
        self.relatedEntries = relatedEntries
        guard isViewLoaded else { return }
        collectionView.reloadData()
        updateEmptyState()
    }

    private func entries(for section: Section) -> [Entry] {
        switch section {
        case .uploader:
            return uploaderEntries
        case .related:
            return relatedEntries
        }
    }

    private func visibleSections() -> [Section] {
        Section.allCases.filter { !entries(for: $0).isEmpty }
    }

    private func updateEmptyState() {
        let isEmpty = visibleSections().isEmpty
        emptyLabel.isHidden = !isEmpty
        collectionView.isHidden = isEmpty
    }
}

extension FeaturedVideoDiscoveryInfoViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        visibleSections().count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let sections = visibleSections()
        guard sections.indices.contains(section) else { return 0 }
        return entries(for: sections[section]).count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let sections = visibleSections()
        let section = sections[indexPath.section]
        let entry = entries(for: section)[indexPath.item]
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: RelatedVideoCell.self), for: indexPath) as! RelatedVideoCell
        cell.update(data: entry.displayData)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView
    {
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind,
                                                                     withReuseIdentifier: FeaturedVideoDiscoveryHeaderView.reuseIdentifier,
                                                                     for: indexPath) as! FeaturedVideoDiscoveryHeaderView
        let sections = visibleSections()
        header.titleLabel.text = sections[indexPath.section].title
        return header
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let sections = visibleSections()
        let section = sections[indexPath.section]
        let entry = entries(for: section)[indexPath.item]
        onSelect?(entry.playInfo)
    }
}

final class FeaturedVideoDiscoveryPlugin: NSObject, CommonPlayerPlugin {
    private enum DiscoverySource {
        case uploader
        case related

        var section: FeaturedVideoDiscoveryInfoViewController.Section {
            switch self {
            case .uploader:
                return .uploader
            case .related:
                return .related
            }
        }
    }

    private struct DiscoveryEntry: Hashable {
        let source: DiscoverySource
        let playInfo: PlayInfo
    }

    var onPlayTemporary: ((PlayInfo) -> Void)?

    private let detail: VideoDetail?
    private let currentPlayInfo: PlayInfo
    private let sequenceProvider: VideoSequenceProvider?
    private let discoveryInfoViewController = FeaturedVideoDiscoveryInfoViewController()
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
        discoveryInfoViewController.onSelect = { [weak self] playInfo in
            guard let self else { return }
            let currentSequenceKey = self.sequenceProvider.flatMap { provider in
                MainActor.assumeIsolated {
                    provider.current()?.sequenceKey
                }
            } ?? self.currentPlayInfo.sequenceKey
            guard currentSequenceKey != playInfo.sequenceKey else { return }
            self.onPlayTemporary?(playInfo)
        }
        refreshDiscoveryTab()
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
                let records = try await ApiRequest.requestUpSpaceVideo(mid: mid, lastAid: nil, pageSize: 12)
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
                    return DiscoveryEntry(source: .uploader, playInfo: playInfo)
                }

                await MainActor.run {
                    self.uploaderEntries = Array(entries.prefix(3))
                    self.refreshDiscoveryTab()
                }
            } catch {
                await MainActor.run {
                    self.uploaderEntries = []
                    self.refreshDiscoveryTab()
                }
            }
        }
    }

    private func refreshDiscoveryTab() {
        let uploaderEntries = uploaderEntries.map(makeViewEntry(from:))
        let uploaderAids = Set(uploaderEntries.map(\.playInfo.aid))
        let relatedEntries = relatedCandidates
            .filter { !uploaderAids.contains($0.playInfo.aid) }
            .prefix(3)
            .map(makeViewEntry(from:))
        discoveryInfoViewController.update(uploaderEntries: uploaderEntries, relatedEntries: Array(relatedEntries))
    }

    private func makeViewEntry(from entry: DiscoveryEntry) -> FeaturedVideoDiscoveryInfoViewController.Entry {
        FeaturedVideoDiscoveryInfoViewController.Entry(section: entry.source.section,
                                                       playInfo: entry.playInfo,
                                                       displayData: FeaturedVideoDiscoveryInfoViewController.DiscoveryDisplayData(title: entry.playInfo.title ?? "",
                                                                                                                                  ownerName: entry.playInfo.ownerName ?? "",
                                                                                                                                  pic: entry.playInfo.coverURL))
    }

    private func refreshCustomInfoViewControllers() {
        guard let playerVC else { return }
        var controllers = playerVC.customInfoViewControllers.filter { $0 !== discoveryInfoViewController }
        controllers.append(discoveryInfoViewController)
        playerVC.customInfoViewControllers = controllers
    }

    private func removeCustomInfoViewControllers() {
        guard let playerVC else { return }
        playerVC.customInfoViewControllers.removeAll { $0 === discoveryInfoViewController }
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
            return DiscoveryEntry(source: .related, playInfo: playInfo)
        }
    }
}
