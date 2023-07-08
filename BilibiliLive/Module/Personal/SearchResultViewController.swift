//
//  SearchResultViewController.swift
//  BilibiliLive
//
//  Created by whw on 2022/11/2.
//

import Combine
import Kingfisher
import UIKit

class SearchResultViewController: UIViewController {
    var collectionView: UICollectionView!
    var dataSource: UICollectionViewDiffableDataSource<SearchList, AnyHashable>!
    var currentSnapshot: NSDiffableDataSourceSnapshot<SearchList, AnyHashable>!
    static let titleElementKind = "titleElementKind"

    @Published var searchText: String = ""
    var cancellable: Cancellable?

    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        collectionView.delegate = self
        tabBarObservedScrollView = collectionView
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        configureDataSource()

        cancellable = $searchText
            .filter({ $0.count > 0 })
            .debounce(for: 0.8, scheduler: RunLoop.main)
            .removeDuplicates()
            .sink {
                [weak self] key in
                guard let self = self else { return }
                WebRequest.requestSearchResult(key: key) { [weak self] searchResult in
                    guard let self = self else { return }
                    currentSnapshot.deleteAllItems()

                    let defaultHeight = NSCollectionLayoutDimension.fractionalWidth(Settings.displayStyle == .large ? 0.26 : 0.2)
                    for section in searchResult.result {
                        switch section {
                        case let .video(data):
                            let list = SearchList(title: "视频", height: defaultHeight, scrollingBehavior: .continuous)
                            currentSnapshot.appendSections([list])
                            currentSnapshot.appendItems(data, toSection: list)
                        case let .bangumi(data):
                            let list = SearchList(title: "番剧", height: defaultHeight, scrollingBehavior: .continuous)
                            currentSnapshot.appendSections([list])
                            currentSnapshot.appendItems(data, toSection: list)
                        case let .movie(data):
                            let list = SearchList(title: "影视", height: defaultHeight, scrollingBehavior: .none)
                            currentSnapshot.appendSections([list])
                            currentSnapshot.appendItems(data, toSection: list)
                        case let .user(data):
                            let list = SearchList(title: "用户", height: .estimated(140), scrollingBehavior: .continuous)
                            currentSnapshot.appendSections([list])
                            currentSnapshot.appendItems(data, toSection: list)
                        case .none:
                            break
                        }
                    }

                    dataSource.apply(currentSnapshot)
                }
            }
    }
}

extension SearchResultViewController {
    private func createLayout() -> UICollectionViewLayout {
        let sectionProvider = { [self]
            (sectionIndex: Int, layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection? in
                let sectionIdentifier = dataSource.snapshot().sectionIdentifiers[sectionIndex]

                let section: NSCollectionLayoutSection
                if sectionIdentifier.scrollingBehavior == .none {
                    let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                           heightDimension: sectionIdentifier.height)
                    let itemSize = NSCollectionLayoutSize(widthDimension: sectionIdentifier.width,
                                                          heightDimension: .fractionalHeight(1))
                    let item = NSCollectionLayoutItem(layoutSize: itemSize)
                    let hSpacing: CGFloat = Settings.displayStyle == .large ? 35 : 30
                    item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: hSpacing, bottom: 0, trailing: hSpacing)
                    let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
                    group.edgeSpacing = .init(leading: .fixed(0), top: .fixed(40), trailing: .fixed(0), bottom: .fixed(-60))
                    section = NSCollectionLayoutSection(group: group)
                } else {
                    let groupSize = NSCollectionLayoutSize(widthDimension: sectionIdentifier.width,
                                                           heightDimension: sectionIdentifier.height)
                    let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                          heightDimension: .fractionalHeight(1))
                    let item = NSCollectionLayoutItem(layoutSize: itemSize)
                    let hSpacing: CGFloat = Settings.displayStyle == .large ? 35 : 30
                    item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: hSpacing, bottom: 0, trailing: hSpacing)
                    let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
                    group.edgeSpacing = .init(leading: .fixed(0), top: .fixed(40), trailing: .fixed(0), bottom: .fixed(0))
                    section = NSCollectionLayoutSection(group: group)
                    section.orthogonalScrollingBehavior = sectionIdentifier.scrollingBehavior
                }

                let titleSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                       heightDimension: .estimated(44))
                let titleSupplementary = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: titleSize,
                    elementKind: FavoriteViewController.titleElementKind,
                    alignment: .top
                )
                section.boundarySupplementaryItems = [titleSupplementary]
                return section
        }

        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.interSectionSpacing = 20

        let layout = UICollectionViewCompositionalLayout(
            sectionProvider: sectionProvider, configuration: config
        )
        return layout
    }

    private func configureDataSource() {
        let displayCell = UICollectionView.CellRegistration<FeedCollectionViewCell, DisplayData> {
            $0.setup(data: $2)
        }
        let userCell = UICollectionView.CellRegistration<UpCell, SearchResult.User> {
            $0.nameLabel.text = $2.uname
            $0.despLabel.text = $2.usign
            $0.imageView.kf.setImage(with: $2.upic.addSchemeIfNeed(), options: [.processor(DownsamplingImageProcessor(size: CGSize(width: 80, height: 80))), .processor(RoundCornerImageProcessor(radius: .widthFraction(0.5))), .cacheSerializer(FormatIndicatedCacheSerializer.png)])
        }
        dataSource = UICollectionViewDiffableDataSource<SearchList, AnyHashable>(collectionView: collectionView) {
            collectionView, indexPath, item in
            if let item = item as? any DisplayData {
                return collectionView.dequeueConfiguredReusableCell(using: displayCell, for: indexPath, item: item)
            } else if let item = item as? SearchResult.User {
                return collectionView.dequeueConfiguredReusableCell(using: userCell, for: indexPath, item: item)
            } else {
                fatalError("Unknown item type")
            }
        }

        let supplementaryRegistration = UICollectionView.SupplementaryRegistration<TitleSupplementaryView>(elementKind: FavoriteViewController.titleElementKind) {
            supplementaryView, string, indexPath in
            if let snapshot = self.currentSnapshot {
                let videoCategory = snapshot.sectionIdentifiers[indexPath.section]
                supplementaryView.label.text = videoCategory.title
            }
        }

        dataSource.supplementaryViewProvider = { view, kind, index in
            return self.collectionView.dequeueConfiguredReusableSupplementary(
                using: supplementaryRegistration, for: index
            )
        }

        currentSnapshot = NSDiffableDataSourceSnapshot<SearchList, AnyHashable>()
    }
}

