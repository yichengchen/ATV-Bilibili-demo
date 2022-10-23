//
//  HistoryViewController.swift
//  BilibiliLive
//
//  Created by whw on 2021/4/15.
//

import Alamofire
import SwiftyJSON
import UIKit

class HistoryViewController: UIViewController, BLTabBarContentVCProtocol {
    let collectionVC = FeedCollectionViewController()
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionVC.show(in: self)
        collectionVC.didSelect = {
            [weak self] in
            self?.goDetail(with: $0 as! HistoryData)
        }
        loadData()
    }

    func reloadData() {
        loadData()
    }

    func loadData() {
        AF.request("http://api.bilibili.com/x/v2/history").responseData {
            [weak self] response in
            guard let self = self else { return }
            switch response.result {
            case let .success(data):
                let json = JSON(data)
                let datas = self.progrssData(json: json)
                self.collectionVC.displayDatas = datas
            case let .failure(error):
                print(error)
            }
        }
    }

    func progrssData(json: JSON) -> [HistoryData] {
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

    func goDetail(with history: HistoryData) {
        let detailVC = VideoDetailViewController.create(aid: history.aid, cid: history.cid)
        detailVC.present(from: self)
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
