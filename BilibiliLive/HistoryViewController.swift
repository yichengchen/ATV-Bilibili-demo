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
            let cid = data["cid"].intValue
            let avid = data["aid"].intValue
            let owner = data["owner"]["name"].stringValue
            let pic = data["pic"].url!
            let position = data["progress"].floatValue / data["duration"].floatValue
            return HistoryData(title: title, cid: cid, aid: avid, owner: owner, pic: pic, position: position)
        }
        return datas
    }
    
    func goDetail(with indexPath: IndexPath) {
        let history = feeds[indexPath.item]
        let player = VideoPlayerViewController()
        player.aid = history.aid
        player.cid = history.cid
        player.position = history.position
        present(player, animated: true, completion: nil)
    }
    
    func del(with indexPath: IndexPath) {
        let aid = feeds[indexPath.item].aid
        let cookies = CookieHandler.shared.getCookie(forURL: "https://bilibili.com")
        guard let token = cookies.first(where: {$0.name == "bili_jct"})?.value else { return }
        AF.request("http://api.bilibili.com/x/v2/history/delete",method: .post,parameters: ["aid":aid,"csrf":token]).responseJSON {
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
}


