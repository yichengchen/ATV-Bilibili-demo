//
//  F.swift
//  BilibiliLive
//
//  Created by Etan Chen on 2021/4/4.
//

import Alamofire
import SwiftyJSON
import UIKit

class FollowsViewController: StandardVideoCollectionViewController<FeedData> {
    override func request(page: Int) async throws -> [FeedData] {
        return try await WebRequest.requestFollowsFeed(page: page)
    }

    override func goDetail(with feed: FeedData) {
        if let bangumi = feed.bangumi {
            let detailVC = VideoDetailViewController.create(epid: bangumi.new_ep.episode_id)
            detailVC.present(from: self)
        } else {
            // 发现这个旧feed接口的bangumi字段一直为nil，只有archive中有正确的ep_id值，港澳台解锁需要获取该值
            var epid: Int?
            if let redirect = feed.archive?.redirect_url?.lastPathComponent, redirect.starts(with: "ep") {
                epid = Int(redirect.dropFirst(2))
            }
            let detailVC = VideoDetailViewController.create(aid: feed.aid, cid: feed.cid, epid: epid)
            detailVC.present(from: self)
        }
    }
}

extension WebRequest {
    static func requestFollowsFeed(page: Int) async throws -> [FeedData] {
        return try await request(url: "https://api.bilibili.com/x/web-feed/feed", parameters: ["ps": 40, "pn": page])
    }
}

struct FeedData: Decodable, PlayableData {
    struct Bangumi: Decodable, Hashable {
        let season_id: Int
        let title: String
        let cover: URL
        struct EP: Decodable, Hashable {
            let index: String
            let index_title: String?
            let episode_id: Int
        }

        let new_ep: EP
    }

    struct Archive: Decodable, Hashable {
        let title: String
        let cid: Int
        let owner: VideoOwner
        let pic: URL
        let redirect_url: URL?
    }

    let id: Int
    let pubdate: Int
    let bangumi: Bangumi?
    let archive: Archive?

    // PlayableData
    var cid: Int { 0 }
    var aid: Int { id }

    // DisplayData
    var title: String { (archive != nil) ? archive!.title : bangumi!.title }
    var ownerName: String { (archive != nil) ? archive!.owner.name : bangumi!.title }
    var pic: URL? { (archive != nil) ? archive!.pic : bangumi!.cover }
    var avatar: URL? { URL(string: archive?.owner.face ?? "") }
    var date: String? { DateFormatter.stringFor(timestamp: pubdate) }
}
