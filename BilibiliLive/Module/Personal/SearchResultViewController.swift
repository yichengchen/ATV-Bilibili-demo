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
    var dataSource: UICollectionViewDiffableDataSource<SearchList, Item>!
    var currentSnapshot: NSDiffableDataSourceSnapshot<SearchList, Item>!
    static let titleElementKind = "titleElementKind"

    // MARK: - Search State

    enum SearchState {
        case empty // 显示热搜 + 历史
        case loading // 加载中
        case results // 显示搜索结果
    }

    enum Item: Hashable {
        case video(SearchResult.Video)
        case paginatedVideo(PaginatedVideoResult.VideoItem) // 分页加载的视频
        case bangumi(SearchResult.Bangumi)
        case user(SearchResult.User)
        case liveRoom(SearchLiveResult.Result.LiveRoom)
        // 新增
        case hotKeyword(HotSearchResult.HotWord)
        case historyKeyword(String)
        case clearHistory
        case loadMore(String) // section type identifier
    }

    @Published var searchText: String = ""
    @Published private var searchState: SearchState = .empty
    var cancellable = Set<AnyCancellable>()
    private let suggestDelayWork = DelayWork(delay: 1.0)
    private var showHistorySuggest = false

    // 分页状态
    private var videoPagination = SearchPaginationState()
    private var livePagination = SearchPaginationState()
    private var currentKeyword: String = ""

    // 热搜数据
    private var hotKeywords: [HotSearchResult.HotWord] = []

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

        // 监听搜索文本变化
        $searchText
            .debounce(for: 0.8, scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] key in
                guard let self else { return }
                if key.isEmpty {
                    searchState = .empty
                } else {
                    Task { @MainActor in
                        await self.performSearch(key: key)
                    }
                }
            }
            .store(in: &cancellable)

        // 监听状态变化更新UI
        $searchState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                Task { @MainActor in
                    await self.updateUIForState(state)
                }
            }
            .store(in: &cancellable)

        // 初始加载热搜
        Task {
            await loadHotSearch()
        }
    }

    // MARK: - Hot Search

    @MainActor
    private func loadHotSearch() async {
        hotKeywords = await Settings.getHotKeywords()
        if searchState == .empty {
            await updateUIForState(.empty)
        }
    }

    @MainActor
    private func updateUIForState(_ state: SearchState) async {
        switch state {
        case .empty:
            showEmptyState()
        case .loading:
            // 可以显示加载指示器
            break
        case .results:
            // 结果已在performSearch中更新
            break
        }
    }

    @MainActor
    private func showEmptyState() {
        currentSnapshot.deleteAllItems()

        // 热搜区
        if !hotKeywords.isEmpty {
            let hotList = SearchList(
                title: "热门搜索",
                sectionType: .hotSearch,
                height: .absolute(70),
                scrollingBehavior: .continuous
            )
            currentSnapshot.appendSections([hotList])
            currentSnapshot.appendItems(hotKeywords.map { .hotKeyword($0) }, toSection: hotList)
        }

        // 历史区
        let histories = Settings.searchHistories
        if !histories.isEmpty {
            let historyList = SearchList(
                title: "历史搜索",
                sectionType: .history,
                height: .absolute(70),
                scrollingBehavior: .continuous
            )
            currentSnapshot.appendSections([historyList])
            var items: [Item] = histories.map { .historyKeyword($0) }
            items.append(.clearHistory)
            currentSnapshot.appendItems(items, toSection: historyList)
        }

        dataSource.apply(currentSnapshot)
    }

    @MainActor
    private func performSearch(key: String) async {
        // 重置分页状态
        currentKeyword = key
        videoPagination.reset()
        livePagination.reset()
        searchState = .loading

        // 使用 async let 并行请求
        async let searchResultTask = WebRequest.requestSearchResult(key: key)
        async let liveResultTask = WebRequest.requestSearchLiveResult(key: key)

        let searchResult = try? await searchResultTask
        let liveResult = try? await liveResultTask

        searchState = .results
        updateSnapshot(searchResult: searchResult, liveResult: liveResult)
    }

    @MainActor
    private func updateSnapshot(searchResult: SearchResult?, liveResult: SearchLiveResult?) {
        currentSnapshot.deleteAllItems()
        dataSource.apply(currentSnapshot)

        let defaultHeight = NSCollectionLayoutDimension.fractionalWidth(Settings.displayStyle == .large ? 0.26 : 0.2)

        // 添加综合搜索结果
        if let searchResult {
            for section in searchResult.result {
                switch section {
                case let .video(data):
                    let list = SearchList(title: "视频", sectionType: .video, height: defaultHeight, scrollingBehavior: .continuous)
                    currentSnapshot.appendSections([list])
                    var items: [Item] = data.map { .video($0) }
                    // 视频支持分页
                    if data.count >= 20 {
                        videoPagination.hasMore = true
                        items.append(.loadMore("video"))
                    }
                    currentSnapshot.appendItems(items, toSection: list)
                case let .bangumi(data):
                    let list = SearchList(title: "番剧", sectionType: .bangumi, height: defaultHeight, scrollingBehavior: .continuous)
                    currentSnapshot.appendSections([list])
                    currentSnapshot.appendItems(data.map { .bangumi($0) }, toSection: list)
                case let .movie(data):
                    let list = SearchList(title: "影视", sectionType: .movie, height: defaultHeight, scrollingBehavior: .none)
                    currentSnapshot.appendSections([list])
                    currentSnapshot.appendItems(data.map { .bangumi($0) }, toSection: list)
                case let .user(data):
                    let list = SearchList(title: "用户", sectionType: .user, height: .estimated(140), scrollingBehavior: .continuous)
                    currentSnapshot.appendSections([list])
                    currentSnapshot.appendItems(data.map { .user($0) }, toSection: list)
                case .none:
                    break
                }
            }
        }

        // 添加直播搜索结果
        if let liveResult, let liveRooms = liveResult.result.live_room, !liveRooms.isEmpty {
            let list = SearchList(title: "直播", sectionType: .live, height: defaultHeight, scrollingBehavior: .continuous)
            currentSnapshot.appendSections([list])
            var items: [Item] = liveRooms.map { .liveRoom($0) }
            // 直播支持分页
            if liveRooms.count >= 20 {
                livePagination.hasMore = true
                items.append(.loadMore("live"))
            }
            currentSnapshot.appendItems(items, toSection: list)
        }

        dataSource.apply(currentSnapshot)
    }

    // MARK: - Pagination

    @MainActor
    private func loadMoreVideos() async {
        guard !videoPagination.isLoading, videoPagination.hasMore else { return }

        videoPagination.isLoading = true
        videoPagination.loadNextPage()

        do {
            let result = try await WebRequest.requestMoreVideos(
                key: currentKeyword,
                page: videoPagination.currentPage
            )

            guard let videos = result.result, !videos.isEmpty else {
                videoPagination.hasMore = false
                videoPagination.isLoading = false
                removeLoadMoreCell(for: "video")
                return
            }

            appendPaginatedVideos(videos, hasMore: result.hasMore)
        } catch {
            Logger.warn("Load more videos failed: \(error)")
        }

        videoPagination.isLoading = false
    }

    @MainActor
    private func loadMoreLiveRooms() async {
        guard !livePagination.isLoading, livePagination.hasMore else { return }

        livePagination.isLoading = true
        livePagination.loadNextPage()

        do {
            let result = try await WebRequest.requestMoreLiveRooms(
                key: currentKeyword,
                page: livePagination.currentPage
            )

            guard let rooms = result.result.live_room, !rooms.isEmpty else {
                livePagination.hasMore = false
                livePagination.isLoading = false
                removeLoadMoreCell(for: "live")
                return
            }

            // 检查是否还有更多 (基于返回数量)
            let hasMore = rooms.count >= 20
            appendLiveRooms(rooms, hasMore: hasMore)
        } catch {
            Logger.warn("Load more live rooms failed: \(error)")
        }

        livePagination.isLoading = false
    }

    @MainActor
    private func appendVideos(_ videos: [SearchResult.Video], hasMore: Bool) {
        guard let section = currentSnapshot.sectionIdentifiers.first(where: { $0.sectionType == .video }) else { return }

        // 移除旧的loadMore
        currentSnapshot.deleteItems([.loadMore("video")])

        // 添加新视频
        currentSnapshot.appendItems(videos.map { .video($0) }, toSection: section)

        // 如果还有更多，添加loadMore
        videoPagination.hasMore = hasMore
        if hasMore {
            currentSnapshot.appendItems([.loadMore("video")], toSection: section)
        }

        dataSource.apply(currentSnapshot)
    }

    @MainActor
    private func appendPaginatedVideos(_ videos: [PaginatedVideoResult.VideoItem], hasMore: Bool) {
        guard let section = currentSnapshot.sectionIdentifiers.first(where: { $0.sectionType == .video }) else { return }

        // 移除旧的loadMore
        currentSnapshot.deleteItems([.loadMore("video")])

        // 添加新视频 (使用paginatedVideo case)
        currentSnapshot.appendItems(videos.map { .paginatedVideo($0) }, toSection: section)

        // 如果还有更多，添加loadMore
        videoPagination.hasMore = hasMore
        if hasMore {
            currentSnapshot.appendItems([.loadMore("video")], toSection: section)
        }

        dataSource.apply(currentSnapshot)
    }

    @MainActor
    private func appendLiveRooms(_ rooms: [SearchLiveResult.Result.LiveRoom], hasMore: Bool) {
        guard let section = currentSnapshot.sectionIdentifiers.first(where: { $0.sectionType == .live }) else { return }

        // 移除旧的loadMore
        currentSnapshot.deleteItems([.loadMore("live")])

        // 添加新直播
        currentSnapshot.appendItems(rooms.map { .liveRoom($0) }, toSection: section)

        // 如果还有更多，添加loadMore
        livePagination.hasMore = hasMore
        if hasMore {
            currentSnapshot.appendItems([.loadMore("live")], toSection: section)
        }

        dataSource.apply(currentSnapshot)
    }

    @MainActor
    private func removeLoadMoreCell(for type: String) {
        currentSnapshot.deleteItems([.loadMore(type)])
        dataSource.apply(currentSnapshot)
    }
}

