//
//  FollowsViewController.swift
//  BilibiliLive
//
//  Created by Etan Chen on 2021/4/4.
//

import Alamofire
import SwiftyJSON
import UIKit

class FollowsViewController: StandardVideoCollectionViewController<DynamicFeedData> {
    var lastOffset = ""

    override func setupCollectionView() {
        super.setupCollectionView()
        collectionVC.pageSize = 1
        collectionVC.isShowCove = true
    }

    override func request(page: Int) async throws -> [DynamicFeedData] {
        if page == 1 {
            lastOffset = ""
        }
        let info = try await WebRequest.requestFollowsFeed(offset: lastOffset, page: page)
        lastOffset = info.offset
        Logger.debug("request page\(page) get count:\(info.videoFeeds.count) next offset:\(info.offset)")
        collectionVC.headerText = "关注更新"
        return info.videoFeeds
    }

    override func goDetail(with feed: DynamicFeedData) {
        let epid = feed.modules.module_dynamic.major?.pgc?.epid
        let detailVC = VideoDetailViewController.create(aid: feed.aid, cid: feed.cid, epid: epid)
        detailVC.present(from: self)
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
            return items
                .filter({ $0.aid != 0 || $0.modules.module_dynamic.major?.pgc != nil })
        }
    }

    static func requestFollowsFeed(offset: String, page: Int) async throws -> DynamicFeedInfo {
        var param: [String: Any] = ["type": "all", "timezone_offset": "-480", "page": page]
        if let offsetNum = Int(offset) {
            param["offset"] = offsetNum
        }
        let res: DynamicFeedInfo = try await request(url: "https://api.bilibili.com/x/polymer/web-dynamic/v1/feed/all", parameters: param)
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

    var cid: Int { return 0 }

    var title: String {
        return modules.module_dynamic.major?.archive?.title ?? modules.module_dynamic.major?.pgc?.title ?? ""
    }

    var ownerName: String {
        return modules.module_author.name
    }

    var pic: URL? {
        return URL(string: modules.module_dynamic.major?.archive?.cover ?? "") ?? modules.module_dynamic.major?.pgc?.cover
    }

    var avatar: URL? {
        return URL(string: modules.module_author.face)
    }

    var date: String? {
        return modules.module_author.pub_time
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
                }

                struct Pgc: Codable, Hashable {
                    let epid: Int
                    let title: String?
                    let cover: URL?
                    let jump_url: URL?
                }
            }
        }
    }
}
