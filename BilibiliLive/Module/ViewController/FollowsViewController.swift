//
//  FollowsViewController.swift
//  BilibiliLive
//
//  Created by Etan Chen on 2021/4/4.
//

import Alamofire
import SnapKit
import SwiftyJSON
import UIKit

final class FollowsViewController: UIViewController, BLTabBarContentVCProtocol {
    private enum LayoutMode {
        case feedFlow
        case grid
    }

    private var currentMode: LayoutMode?
    private var currentContentViewController: UIViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleLayoutModeDidChange),
                                               name: .followsLayoutModeDidChange,
                                               object: nil)
        syncLayoutIfNeeded(force: true)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        syncLayoutIfNeeded(force: false)
    }

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        currentContentViewController?.preferredFocusEnvironments ?? [view]
    }

    func reloadData() {
        if let content = currentContentViewController as? BLTabBarContentVCProtocol {
            content.reloadData()
        } else {
            syncLayoutIfNeeded(force: true)
        }
    }

    @objc private func handleLayoutModeDidChange() {
        guard isViewLoaded else { return }
        syncLayoutIfNeeded(force: true)
    }

    private func syncLayoutIfNeeded(force: Bool) {
        let targetMode: LayoutMode = Settings.followsFeedFlowEnabled ? .feedFlow : .grid
        guard force || currentMode != targetMode else { return }

        let targetViewController: UIViewController
        switch targetMode {
        case .feedFlow:
            targetViewController = FollowsFeedFlowViewController()
        case .grid:
            targetViewController = FollowsGridViewController()
        }

        transition(to: targetViewController)
        currentMode = targetMode
    }

    private func transition(to targetViewController: UIViewController) {
        let previousViewController = currentContentViewController
        addChild(targetViewController)
        view.addSubview(targetViewController.view)
        targetViewController.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        targetViewController.didMove(toParent: self)
        currentContentViewController = targetViewController

        guard let previousViewController else { return }
        previousViewController.willMove(toParent: nil)
        previousViewController.view.removeFromSuperview()
        previousViewController.removeFromParent()
    }
}

final class FollowsGridViewController: StandardVideoCollectionViewController<DynamicFeedData> {
    var lastOffset = ""

    override func setupCollectionView() {
        super.setupCollectionView()
        collectionVC.pageSize = 1
    }

    override func request(page: Int) async throws -> [DynamicFeedData] {
        if page == 1 {
            lastOffset = ""
        }
        let info = try await WebRequest.requestFollowsFeed(offset: lastOffset, page: page)
        lastOffset = info.offset
        Logger.debug("request page\(page) get count:\(info.videoFeeds.count) next offset:\(info.offset)")
        return info.videoFeeds
    }

    override func goDetail(with feed: DynamicFeedData) {
        let epid = feed.modules.module_dynamic.major?.pgc?.epid
        let detailVC = VideoDetailViewController.create(aid: feed.aid, cid: feed.cid, epid: epid)
        detailVC.present(from: self)
    }
}