extension SearchResultViewController {
    private func createLayout() -> UICollectionViewLayout {
        let sectionProvider = { [self]
            (sectionIndex: Int, layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection? in
                let sectionIdentifier = dataSource.snapshot().sectionIdentifiers[sectionIndex]

                let section: NSCollectionLayoutSection

                // 热搜和历史使用特殊布局
                if sectionIdentifier.sectionType == .hotSearch || sectionIdentifier.sectionType == .history {
                    let itemSize = NSCollectionLayoutSize(
                        widthDimension: .estimated(180),
                        heightDimension: .absolute(60)
                    )
                    let item = NSCollectionLayoutItem(layoutSize: itemSize)
                    item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10)

                    let groupSize = NSCollectionLayoutSize(
                        widthDimension: .estimated(180),
                        heightDimension: .absolute(60)
                    )
                    let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

                    section = NSCollectionLayoutSection(group: group)
                    section.orthogonalScrollingBehavior = .continuous
                    section.contentInsets = NSDirectionalEdgeInsets(top: 20, leading: 40, bottom: 20, trailing: 40)
                } else if sectionIdentifier.scrollingBehavior == .none {
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
        let displayCell = UICollectionView.CellRegistration<FeedCollectionViewCell, any DisplayData> {
            $0.setup(data: $2)
        }
        let userCell = UICollectionView.CellRegistration<UpCell, SearchResult.User> {
            $0.nameLabel.text = $2.uname
            $0.despLabel.text = $2.usign
            $0.imageView.kf.setImage(with: $2.upic.addSchemeIfNeed(), options: [.processor(DownsamplingImageProcessor(size: CGSize(width: 80, height: 80))), .processor(RoundCornerImageProcessor(radius: .widthFraction(0.5))), .cacheSerializer(FormatIndicatedCacheSerializer.png)])
        }

        // 热搜关键词Cell
        let hotKeywordCell = UICollectionView.CellRegistration<HotSearchCell, HotSearchResult.HotWord> {
            $0.configure(with: $2)
        }

        // 历史关键词Cell
        let historyKeywordCell = UICollectionView.CellRegistration<HotSearchCell, String> {
            $0.configureAsHistory($2)
        }

        // 清空历史Cell
        let clearHistoryCell = UICollectionView.CellRegistration<HotSearchCell, Void> { cell, _, _ in
            cell.configureAsClearHistory()
        }

        // 加载更多Cell
        let loadMoreCell = UICollectionView.CellRegistration<LoadMoreCell, String> { cell, _, _ in
            cell.isLoading = false
        }

        dataSource = UICollectionViewDiffableDataSource<SearchList, Item>(collectionView: collectionView) {
            collectionView, indexPath, item in
            switch item {
            case let .video(item):
                return collectionView.dequeueConfiguredReusableCell(using: displayCell, for: indexPath, item: item)
            case let .paginatedVideo(item):
                return collectionView.dequeueConfiguredReusableCell(using: displayCell, for: indexPath, item: item)
            case let .bangumi(item):
                return collectionView.dequeueConfiguredReusableCell(using: displayCell, for: indexPath, item: item)
            case let .user(item):
                return collectionView.dequeueConfiguredReusableCell(using: userCell, for: indexPath, item: item)
            case let .liveRoom(item):
                return collectionView.dequeueConfiguredReusableCell(using: displayCell, for: indexPath, item: item)
            case let .hotKeyword(item):
                return collectionView.dequeueConfiguredReusableCell(using: hotKeywordCell, for: indexPath, item: item)
            case let .historyKeyword(item):
                return collectionView.dequeueConfiguredReusableCell(using: historyKeywordCell, for: indexPath, item: item)
            case .clearHistory:
                return collectionView.dequeueConfiguredReusableCell(using: clearHistoryCell, for: indexPath, item: ())
            case let .loadMore(type):
                return collectionView.dequeueConfiguredReusableCell(using: loadMoreCell, for: indexPath, item: type)
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

        currentSnapshot = NSDiffableDataSourceSnapshot<SearchList, Item>()
    }
}

extension SearchResultViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let data = dataSource.itemIdentifier(for: indexPath) else { return }
        switch data {
        case let .video(data):
            let detailVC = VideoDetailViewController.create(aid: data.aid, cid: 0)
            detailVC.present(from: self)

        case let .paginatedVideo(data):
            let detailVC = VideoDetailViewController.create(aid: data.aid, cid: 0)
            detailVC.present(from: self)

        case let .bangumi(data):
            let detailVC = VideoDetailViewController.create(seasonId: data.season_id)
            detailVC.present(from: self)

        case let .user(data):
            let upSpaceVC = UpSpaceViewController.create(mid: data.mid)
            present(upSpaceVC, animated: true)

        case let .liveRoom(data):
            let playerVC = LivePlayerViewController()
            let room = LiveRoom(
                title: data.title,
                room_id: data.roomid,
                uname: data.uname,
                area_v2_name: data.cate_name,
                keyframe: data.cover?.absoluteString,
                face: data.uface,
                cover_from_user: data.user_cover
            )
            playerVC.room = room
            present(playerVC, animated: true)

        // 新增: 热搜关键词
        case let .hotKeyword(hotWord):
            triggerSearch(keyword: hotWord.keyword)

        // 新增: 历史关键词
        case let .historyKeyword(keyword):
            triggerSearch(keyword: keyword)

        // 新增: 清空历史
        case .clearHistory:
            Settings.clearHistory()
            searchState = .empty

        // 新增: 加载更多
        case let .loadMore(type):
            Task {
                if type == "video" {
                    await loadMoreVideos()
                } else if type == "live" {
                    await loadMoreLiveRooms()
                }
            }
        }
    }

    /// 触发搜索 (用于热搜和历史关键词点击)
    private func triggerSearch(keyword: String) {
        // 保存历史并触发搜索
        Settings.addHistory(keyword)
        searchText = keyword
    }

    func indexPathForPreferredFocusedView(in collectionView: UICollectionView) -> IndexPath? {
        if let section = currentSnapshot.sectionIdentifiers.first, currentSnapshot.numberOfItems(inSection: section) > 0 {
            return IndexPath(item: 0, section: 0)
        }
        return nil
    }

    func collectionView(_ collectionView: UICollectionView, didUpdateFocusIn context: UICollectionViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        // 从搜索框进入结果查看时，认为本搜索词是用户想要的，保存搜索历史
        if context.previouslyFocusedIndexPath == nil && context.nextFocusedIndexPath != nil {
            Settings.addHistory(searchText)
        }
    }
}

extension SearchResultViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        guard searchController.searchBar.text != "清空历史" else { return }
        if let text = searchController.searchBar.text {
            searchText = text
        }

        if let text = searchController.searchBar.text, !text.isEmpty {
            showHistorySuggest = false
            suggestDelayWork.submit {
                let result = try await WebRequest.requestSuggest(key: text)
                searchController.searchSuggestions = result.result.tag.map {
                    SuggestEntry(title: $0.term, iconImage: UIImage(systemName: "magnifyingglass"))
                }
            }
        } else {
            suggestDelayWork.cancel()
            // 添加showHistorySuggest判断避免可能重复执行
            if !showHistorySuggest {
                showHistorySuggest = true
                // 清空搜索词后显示历史搜索词
                var suggests = Settings.searchHistories.map {
                    SuggestEntry(title: $0, iconImage: UIImage(systemName: "clock"))
                }
                if !suggests.isEmpty {
                    suggests.append(SuggestEntry(title: "清空历史", iconImage: UIImage(systemName: "trash")))
                }
                searchController.searchSuggestions = suggests
            }
        }
    }

