//
//  HotViewController.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/10/26.
//

import UIKit

class HotViewController: UIViewController, BLTabBarContentVCProtocol {
    let collectionVC = FeedCollectionViewController()
    private var page = 0
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionVC.show(in: self)
        collectionVC.pageSize = 40
        collectionVC.didSelect = {
            [weak self] in
            self?.goDetail(with: $0 as! VideoDetail)
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
            let res = try? await WebRequest.requestHotVideo(page: page)
            collectionVC.displayDatas = res?.list ?? []
        }
    }

    func loadMore() {
        Task {
            do {
                let res = try await WebRequest.requestHotVideo(page: page + 1)
                collectionVC.appendData(displayData: res.list)
                page = page + 1
                if res.no_more {
                    collectionVC.finished = true
                }
            }
        }
    }

    func goDetail(with record: VideoDetail) {
        let detailVC = VideoDetailViewController.create(aid: record.View.aid, cid: record.View.cid)
        detailVC.present(from: self)
    }
}

extension WebRequest {
    static func requestHotVideo(page: Int) async throws -> HotData {
        try await request(url: EndPoint.hot, parameters: ["pn": page, "ps": 40])
    }
}

extension WebRequest.EndPoint {
    static let hot = "https://api.bilibili.com/x/web-interface/popular"
}

struct HotData: Codable {
    let no_more: Bool
    let list: [VideoDetail.Info]
}