extension SearchResultViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let data = dataSource.itemIdentifier(for: indexPath) else { return }
        switch data {
        case let data as SearchResult.Video:
            let detailVC = VideoDetailViewController.create(aid: data.aid, cid: 0)
            detailVC.present(from: self)
        case let data as SearchResult.Bangumi:
            let detailVC = VideoDetailViewController.create(seasonId: data.season_id)
            detailVC.present(from: self)
        case let data as SearchResult.User:
            let upSpaceVC = UpSpaceViewController()
            upSpaceVC.mid = data.mid
            present(upSpaceVC, animated: true)
        default:
            break
        }
    }

    func indexPathForPreferredFocusedView(in collectionView: UICollectionView) -> IndexPath? {
        if let section = currentSnapshot.sectionIdentifiers.first, currentSnapshot.numberOfItems(inSection: section) > 0 {
            return IndexPath(item: 0, section: 0)
        }
        return nil
    }
}

extension SearchResultViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        if let text = searchController.searchBar.text {
            searchText = text
        }
    }
}

extension WebRequest {
    static func requestSearchResult(key: String, complete: ((SearchResult) -> Void)?) {
        request(url: "https://api.bilibili.com/x/web-interface/search/all/v2", parameters: ["keyword": key]) {
            (result: Result<SearchResult, RequestError>) in
            if let details = try? result.get() {
                complete?(details)
            }
        }
    }
}

struct SearchResult: Decodable, Hashable {
    struct Video: Codable, Hashable, DisplayData {
        let author: String
        let upic: URL
        let aid: Int

        // DisplayData
        var title: String
        var ownerName: String { author }
        let pic: URL?
        var avatar: URL? { upic }
    }

    struct Bangumi: Codable, Hashable, DisplayData {
        let season_id: Int
        let styles: String
        let cover: URL
        let pubtime: Int

        // DisplayData
        var title: String
        var ownerName: String { styles }
        var pic: URL? { cover }
        var date: String? { DateFormatter.stringFor(timestamp: pubtime) }
    }

    struct User: Codable, Hashable {
        let uname: String
        let upic: URL
        let usign: String
        let mid: Int
    }

    enum DataType: String, Codable {
        case video
        case media_bangumi
        case media_ft
        case bili_user
    }

    enum Section: Decodable, Hashable {
        case video(_ video: [Video])
        case bangumi(_ bangumi: [Bangumi])
        case movie(_ movie: [Bangumi])
        case user(_ user: [User])
        case none

        enum CodingKeys: CodingKey {
            case result_type
            case data
        }

        init(from decoder: Decoder) throws {
            let container: KeyedDecodingContainer<SearchResult.Section.CodingKeys> = try decoder.container(keyedBy: SearchResult.Section.CodingKeys.self)
            let result_type = try? container.decode(DataType.self, forKey: .result_type)
            switch result_type {
            case .video:
                var video = try container.decode([Video].self, forKey: .data)
                video.indices.forEach({ video[$0].title = video[$0].title.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil) })
                video = Array(Set(video))
                self = .video(video)
            case .media_bangumi:
                var bangumi = try container.decode([Bangumi].self, forKey: .data)
                if bangumi.count == 0 {
                    self = .none
                    break
                }
                bangumi.indices.forEach({ bangumi[$0].title = bangumi[$0].title.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil) })
                bangumi = Array(Set(bangumi))
                self = .bangumi(bangumi)
            case .media_ft:
                var bangumi = try container.decode([Bangumi].self, forKey: .data)
                if bangumi.count == 0 {
                    self = .none
                    break
                }
                bangumi.indices.forEach({ bangumi[$0].title = bangumi[$0].title.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil) })
                bangumi = Array(Set(bangumi))
                self = .movie(bangumi)
            case .bili_user:
                var user = try container.decode([User].self, forKey: .data)
                if user.count == 0 {
                    self = .none
                    break
                }
                user = Array(Set(user))
                self = .user(user)
            case .none:
                self = .none
            }
        }
    }

    let result: [Section]
}

struct SearchList: Hashable {
    let title: String
    let width = NSCollectionLayoutDimension.fractionalWidth(Settings.displayStyle.fractionalWidth)
    let height: NSCollectionLayoutDimension
    let scrollingBehavior: UICollectionLayoutSectionOrthogonalScrollingBehavior
}