    func updateSearchResults(for searchController: UISearchController, selecting searchSuggestion: any UISearchSuggestion) {
        // 选中建议词后添加搜索历史
        if searchSuggestion.localizedDescription == "清空历史" {
            Settings.clearHistory()
            searchController.searchSuggestions = []
            searchController.searchBar.text = nil
        } else if let text = searchController.searchBar.text {
            Settings.addHistory(text)
        }
    }
}

extension WebRequest {
    static func requestSearchResult(key: String) async throws -> SearchResult {
        try await request(url: "https://api.bilibili.com/x/web-interface/search/all/v2", parameters: ["keyword": key])
    }

    static func requestSearchLiveResult(key: String) async throws -> SearchLiveResult {
        try await request(url: "https://api.bilibili.com/x/web-interface/wbi/search/type", parameters: ["keyword": key, "search_type": "live"])
    }

    static func requestSuggest(key: String) async throws -> SuggestResult {
        try await request(url: "https://api.bilibili.com/x/web-interface/suggest", parameters: ["term": key])
    }
}

struct SearchResult: Decodable, Hashable {
    struct Video: Codable, Hashable, DisplayData {
        let type: String
        let author: String
        let upic: String
        let aid: Int
        let pubdate: Int
        let danmaku: Int
        let play: Int?
        let duration: String?

