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
    let collectionVC = FeedCollectionViewController()

    override func viewDidLoad() {
        super.viewDidLoad()
        collectionVC.show(in: self)
        collectionVC.didSelect = {
            [weak self] record in
            self?.goDetail(with: record as! FeedData)
        }
        collectionVC.didLongPress = {
            [weak self] record in
            guard let self = self else { return }
            let alert = UIAlertController(title: "Delete?", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                self.del(with: record as! FeedData)
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
        loadData()
    }
    
    func reloadData() {
        loadData()
    }
    
    func loadData() {
        AF.request("http://api.bilibili.com/x/v2/history/toview").responseData {
            [weak self] response in
            guard let self = self else { return }
            switch(response.result) {
            case .success(let data):
                let json = JSON(data)
                let datas = self.progrssData(json: json)
                self.collectionVC.displayDatas = datas
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
            let avatar = data["owner"]["face"].url
            let timestamp = data["pubdate"].int
            let date = DateFormatter.stringFor(timestamp: timestamp)
            return FeedData(title: title, cid: cid, aid: avid, owner: owner, pic: pic,avatar: avatar, date: date)
        }
        return datas
    }
    
    func goDetail(with feed: FeedData) {
        let vc = VideoDetailViewController.create(aid: feed.aid, cid: feed.cid)
        vc.present(from: self)
    }
    
    func del(with feed: FeedData) {
        let aid = feed.aid
        guard let csrf = CookieHandler.shared.csrf() else { return }
        AF.request("http://api.bilibili.com/x/v2/history/toview/del",method: .post,parameters: ["aid":aid,"csrf":csrf]).responseData {
            [weak self] resp in
            print(resp.result)
            self?.reloadData()
        }
    }
}



