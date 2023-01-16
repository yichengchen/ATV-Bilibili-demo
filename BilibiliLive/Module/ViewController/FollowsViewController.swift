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
        let json = try await WebRequest.requestJSON(url: "https://api.bilibili.com/x/web-feed/feed?ps=40&pn=\(page)")

        let datas = json.arrayValue.map { data -> FeedData in
            let timestamp = data["pubdate"].int
            let date = DateFormatter.stringFor(timestamp: timestamp)
            let bangumi = data["bangumi"]
            if !bangumi.isEmpty {
                let season = bangumi["season_id"].intValue
                let owner = bangumi["title"].stringValue
                let pic = bangumi["cover"].url!
                let ep = bangumi["new_ep"]
                let title = "第" + ep["index"].stringValue + "集 - " + ep["index_title"].stringValue
                let episode = ep["episode_id"].intValue
                return FeedData(title: title, cid: 0, aid: 0, isbangumi: true, season: season, episode: episode, ownerName: owner, pic: pic, avatar: nil, date: date)
            }
            let avid = data["id"].intValue
            let archive = data["archive"]
            let title = archive["title"].stringValue
            let cid = archive["cid"].intValue
            let owner = archive["owner"]["name"].stringValue
            let avatar = archive["owner"]["face"].url
            let pic = archive["pic"].url!
            return FeedData(title: title, cid: cid, aid: avid, isbangumi: false, season: nil, episode: nil, ownerName: owner, pic: pic, avatar: avatar, date: date)
        }
        return datas
    }

    override func goDetail(with feed: FeedData) {
        if !feed.isbangumi {
            let detailVC = VideoDetailViewController.create(aid: feed.aid, cid: feed.cid)
            detailVC.present(from: self)
            return
        } else {
            let detailVC = VideoDetailViewController.create(epid: feed.episode!)
            detailVC.present(from: self)
        }
    }
}

struct FeedData: PlayableData {
    let title: String
    let cid: Int
    let aid: Int
    let isbangumi: Bool
    let season: Int?
    let episode: Int?
    let ownerName: String
    let pic: URL?
    let avatar: URL?
    let date: String?
}