        // DisplayData
        var title: String
        var ownerName: String { author }
        let pic: URL?
        var avatar: URL? { URL(string: upic) }
        var date: String? { DateFormatter.stringFor(timestamp: pubdate) }
        var overlay: DisplayOverlay? {
            var leftItems = [DisplayOverlay.DisplayOverlayItem]()
            var rightItems = [DisplayOverlay.DisplayOverlayItem]()
            leftItems.append(DisplayOverlay.DisplayOverlayItem(icon: "play.rectangle", text: play == 0 ? "-" : play?.numberString() ?? "-"))
            leftItems.append(DisplayOverlay.DisplayOverlayItem(icon: "list.bullet.rectangle", text: danmaku == 0 ? "-" : danmaku.numberString()))
            if let duration {
                rightItems.append(DisplayOverlay.DisplayOverlayItem(icon: nil, text: duration))
            }
            return DisplayOverlay(leftItems: leftItems, rightItems: rightItems)
        }
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
                video.indices.forEach({ video[$0].title = video[$0].title.removingHTMLTags() })
                // 过滤只保留视频类型，去掉直播和课堂等类型
                video = video.filter { $0.type == "video" }
                video = Array(Set(video))
                self = .video(video)
            case .media_bangumi:
                var bangumi = try container.decode([Bangumi].self, forKey: .data)
                if bangumi.count == 0 {
                    self = .none
                    break
                }
                bangumi.indices.forEach({ bangumi[$0].title = bangumi[$0].title.removingHTMLTags() })
                bangumi = Array(Set(bangumi))
                self = .bangumi(bangumi)
            case .media_ft:
                var bangumi = try container.decode([Bangumi].self, forKey: .data)
                if bangumi.count == 0 {
                    self = .none
                    break
                }
                bangumi.indices.forEach({ bangumi[$0].title = bangumi[$0].title.removingHTMLTags() })
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
    enum SectionType: Hashable {
        case hotSearch
        case history
        case video
        case bangumi
        case movie
        case user
        case live
    }

