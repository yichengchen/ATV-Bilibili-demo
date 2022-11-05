//
//  WeeklyWatchViewController.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/11/5.
//

import UIKit

class WeeklyWatchViewController: StandardVideoCollectionViewController<VideoDetail.Info> {
    var list = [WeeklyList]()

    override func setupCollectionView() {
        super.setupCollectionView()
        collectionVC.styleOverride = .sideBar
    }

    override func supportPullToLoad() -> Bool {
        return false
    }

    override func request(page: Int) async throws -> [VideoDetail.Info] {
        list = try await WebRequest.requestWeeklyWatchList()
        if let number = list.first?.number {
            let data = try await WebRequest.requestWeeklyWatch(wid: number)
            return data
        } else {
            throw NSError(domain: "", code: -1)
        }
    }
}

extension WebRequest {
    static func requestWeeklyWatchList() async throws -> [WeeklyList] {
        struct Resp: Codable {
            let list: [WeeklyList]
        }
        let res: Resp = try await request(url: "https://api.bilibili.com/x/web-interface/popular/series/list")
        return res.list
    }

    static func requestWeeklyWatch(wid: Int) async throws -> [VideoDetail.Info] {
        struct Resp: Codable {
            let list: [VideoDetail.Info]
        }
        let res: Resp = try await request(url: "https://api.bilibili.com/x/web-interface/popular/series/one", parameters: ["number": wid])
        return res.list
    }
}

struct WeeklyList: Codable {
    let number: Int
    let subject: String
    let name: String
}
