//
//  ToViewViewController.swift
//  BilibiliLive
//
//  Created by Etan Chen on 2021/4/5.
//

import UIKit
import Alamofire
import SwiftyJSON

class ToViewViewController: UIViewController, BLTabBarContentVCProtocol {
    let collectionVC = FeedCollectionViewController.create()
    var feeds = [FeedData]() {
        didSet {
            collectionVC.displayDatas = feeds.map{ DisplayData(title: $0.title, owner: $0.owner, pic: $0.pic) }
        }
    }
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
        AF.request("http://api.bilibili.com/x/v2/history/toview").responseJSON {
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
    
    func progrssData(json:JSON) -> [FeedData] {
        let datas = json["data"]["list"].arrayValue.map { data -> FeedData in
            let title = data["title"].stringValue
            let cid = data["cid"].intValue
            let avid = data["aid"].intValue
            let owner = data["owner"]["name"].stringValue
            let pic = data["pic"].url!
            return FeedData(title: title, cid: cid, aid: avid, owner: owner, pic: pic)
        }
        return datas
    }
    
    func goDetail(with indexPath: IndexPath) {
        let feed = feeds[indexPath.item]
        let player = VideoPlayerViewController()
        player.aid = feed.aid
        player.cid = feed.cid
        present(player, animated: true, completion: nil)
    }
}



