//
//  HistoryViewController.swift
//  BilibiliLive
//
//  Created by whw on 2021/4/15.
//

import UIKit
import Alamofire
import SwiftyJSON

class HistoryViewController: UIViewController, BLTabBarContentVCProtocol {
    let collectionVC = FeedCollectionViewController.create()
    var feeds = [HistoryData]() { didSet {collectionVC.displayDatas=feeds} }
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionVC.show(in: self)
        collectionVC.didSelect = {
            [weak self] idx in
            self?.goDetail(with: idx)
        }
        collectionVC.didLongPress = {
            [weak self] idx in
            guard let self = self else { return }
            let alert = UIAlertController(title: "Delete?", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                self.del(with: idx)
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
        AF.request("http://api.bilibili.com/x/v2/history").responseJSON {
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
    
    func progrssData(json:JSON) -> [HistoryData] {
        let datas = json["data"].arrayValue.map { data -> HistoryData in
            let title = data["title"].stringValue
            let avid = data["aid"].intValue
            let owner = data["owner"]["name"].stringValue
            let pic = data["pic"].url!
            
            let cid: Int
            let position: Float
            let multiPage: Bool
            let pages = data["videos"].intValue
            let page = data["page"]
            if pages > 1 && page.exists() {
                cid = page["cid"].intValue
                position = data["progress"].floatValue / page["duration"].floatValue
                multiPage = true
            } else {
                cid = data["cid"].intValue
                position = data["progress"].floatValue / data["duration"].floatValue
                multiPage = false
            }
            return HistoryData(title: title, cid: cid, aid: avid, owner: owner, pic: pic, position: position, multiPage: multiPage)
        }
        return datas
    }
    
    func goDetail(with indexPath: IndexPath) {
        let history = feeds[indexPath.item]
        if history.multiPage {
            let detailVC = VideoDetailViewController.create(aid: history.aid, cid: history.cid)
            present(detailVC, animated: false) {
                let player = VideoPlayerViewController()
                player.aid = history.aid
                player.cid = history.cid
                player.position = history.position
                detailVC.present(player, animated: true, completion: nil)
            }
        } else {
            let player = VideoPlayerViewController()
            player.aid = history.aid
            player.cid = history.cid
            player.position = history.position
            present(player, animated: true, completion: nil)
        }
    }
    
    func del(with indexPath: IndexPath) {
        let aid = feeds[indexPath.item].aid
        guard let csrf = CookieHandler.shared.csrf() else { return }
        AF.request("http://api.bilibili.com/x/v2/history/delete",method: .post,parameters: ["aid":aid,"csrf":csrf]).responseJSON {
            [weak self] resp in
            print(resp.result)
            self?.reloadData()
        }
    }
}

struct HistoryData: DisplayData {
    let title: String
    let cid: Int
    let aid: Int
    let owner: String
    let pic: URL?
    let position: Float
    let multiPage: Bool
}


