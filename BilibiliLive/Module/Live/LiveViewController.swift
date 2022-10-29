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
    private var page = 1
    let collectionVC = FeedCollectionViewController()
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionVC.pageSize = 10
        collectionVC.show(in: self)
        collectionVC.didSelect = {
            [weak self] in
            self?.enter(with: $0 as! LiveRoom)
        }
        collectionVC.loadMore = {
            [weak self] in
            self?.loadMore()
        }
        reloadData()
    }

    func reloadData() {
        Task {
            page = 1
            let res = try? await WebRequest.requestLiveRoom(page: page)
            if res?.count ?? 0 < 9 { collectionVC.finished = true }
            collectionVC.displayDatas = res ?? []
        }
    }

    func loadMore() {
        Task {
            do {
                let res = try await WebRequest.requestLiveRoom(page: page + 1)
                collectionVC.appendData(displayData: res)
                page = page + 1
            }
        }
    }

    func enter(with room: LiveRoom) {
        let playerVC = LivePlayerViewController()
        playerVC.room = room
        present(playerVC, animated: true, completion: nil)
    }
}

struct LiveRoom: DisplayData, Codable {
    let title: String
    let room_id: Int
    let uname: String
    let keyframe: URL
    let face: URL?
    let cover_from_user: URL?

    var ownerName: String { uname }
    var pic: URL? { keyframe }
    var avatar: URL? { face }
}

extension WebRequest.EndPoint {
    static let liveRoom = "https://api.live.bilibili.com/xlive/web-ucenter/v1/xfetter/GetWebList"
}

extension WebRequest {
    static func requestLiveRoom(page: Int) async throws -> [LiveRoom] {
        struct Resp: Codable {
            let rooms: [LiveRoom]
        }
        let resp: Resp = try await request(url: EndPoint.liveRoom, parameters: ["page_size": 10, "page": page])
        return resp.rooms
    }
}
