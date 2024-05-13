//
//  PlayerViewController.swift
//  BilibiliLive
//
//  Created by Etan on 2021/3/27.
//

import Alamofire
import AVKit
import Foundation
import SwiftyJSON
import UIKit

class LivePlayerViewController: CommonPlayerViewController {
    var room: LiveRoom? {
        didSet {
            roomID = room?.room_id ?? 0
        }
    }

    private var roomID: Int = 0
    private var failCount = 0
    private var viewModel: LivePlayerViewModel?
    deinit {
        Logger.debug("deinit live player")
    }

    override func viewDidLoad() {
        allowChangeSpeed = false
        requiresLinearPlayback = true
        super.viewDidLoad()

        viewModel = LivePlayerViewModel(roomID: roomID)
        viewModel?.onShootDanmu = { [weak self] in
            self?.danMuView.shoot(danmaku: $0)
        }
        viewModel?.onPlayUrlStr = { [weak self] in
            guard let self else { return }
            let headers: [String: String] = [
                "User-Agent": Keys.userAgent,
                "Referer": Keys.liveReferer,
            ]
            let asset = AVURLAsset(url: URL(string: $0)!, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
            playerItem = AVPlayerItem(asset: asset)
            player = AVPlayer(playerItem: playerItem)
            player?.automaticallyWaitsToMinimizeStalling = false
        }
        viewModel?.onError = { [weak self] in
            self?.showErrorAlertAndExit(message: $0)
        }

        viewModel?.start()

        if Settings.danmuMask, Settings.vnMask {
            maskProvider = VMaskProvider()
            setupMask()
        }

        Task {
            if let info = await viewModel?.fetchDespInfo() {
                let subtitle = "\(room?.ownerName ?? "")·\(info.parent_area_name) \(info.area_name)"
                let desp = "\(info.description)\nTags:\(info.tags ?? "")"
                setPlayerInfo(title: info.title, subTitle: subtitle, desp: desp, pic: room?.pic)
            } else {
                setPlayerInfo(title: room?.title, subTitle: "", desp: room?.ownerName, pic: room?.pic)
            }
        }
    }

    override func retryPlay() -> Bool {
        Logger.warn("play fail, retry")
        viewModel?.playerDidFailToPlay()
        return true
    }

    override func playerRateDidChange(player: AVPlayer) {
        Logger.info("play speed change to", player.rate)
        if player.rate == 0 {
            viewModel?.playerDidFailToPlay()
        }
    }

    override func additionDebugInfo() -> String {
        return viewModel?.debugInfo() ?? ""
    }
}
