//
//  F.swift
//  BilibiliLive
//
//  Created by Etan Chen on 2021/4/4.
//

import UIKit
import Alamofire
import SwiftyJSON

class FeedViewController: UIViewController, BLTabBarContentVCProtocol {
    let collectionVC = FeedCollectionViewController.create()
    var feeds = [DisplayData]() { didSet {collectionVC.displayDatas=feeds} }
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionVC.show(in: self)
        collectionVC.didSelect = {
            [weak self] idx in
            self?.goDetail(with: idx)
        }
        loadData()
    }
    
    func reloadData() {
        loadData()
    }
    
    func loadData() {
        AF.request("https://api.bilibili.com/x/web-feed/feed?ps=50&pn=1").responseJSON {
            [weak self] response in
            guard let self = self else { return }
            switch(response.result) {
            case .success(let data):
                let json = JSON(data)
                let datas = self.progrssData(json: json)
                self.feeds = datas
                
            case .failure(let error):
                print(error)
                break
            }
        }
    }
    
    func progrssData(json:JSON) -> [DisplayData] {
        let datas = json["data"].arrayValue.map { data -> DisplayData in
            let bangumi = data["bangumi"]
            if !bangumi.isEmpty {
                let season = bangumi["season_id"].intValue
                let owner = bangumi["title"].stringValue
                let pic = bangumi["cover"].url!
                let ep = bangumi["new_ep"]
                let title = "第" + ep["index"].stringValue + "集 - " + ep["index_title"].stringValue
                let episode = ep["episode_id"].intValue
                return BangumiData(title: title, season: season, episode: episode, owner: owner, pic: pic)
            }
            let avid = data["id"].intValue
            let archive = data["archive"]
            let title = archive["title"].stringValue
            let cid = archive["cid"].intValue
            let owner = archive["owner"]["name"].stringValue
            let pic = archive["pic"].url!
            return FeedData(title: title, cid: cid, aid: avid, owner: owner, pic: pic)
        }
        return datas
    }
    
    func goDetail(with indexPath: IndexPath) {
        if let feed = feeds[indexPath.item] as? FeedData {
            let player = VideoPlayerViewController()
            player.aid = feed.aid
            player.cid = feed.cid
            present(player, animated: true, completion: nil)
        }
        if let bangumi = feeds[indexPath.item] as? BangumiData {
            AF.request("https://api.bilibili.com/pgc/web/season/section?season_id=\(bangumi.season)").responseJSON { [weak self] (response) in
                guard let self = self else { return }
                switch(response.result) {
                case .success(let data):
                    let json = JSON(data)
                    let episodes = json["result"]["main_section"]["episodes"].arrayValue
                    for episode in episodes {
                        if episode["id"].intValue == bangumi.episode {
                            let player = VideoPlayerViewController()
                            player.aid = episode["aid"].intValue
                            player.cid = episode["cid"].intValue
                            self.present(player, animated: true, completion: nil)
                            break
                        }
                    }
                case .failure(let error):
                    print(error)
                }
            }
        }
    }
}

struct FeedData: DisplayData {
    let title: String
    let cid: Int
    let aid: Int
    let owner: String
    let pic: URL?
}

struct BangumiData: DisplayData {
    let title: String
    let season: Int
    let episode: Int
    let owner: String
    let pic: URL?
}

