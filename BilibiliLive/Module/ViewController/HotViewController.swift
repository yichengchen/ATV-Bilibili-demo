//
//  HotViewController.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/10/26.
//

import UIKit

class HotViewController: StandardVideoCollectionViewController<VideoDetail.Info> {
    override func setupCollectionView() {
        super.setupCollectionView()
        collectionVC.isShowCove = true
    }

    override func request(page: Int) async throws -> [VideoDetail.Info] {
        collectionVC.headerText = "热门视频"
        return try await WebRequest.requestHotVideo(page: page).list
    }
}

extension WebRequest {
    static func requestHotVideo(page: Int) async throws -> HotData {
        try await request(url: EndPoint.hot, parameters: ["pn": page, "ps": 40], noCookie: Settings.requestHotWithoutCookie)
    }
}

extension WebRequest.EndPoint {
    static let hot = "https://api.bilibili.com/x/web-interface/popular"
}

struct HotData: Codable {
    let no_more: Bool
    let list: [VideoDetail.Info]
}
