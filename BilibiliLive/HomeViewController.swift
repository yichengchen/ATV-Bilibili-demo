//
//  HomeViewController.swift
//  BilibiliLive
//
//  Created by Etan Chen on 2021/3/28.
//

import Foundation
import UIKit

import Alamofire
import SwiftyJSON
import Kingfisher

class HomeViewController: UIViewController, BLTabBarContentVCProtocol {
    var rooms = [LiveRoom]() {
        didSet {
            collectionVC.displayDatas = rooms.map{DisplayData(title: $0.name, owner: $0.up, pic: $0.cover)}
        }
    }
    
    let collectionVC = FeedCollectionViewController.create()
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionVC.show(in: self)
        collectionVC.didSelect = {
            [weak self] idx in
            self?.enter(with: idx)
        }
        loadData()
    }

    func reloadData() {
        loadData()
    }
    
    func loadData(page:Int = 1, perviousPage:[LiveRoom] = []) {
        var rooms = perviousPage
        AF.request("https://api.live.bilibili.com/xlive/web-ucenter/v1/xfetter/GetWebList?page_size=10&page=\(page)").responseJSON {
            [weak self] resp in
            guard let self = self else { return }
            switch resp.result {
            case .success(let data):
                let json = JSON(data)
                rooms.append(contentsOf: self.process(json: json))
                let totalCount = json["data"]["count"].intValue
                if self.rooms.count < totalCount, page < 5 {
                    self.loadData(page: page+1,perviousPage: rooms)
                } else {
                    self.rooms = rooms
                }
            case .failure(let err):
                print(err)
                if rooms.count > 0 {
                    self.rooms = rooms
                }
            }
        }
    }
    
    func process(json: JSON) -> [LiveRoom] {
        let newRooms = json["data"]["rooms"].arrayValue.map { room in
            LiveRoom(name: room["title"].stringValue,
                     roomID: room["room_id"].intValue,
                     up: room["uname"].stringValue,
                     cover: room["keyframe"].url)
        }
        return newRooms
    }
    
    func enter(with indexPath: IndexPath) {
        let room = rooms[indexPath.item]
        let cid = room.roomID
        let playerVC = UIStoryboard(name: "Main", bundle: Bundle.main).instantiateViewController(identifier: "PlayerViewController") as! LivePlayerViewController
        playerVC.roomID = cid
        present(playerVC, animated: true, completion: nil)
    }
}

extension HomeViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
    }    
}

struct LiveRoom {
    let name:String
    let roomID: Int
    let up: String
    let cover: URL?
}


