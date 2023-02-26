//
//  ToViewViewController.swift
//  BilibiliLive
//
//  Created by Etan Chen on 2021/4/5.
//

import Alamofire
import SwiftyJSON
import UIKit

class ToViewViewController: StandardVideoCollectionViewController<ToViewData> {
    override func setupCollectionView() {
        super.setupCollectionView()
        collectionVC.styleOverride = .sideBar
        collectionVC.didSelect = {
            [weak self] record in
            self?.goDetail(with: record as! ToViewData)
        }
        collectionVC.didLongPress = {
            [weak self] record in
            guard let self = self else { return }
            let alert = UIAlertController(title: "Delete?", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                self.del(with: record as! ToViewData)
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }

    override func supportPullToLoad() -> Bool {
        return false
    }

    override func goDetail(with feed: ToViewData) {
        let vc = VideoDetailViewController.create(aid: feed.aid, cid: feed.cid)
        vc.present(from: self)
    }

    func del(with toViewItem: ToViewData) {
        let aid = toViewItem.aid
        guard let csrf = CookieHandler.shared.csrf() else { return }
        AF.request("http://api.bilibili.com/x/v2/history/toview/del", method: .post, parameters: ["aid": aid, "csrf": csrf]).responseData {
            [weak self] resp in
            print(resp.result)
            self?.reloadData()
        }
    }

    override func request(page: Int) async throws -> [ToViewData] {
        return try await WebRequest.requestToView()
    }
}

struct ToViewData: PlayableData, Codable {
    let title: String
    let cid: Int
    let aid: Int
    let owner: VideoOwner
    let pic: URL?
    let pubdate: Int

    var ownerName: String {
        return owner.name
    }

    var avatar: URL? {
        return URL(string: owner.face)
    }

    var date: String? {
        return DateFormatter.stringFor(timestamp: pubdate)
    }
}

extension WebRequest {
    static func requestToView() async throws -> [ToViewData] {
        struct Resp: Codable {
            var list: [ToViewData]
        }
        let res: Resp = try await request(url: "https://api.bilibili.com/x/v2/history/toview")
        return res.list
    }
}
