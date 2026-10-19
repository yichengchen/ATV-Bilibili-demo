//
//  ToViewViewController.swift
//  BilibiliLive
//
//  Created by Etan Chen on 2021/4/5.
//

import Alamofire
import SnapKit
import SwiftyJSON
import UIKit

class ToViewViewController: StandardVideoCollectionViewController<ToViewData> {
    private var isClearingWatched = false

    override func setupCollectionView() {
        super.setupCollectionView()
        collectionVC.showHeader = true
        collectionVC.customHeaderConfig = FeedHeaderConfig(
            viewType: ToViewHeaderSupplementaryView.self,
            estimatedHeight: 90
        ) { [weak self] headerView, _ in
            headerView.onClearWatchedTapped = { [weak self] in
                self?.confirmClearWatched()
            }
        }
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

    private func confirmClearWatched() {
        guard !isClearingWatched else { return }
        let clearAction = UIAlertAction(title: "清除", style: .destructive) { [weak self] _ in
            self?.clearWatched()
        }
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel Action"), style: .cancel)
        let alert = UIAlertController(
            title: "清除已看完",
            message: "将从稍后再看中移除所有已看完的视频，此操作无法撤销",
            preferredStyle: .alert
        )
        alert.addAction(clearAction)
        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
    }

    private func clearWatched() {
        guard !isClearingWatched else { return }
        isClearingWatched = true
        Task { [weak self] in
            do {
                try await WebRequest.requestClearViewedToView()
                guard let self else { return }
                self.isClearingWatched = false
                // 仅在服务器确认成功后刷新列表
                await self.reallyReloadData()
            } catch let err {
                guard let self else { return }
                self.isClearingWatched = false
                var message = "\(err)"
                if let requestError = err as? RequestError,
                   case let .statusFail(code, msg) = requestError
                {
                    message = "\(msg) (\(code))"
                }
                let alert = UIAlertController(title: "清除失败", message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Ok", style: .cancel))
                self.present(alert, animated: true)
            }
        }
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

    /// 清除稍后再看中所有已看完的视频，code != 0 时抛出 RequestError.statusFail
    static func requestClearViewedToView() async throws {
        // POST 请求会由 requestData 自动附带 csrf
        _ = try await requestJSON(method: .post,
                                  url: "https://api.bilibili.com/x/v2/history/toview/del",
                                  parameters: ["viewed": "true"])
    }
}

class ToViewHeaderSupplementaryView: UICollectionReusableView {
    let clearWatchedButton = BLCustomTextButton()
    var onClearWatchedTapped: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(clearWatchedButton)
        clearWatchedButton.title = "清除已看完"
        clearWatchedButton.titleFont = .systemFont(ofSize: 26, weight: .medium)
        clearWatchedButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(30)
            make.top.equalToSuperview().offset(10)
            make.bottom.equalToSuperview().offset(-20)
        }
        clearWatchedButton.onPrimaryAction = { [weak self] _ in
            self?.onClearWatchedTapped?()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
