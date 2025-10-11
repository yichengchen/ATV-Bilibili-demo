//
//  RankingViewController.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/10/29.
//

import Foundation
import UIKit

struct RankCategoryInfo {
    let title: String
    let rid: Int
    var isSeason = false

    static let all = [RankCategoryInfo(title: "全站", rid: 0),
                      RankCategoryInfo(title: "动画", rid: 1005),
                      RankCategoryInfo(title: "番剧", rid: 1, isSeason: true),
                      RankCategoryInfo(title: "国创", rid: 4, isSeason: true),
                      RankCategoryInfo(title: "音乐", rid: 1003),
                      RankCategoryInfo(title: "舞蹈", rid: 1004),
                      RankCategoryInfo(title: "游戏", rid: 1008),
                      RankCategoryInfo(title: "知识", rid: 1010),
                      RankCategoryInfo(title: "科技", rid: 1012),
                      RankCategoryInfo(title: "运动", rid: 1018),
                      RankCategoryInfo(title: "汽车", rid: 1013),
                      RankCategoryInfo(title: "生活", rid: 160),
                      RankCategoryInfo(title: "美食", rid: 1020),
                      RankCategoryInfo(title: "动物", rid: 1024),
                      RankCategoryInfo(title: "鬼畜", rid: 1007),
                      RankCategoryInfo(title: "时尚", rid: 1014),
                      RankCategoryInfo(title: "娱乐", rid: 1002),
                      RankCategoryInfo(title: "影视", rid: 1001)]
}

class RankingViewController: CategoryViewController {
    override func viewDidLoad() {
        categories = RankCategoryInfo.all
            .map {
                if $0.isSeason {
                    return CategoryDisplayModel(title: $0.title, contentVC: RankingSeasonContentViewController(info: $0))
                } else {
                    return CategoryDisplayModel(title: $0.title, contentVC: RankingVideoContentViewController(info: $0))
                }
            }
        super.viewDidLoad()
        if let vc = currentViewController as? StandardVideoCollectionViewController<VideoDetail.Info> {
            vc.collectionVC.collectionView.contentInset = UIEdgeInsets(top: 160, left: 0, bottom: 0, right: 0)
        }
    }
}

class RankingVideoContentViewController: StandardVideoCollectionViewController<VideoDetail.Info> {
    let info: RankCategoryInfo

    init(info: RankCategoryInfo) {
        self.info = info
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setupCollectionView() {
        collectionVC.styleOverride = .sideBar
        super.setupCollectionView()
    }

    override func supportPullToLoad() -> Bool {
        return false
    }

    override func request(page: Int) async throws -> [VideoDetail.Info] {
        return try await WebRequest.requestRank(for: info.rid)
    }
}

class RankingSeasonContentViewController: StandardVideoCollectionViewController<Season> {
    let info: RankCategoryInfo
    init(info: RankCategoryInfo) {
        self.info = info
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setupCollectionView() {
        collectionVC.styleOverride = .sideBar
        super.setupCollectionView()
    }

    override func supportPullToLoad() -> Bool {
        return false
    }

    override func request(page: Int) async throws -> [Season] {
        return try await WebRequest.requestSeasonRank(for: info.rid)
    }

    override func goDetail(with record: Season) {
        let detailVC = VideoDetailViewController.create(seasonId: record.season_id)
        detailVC.present(from: self)
    }
}

extension Season: PlayableData {
    var aid: Int { 0 }
    var cid: Int { 0 }
}

extension WebRequest.EndPoint {
    static let rank = "https://api.bilibili.com/x/web-interface/ranking/v2"
}

extension WebRequest {
    static func requestRank(for category: Int) async throws -> [VideoDetail.Info] {
        struct RankResp: Codable {
            let list: [VideoDetail.Info]
        }
        let resp: RankResp = try await request(url: EndPoint.rank, parameters: ["rid": category, "type": "all"])
        return resp.list
    }

    static func requestSeasonRank(for category: Int) async throws -> [Season] {
        struct Resp: Codable {
            let list: [Season]
        }
        let res: Resp = try await request(url: "https://api.bilibili.com/pgc/web/rank/list", parameters: ["day": 3, "season_type": category], dataObj: "result")
        return res.list
    }
}

struct Season: Codable, DisplayData {
    struct NewEP: Codable, Hashable {
        let cover: String
        let index_show: String
    }

    var ownerName: String { new_ep.index_show }
    var pic: URL? { cover }

    let title: String
    let cover: URL
    let season_id: Int
    let new_ep: NewEP
}
