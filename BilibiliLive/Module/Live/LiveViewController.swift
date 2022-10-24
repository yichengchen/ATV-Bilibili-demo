//
//  LiveViewController.swift
//  BilibiliLive
//
//  Created by Etan Chen on 2021/3/28.
//

import Foundation
import UIKit

import Alamofire
import SwiftyJSON

class LiveViewController: UIViewController, BLTabBarContentVCProtocol {
    var rooms = [LiveRoom]() { didSet { collectionVC.displayDatas = rooms } }

    let collectionVC = FeedCollectionViewController()
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionVC.show(in: self)
        collectionVC.didSelect = {
            [weak self] in
            self?.enter(with: $0 as! LiveRoom)
        }
        loadData()
    }

    func reloadData() {
        loadData()
    }

    func loadData(page: Int = 1, perviousPage: [LiveRoom] = []) {
        var rooms = perviousPage
        AF.request("https://api.live.bilibili.com/xlive/web-ucenter/v1/xfetter/GetWebList?page_size=10&page=\(page)").responseData {
            [weak self] resp in
            guard let self = self else { return }
            switch resp.result {
            case let .success(data):
                let json = JSON(data)
                rooms.append(contentsOf: self.process(json: json))
                let totalCount = json["data"]["count"].intValue
                if self.rooms.count < totalCount, page < 5 {
                    self.loadData(page: page + 1, perviousPage: rooms)
                } else {
                    self.rooms = rooms
                }
            case let .failure(err):
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

    func enter(with room: LiveRoom) {
        let playerVC = LivePlayerViewController()
        playerVC.room = room
        present(playerVC, animated: true, completion: nil)
    }
}

struct LiveRoom: DisplayData {
    let name: String
    let roomID: Int
    let up: String
    let cover: URL?

    var title: String { name }
    var ownerName: String { up }
    var pic: URL? { cover }
}
