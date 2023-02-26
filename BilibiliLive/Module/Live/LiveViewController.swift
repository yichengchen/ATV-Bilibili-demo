//
//  LiveViewController.swift
//  BilibiliLive
//
//  Created by Etan Chen on 2021/3/28.
//

import Alamofire
import SwiftyJSON
import UIKit

class LiveViewController: CategoryViewController {
    override func viewDidLoad() {
        categories = [
            CategoryDisplayModel(title: "关注", contentVC: MyLiveViewController()),
            CategoryDisplayModel(title: "推荐", contentVC: AreaLiveViewController(areaID: -1)),
            CategoryDisplayModel(title: "人气", contentVC: AreaLiveViewController(areaID: 0)),
            CategoryDisplayModel(title: "娱乐", contentVC: AreaLiveViewController(areaID: 1)),
            CategoryDisplayModel(title: "虚拟主播", contentVC: AreaLiveViewController(areaID: 9)),
            CategoryDisplayModel(title: "网游", contentVC: AreaLiveViewController(areaID: 2)),
            CategoryDisplayModel(title: "手游", contentVC: AreaLiveViewController(areaID: 3)),
            CategoryDisplayModel(title: "单机", contentVC: AreaLiveViewController(areaID: 6)),
            CategoryDisplayModel(title: "生活", contentVC: AreaLiveViewController(areaID: 10)),
            CategoryDisplayModel(title: "电台", contentVC: AreaLiveViewController(areaID: 5)),
            CategoryDisplayModel(title: "知识", contentVC: AreaLiveViewController(areaID: 11)),
            CategoryDisplayModel(title: "赛事", contentVC: AreaLiveViewController(areaID: 13)),
        ]
        super.viewDidLoad()
    }
}

class MyLiveViewController: StandardVideoCollectionViewController<LiveRoom> {
    override func setupCollectionView() {
        super.setupCollectionView()
        collectionVC.styleOverride = .sideBar
        collectionVC.pageSize = 10
        reloadInterval = 15 * 60
    }

    override func request(page: Int) async throws -> [LiveRoom] {
        try await WebRequest.requestLiveRoom(page: page)
    }

    override func goDetail(with record: LiveRoom) {
        let playerVC = LivePlayerViewController()
        playerVC.room = record
        present(playerVC, animated: true, completion: nil)
    }
}

class AreaLiveViewController: StandardVideoCollectionViewController<AreaLiveRoom> {
    let areaID: Int
    init(areaID: Int) {
        self.areaID = areaID
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setupCollectionView() {
        super.setupCollectionView()
        collectionVC.styleOverride = .sideBar
        collectionVC.pageSize = 10
        reloadInterval = 15 * 60
    }

    override func request(page: Int) async throws -> [AreaLiveRoom] {
        if areaID == 0 {
            return try await WebRequest.requestHotLiveRoom(page: page)
        } else if areaID == -1 {
            return try await WebRequest.requestRecommandLiveRoom(page: page)
        }
        return try await WebRequest.requestAreaLiveRoom(area: areaID, page: page)
    }

    override func goDetail(with record: AreaLiveRoom) {
        let playerVC = LivePlayerViewController()
        playerVC.room = record.toLiveRoom()
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

extension LiveRoom: PlayableData {
    var cid: Int { 0 }
    var aid: Int { 0 }
}

extension WebRequest.EndPoint {
    static let liveRoom = "https://api.live.bilibili.com/xlive/web-ucenter/v1/xfetter/GetWebList"
    static let hotLive = "https://api.live.bilibili.com/xlive/web-interface/v1/second/getListByArea"
    static let areaLive = "https://api.live.bilibili.com/xlive/web-interface/v1/second/getList"
    static let recommandLive = "https://api.live.bilibili.com/xlive/web-interface/v1/second/getUserRecommend"
}

extension WebRequest {
    static func requestLiveRoom(page: Int) async throws -> [LiveRoom] {
        struct Resp: Codable {
            let rooms: [LiveRoom]
        }
        let resp: Resp = try await request(url: EndPoint.liveRoom, parameters: ["page_size": 10, "page": page])
        return resp.rooms
    }

    static func requestAreaLiveRoom(area: Int, page: Int) async throws -> [AreaLiveRoom] {
        struct Resp: Codable {
            let list: [AreaLiveRoom]
        }

        let resp: Resp = try await request(url: EndPoint.areaLive, parameters: ["platform": "web", "parent_area_id": area, "area_id": 0, "page": page])
        return resp.list
    }

    static func requestHotLiveRoom(page: Int) async throws -> [AreaLiveRoom] {
        struct Resp: Codable {
            let list: [AreaLiveRoom]
        }

        let resp: Resp = try await request(url: EndPoint.hotLive, parameters: ["platform": "web", "sort": "online", "page_size": 30, "page": page])
        return resp.list
    }

    static func requestRecommandLiveRoom(page: Int) async throws -> [AreaLiveRoom] {
        struct Resp: Codable {
            let list: [AreaLiveRoom]
        }

        let resp: Resp = try await request(url: EndPoint.recommandLive, parameters: ["platform": "web", "page_size": 30, "page": page])
        return resp.list
    }
}

struct AreaLiveRoom: DisplayData, Codable, PlayableData {
    let title: String
    let roomid: Int
    let uname: String
    let system_cover: URL
    let face: URL?
    let user_cover: URL?
    let parent_name: String
    let area_name: String
    var ownerName: String { uname }
    var pic: URL? { system_cover }
    var avatar: URL? { face }
    var cid: Int { 0 }
    var aid: Int { 0 }

    func toLiveRoom() -> LiveRoom {
        return LiveRoom(title: title, room_id: roomid, uname: uname, keyframe: system_cover, face: face, cover_from_user: user_cover)
    }
}
