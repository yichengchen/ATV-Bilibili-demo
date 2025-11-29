//
//  FollowBangumiViewController.swift
//  BilibiliLive
//
//  Created by bitxeno on 2025/11/29.
//

import SnapKit
import UIKit

class FollowBangumiViewController: SegmentViewController {
    override func viewDidLoad() {
        categories = [
            CategoryDisplayModel(title: "番剧", contentVC: BangumiListViewController(type: 1)),
            CategoryDisplayModel(title: "影视", contentVC: BangumiListViewController(type: 2)),
        ]
        super.viewDidLoad()
    }
}

class BangumiListViewController: StandardVideoCollectionViewController<FollowBangumiListData.Bangumi> {
    let type: Int
    init(type: Int) {
        self.type = type
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setupCollectionView() {
        super.setupCollectionView()
        collectionVC.styleOverride = .normal
        collectionVC.pageSize = 24
        collectionVC.loadViewIfNeeded()
        collectionVC.collectionView.contentInset = UIEdgeInsets(top: 40, left: 0, bottom: 40, right: 0)
    }

    override func request(page: Int) async throws -> [FollowBangumiListData.Bangumi] {
        let res = try await WebRequest.requestFollowBangumiList(type: type, page: page)
        return res?.list ?? []
    }

    override func goDetail(with record: FollowBangumiListData.Bangumi) {
        let detailVC = VideoDetailViewController.create(seasonId: record.season_id)
        detailVC.present(from: self)
    }
}

extension WebRequest.EndPoint {
    static let followBangumiList = "https://api.bilibili.com/x/space/bangumi/follow/list"
}

extension WebRequest {
    static func requestFollowBangumiList(type: Int, page: Int = 1) async throws -> FollowBangumiListData? {
        guard let mid = ApiRequest.getToken()?.mid else { return nil }
        return try await request(url: EndPoint.followBangumiList, parameters: ["vmid": mid, "type": type, "pn": page, "ps": "24"])
    }
}

struct FollowBangumiListData: Codable, Hashable {
    struct Bangumi: Codable, Hashable, DisplayData {
        let season_id: Int
        let media_id: Int
        let title: String
        let cover: URL
        let progress: String?
        let new_ep: NewEp?

        struct NewEp: Codable, Hashable {
            let index_show: String?
            let cover: URL?
            let pub_time: String?
        }

        // DisplayData
        var ownerName: String { return progress ?? "" }
        var pic: URL? { return new_ep?.cover ?? cover }
        var overlay: DisplayOverlay? {
            guard let index_show = new_ep?.index_show else { return nil }
            var leftItems = [DisplayOverlay.DisplayOverlayItem]()
            leftItems.append(DisplayOverlay.DisplayOverlayItem(icon: nil, text: index_show))
            var badge: DisplayOverlay.DisplayOverlayBadge?
            if let pub_time = new_ep?.pub_time {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                if let date = formatter.date(from: pub_time), Calendar.current.isDateInToday(date) {
                    badge = .init(text: "更新了!")
                }
            }
            return DisplayOverlay(leftItems: leftItems, badge: badge)
        }
    }

    let list: [Bangumi]
}

extension FollowBangumiListData.Bangumi: PlayableData {
    var aid: Int { 0 }
    var cid: Int { 0 }
}
