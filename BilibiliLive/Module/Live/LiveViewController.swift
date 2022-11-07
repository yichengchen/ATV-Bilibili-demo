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

class LiveViewController: StandardVideoCollectionViewController<LiveRoom> {
    override func setupCollectionView() {
        super.setupCollectionView()
        collectionVC.pageSize = 10
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