    let title: String
    let sectionType: SectionType
    let width: NSCollectionLayoutDimension
    let height: NSCollectionLayoutDimension
    let scrollingBehavior: UICollectionLayoutSectionOrthogonalScrollingBehavior

    init(title: String, sectionType: SectionType = .video, height: NSCollectionLayoutDimension, scrollingBehavior: UICollectionLayoutSectionOrthogonalScrollingBehavior) {
        self.title = title
        self.sectionType = sectionType
        width = NSCollectionLayoutDimension.fractionalWidth(Settings.displayStyle.fractionalWidth)
        self.height = height
        self.scrollingBehavior = scrollingBehavior
    }
}

struct SearchLiveResult: Decodable, Hashable {
    struct Result: Codable, Hashable {
        let live_room: [LiveRoom]?

        struct LiveRoom: Codable, Hashable, DisplayData {
            let uname: String
            let uface: URL?
            let user_cover: URL?
            let cover: URL?
            let roomid: Int
            let cate_name: String
            let titleWithHtml: String

            // DisplayData
            var title: String { titleWithHtml.removingHTMLTags() }
            var ownerName: String { uname.removingHTMLTags() }
            var pic: URL? { cover?.addSchemeIfNeed() }
            var avatar: URL? { uface?.addSchemeIfNeed() }
            var overlay: DisplayOverlay? {
                var leftItems = [DisplayOverlay.DisplayOverlayItem]()
                leftItems.append(DisplayOverlay.DisplayOverlayItem(icon: nil, text: cate_name))
                return DisplayOverlay(leftItems: leftItems)
            }

            enum CodingKeys: String, CodingKey {
                case uname, uface, user_cover, cover, roomid, cate_name
                case titleWithHtml = "title"
            }
        }
    }

    let result: Result
}

struct SuggestResult: Decodable, Hashable {
    struct Result: Codable, Hashable {
        let tag: [Tag]

        struct Tag: Codable, Hashable {
            let term: String
        }
    }

    let result: Result
}

class SuggestEntry: NSObject, UISearchSuggestion {
    var localizedSuggestion: String? {
        return title
    }

    var localizedDescription: String? {
        return title
    }

    var representedObject: Any?

    var title: String
    var iconImage: UIImage? = nil

    init(title: String, iconImage: UIImage? = nil) {
        self.title = title
        self.iconImage = iconImage
    }
}
