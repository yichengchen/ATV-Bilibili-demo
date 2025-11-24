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
        collectionVC.didSelect = { [weak self] record in
            guard let self,
                  let record = record as? ToViewData
            else { return }
            goDetail(with: record)
        }
        collectionVC.didLongPress = {
            [weak self] record in
            guard let self else { return }
            let deleteAction = UIAlertAction(title: NSLocalizedString("Delete", comment: "Delete Action"), style: .destructive) { [weak self] _ in
                guard let self,
                      let record = record as? ToViewData
                else { return }
                del(with: record)
            }
            let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel Action"), style: .cancel)
            let alert = UIAlertController(
                title: NSLocalizedString("Confirm Delete", comment: "Delete Alert title"),
                message: NSLocalizedString("Delete this video from your watch later list", comment: "Delete Alert message"),
                preferredStyle: .alert
            )
            alert.addAction(deleteAction)
            alert.addAction(cancelAction)
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
        AF.request("https://api.bilibili.com/x/v2/history/toview/del", method: .post, parameters: ["aid": aid, "csrf": csrf]).responseData {
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
    let duration: Int
    let stat: Stat?

    var durationString: String {
        let formatter = DateComponentsFormatter()
        if duration >= 3600 {
            formatter.allowedUnits = [.hour, .minute, .second]
        } else {
            formatter.allowedUnits = [.minute, .second]
        }
        formatter.zeroFormattingBehavior = .pad
        formatter.unitsStyle = .positional
        return formatter.string(from: TimeInterval(duration)) ?? ""
    }

    struct Stat: Codable, Hashable {
        let view: Int
        let danmaku: Int
    }

    var ownerName: String {
        return owner.name
    }

    var avatar: URL? {
        if owner.face != nil {
            return URL(string: owner.face!)
        }
        return nil
    }

    var date: String? {
        return DateFormatter.stringFor(timestamp: pubdate)
    }

    var overlay: DisplayOverlay? {
        var leftItems = [DisplayOverlay.DisplayOverlayItem]()
        var rightItems = [DisplayOverlay.DisplayOverlayItem]()
        if let stat {
            leftItems.append(DisplayOverlay.DisplayOverlayItem(icon: "play.rectangle", text: stat.view == 0 ? "-" : stat.view.numberString()))
            leftItems.append(DisplayOverlay.DisplayOverlayItem(icon: "list.bullet.rectangle", text: stat.danmaku == 0 ? "-" : stat.danmaku.numberString()))
        }
        rightItems.append(DisplayOverlay.DisplayOverlayItem(icon: nil, text: durationString))
        return DisplayOverlay(leftItems: leftItems, rightItems: rightItems)
    }
}

extension WebRequest {
    static func requestToView() async throws -> [ToViewData] {
        struct Resp: Codable {
            var list: [ToViewData]?
        }
        let res: Resp = try await request(url: "https://api.bilibili.com/x/v2/history/toview")
        return res.list ?? []
    }
}