final class FollowsFeedFlowViewController: FeedFlowBrowserViewController {
    init() {
        super.init(dataSource: FollowsFeedFlowDataSource())
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class FollowsFeedFlowDataSource: FeedFlowDataSource {
    let title = "关注"
    let defaultPreviewHintText = "停留后自动预览，按确认键进入视频流"
    let loadingHintText = "正在加载关注视频..."
    let emptyStateText = "当前关注区暂无可播放视频"
    let emptyHintText = "可以在设置中关闭关注刷视频模式"
    let loadFailureText = "关注加载失败，请稍后重试"
    let refreshFailureHintText = "已展示现有关注内容，后台刷新失败"

    var reloadToken: String {
        "\(ApiRequest.getToken()?.mid ?? 0)"
    }

    private var lastOffset = ""
    private var nextPage = 1
    private var hasMore = true
    private var items = [FeedFlowItem]()
    private var seenItemKeys = Set<String>()

    func reset() {
        lastOffset = ""
        nextPage = 1
        hasMore = true
        items = []
        seenItemKeys = []
    }

    func refreshFromStart(targetCount: Int, maxSourcePages: Int) async throws -> [FeedFlowItem] {
        let loadedItems = try await loadMoreUntilTarget(targetCount: targetCount, maxSourcePages: maxSourcePages)
        items = loadedItems
        return loadedItems
    }

    func loadMoreItems(targetCount: Int, maxSourcePages: Int) async throws -> [FeedFlowItem] {
        let appended = try await loadMoreUntilTarget(targetCount: targetCount, maxSourcePages: maxSourcePages)
        items.append(contentsOf: appended)
        return appended
    }

    private func loadMoreUntilTarget(targetCount: Int, maxSourcePages: Int) async throws -> [FeedFlowItem] {
        guard hasMore else { return [] }

        var pagesScanned = 0
        var accepted = [FeedFlowItem]()

        while accepted.count < targetCount, pagesScanned < maxSourcePages, hasMore {
            let info = try await WebRequest.requestFollowsFeed(offset: lastOffset, page: nextPage)
            pagesScanned += 1
            nextPage += 1
            lastOffset = info.offset
            hasMore = info.has_more

            let newItems = info.videoFeeds
                .compactMap(\.feedFlowItem)
                .filter { seenItemKeys.insert($0.identityKey).inserted }
            accepted.append(contentsOf: newItems)
        }

        return accepted
    }
}

extension WebRequest {
    struct DynamicFeedInfo: Codable {
        let items: [DynamicFeedData]
        let offset: String
        let update_num: Int
        let update_baseline: String
        let has_more: Bool

        var videoFeeds: [DynamicFeedData] {
            items.filter { $0.aid != 0 || $0.modules.module_dynamic.major?.pgc?.epid != nil }
        }

        enum CodingKeys: String, CodingKey {
            case items, offset, update_num, update_baseline, has_more
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            items = try container.decode([DynamicFeedData].self, forKey: .items)
            offset = try container.decode(String.self, forKey: .offset)
            if let intVal = try? container.decode(Int.self, forKey: .update_num) {
                update_num = intVal
            } else if let strVal = try? container.decode(String.self, forKey: .update_num) {
                update_num = Int(strVal) ?? 0
            } else {
                update_num = 0
            }
            update_baseline = try container.decode(String.self, forKey: .update_baseline)
            has_more = try container.decode(Bool.self, forKey: .has_more)
        }
    }

    static func requestFollowsFeed(offset: String, page: Int) async throws -> DynamicFeedInfo {
        var param: [String: Any] = ["type": "all", "timezone_offset": "-480", "page": page]
        if let offsetNum = Int(offset) {
            param["offset"] = offsetNum
        }
        let res: DynamicFeedInfo = try await request(url: "https://api.bilibili.com/x/polymer/web-dynamic/v1/feed/all",
                                                     parameters: param)
        if res.videoFeeds.isEmpty, res.has_more {
            return try await requestFollowsFeed(offset: res.offset, page: page)
        }
        return res
    }
}

struct DynamicFeedData: Codable, PlayableData, DisplayData {
    var aid: Int {
        if let str = modules.module_dynamic.major?.archive?.aid {
            return Int(str) ?? 0
        }
        return 0
    }

    var cid: Int { 0 }

    var title: String {
        modules.module_dynamic.major?.archive?.title ?? modules.module_dynamic.major?.pgc?.title ?? ""
    }

    var ownerName: String {
        modules.module_author.name
    }

    var pic: URL? {
        URL(string: modules.module_dynamic.major?.archive?.cover ?? "") ?? modules.module_dynamic.major?.pgc?.cover
    }

    var avatar: URL? {
        URL(string: modules.module_author.face)
    }

    var date: String? {
        modules.module_author.pub_time
    }

    var overlay: DisplayOverlay? {
        var leftItems = [DisplayOverlay.DisplayOverlayItem]()
        var rightItems = [DisplayOverlay.DisplayOverlayItem]()
        if let stat = modules.module_dynamic.major?.archive?.stat {
            if let play = stat.play {
                leftItems.append(DisplayOverlay.DisplayOverlayItem(icon: "play.rectangle", text: play == "0" ? "-" : "\(play)"))
            }
            if let danmaku = stat.danmaku {
                leftItems.append(DisplayOverlay.DisplayOverlayItem(icon: "list.bullet.rectangle", text: danmaku == "0" ? "-" : "\(danmaku)"))
            }
        }
        if let durationText = modules.module_dynamic.major?.archive?.duration_text {
            rightItems.append(DisplayOverlay.DisplayOverlayItem(icon: nil, text: durationText))
        }
        return DisplayOverlay(leftItems: leftItems, rightItems: rightItems)
    }

    var feedFlowItem: FeedFlowItem? {
        if aid > 0 {
            return FeedFlowItem(aid: aid,
                                title: title,
                                ownerName: ownerName,
                                coverURL: pic,
                                avatarURL: avatar,
                                duration: modules.module_dynamic.major?.archive?.duration_text?.durationInSeconds,
                                durationText: modules.module_dynamic.major?.archive?.duration_text ?? "",
                                viewCountText: modules.module_dynamic.major?.archive?.stat?.play ?? "",
                                danmakuCountText: modules.module_dynamic.major?.archive?.stat?.danmaku ?? "",
                                reasonText: date)
        }

        if let epid = modules.module_dynamic.major?.pgc?.epid, epid > 0 {
            return FeedFlowItem(aid: 0,
                                epid: epid,
                                title: title,
                                ownerName: ownerName,
                                coverURL: pic,
                                avatarURL: avatar,
                                durationText: "",
                                reasonText: date)
        }

        return nil
    }

    let type: String
    let basic: Basic
    let modules: Modules
    let id_str: String

    struct Basic: Codable, Hashable {
        let comment_id_str: String
        let comment_type: Int
    }

    struct Modules: Codable, Hashable {
        let module_author: ModuleAuthor
        let module_dynamic: ModuleDynamic

        struct ModuleAuthor: Codable, Hashable {
            let face: String
            let mid: Int
            let name: String
            let pub_time: String
        }

        struct ModuleDynamic: Codable, Hashable {
            let major: Major?

            struct Major: Codable, Hashable {
                let archive: Archive?
                let pgc: Pgc?

                struct Archive: Codable, Hashable {
                    let aid: String?
                    let cover: String?
                    let desc: String?
                    let title: String?
                    let duration_text: String?
                    let stat: Stat?

                    struct Stat: Codable, Hashable {
                        let danmaku: String?
                        let play: String?
                    }
                }

                struct Pgc: Codable, Hashable {
                    let epid: Int?
                    let title: String?
                    let cover: URL?
                    let jump_url: URL?

                    enum CodingKeys: String, CodingKey {
                        case epid, title, cover, jump_url
                    }

                    init(from decoder: Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        if let intVal = try? container.decodeIfPresent(Int.self, forKey: .epid) {
                            epid = intVal
                        } else if let strVal = try? container.decodeIfPresent(String.self, forKey: .epid) {
                            epid = Int(strVal)
                        } else {
                            epid = nil
                        }
                        title = try container.decodeIfPresent(String.self, forKey: .title)
                        cover = try container.decodeIfPresent(URL.self, forKey: .cover)
                        jump_url = try container.decodeIfPresent(URL.self, forKey: .jump_url)
                    }
                }
            }
        }
    }
}

private extension String {
    var durationInSeconds: Int? {
        let parts = split(separator: ":").compactMap { Int($0) }
        guard !parts.isEmpty else { return nil }
        var total = 0
        for (index, value) in parts.reversed().enumerated() {
            switch index {
            case 0:
                total += value
            case 1:
                total += value * 60
            default:
                total += value * 3600
            }
        }
        return total
    }
}
