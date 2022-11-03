//
//  VideoPlayerViewController.swift
//  BilibiliLive
//
//  Created by Etan Chen on 2021/4/4.
//

import Alamofire
import AVFoundation
import AVKit
import SwiftyJSON
import SwiftyXMLParser
import UIKit

class VideoPlayerViewController: CommonPlayerViewController {
    var cid: Int?
    var aid: Int!

    private var allDanmus = [Danmu]()
    private var playingDanmus = [Danmu]()
    private var playerDelegate: BilibiliVideoResourceLoaderDelegate?
    private let danmuProvider = VideoDanmuProvider()

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard let currentTime = player?.currentTime().seconds, currentTime > 0 else { return }

        if let aid = aid, let cid = cid, cid > 0 {
            WebRequest.reportWatchHistory(aid: aid, cid: cid, currentTime: Int(currentTime))
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        ensureCid {
            [weak self] in
            guard let self = self else { return }
            Task {
                await self.fetchVideoData()
            }
            self.danmuProvider.cid = self.cid
            self.danmuProvider.fetchDanmuData()
        }
        danmuProvider.onShowDanmu = {
            [weak self] in
            self?.danMuView.shoot(danmaku: $0)
        }
    }

    func playmedia(info: VideoPlayURLInfo) async {
        let playURL = URL(string: BilibiliVideoResourceLoaderDelegate.URLs.play)!
        let headers: [String: String] = [
            "User-Agent": "Bilibili/APPLE TV",
            "Referer": "https://www.bilibili.com/video/av\(aid!)",
        ]
        let asset = AVURLAsset(url: playURL, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        playerDelegate = BilibiliVideoResourceLoaderDelegate()
        playerDelegate?.setBilibili(info: info)
        asset.resourceLoader.setDelegate(playerDelegate, queue: DispatchQueue(label: "loader"))
        let requestedKeys = ["playable"]
        await asset.loadValues(forKeys: requestedKeys)
        prepare(toPlay: asset, withKeys: requestedKeys)
        danMuView.play()
    }

    override func extraInfoForPlayerError() -> String {
        return playerDelegate?.infoDebugText ?? "-"
    }

    override func playerDidFinishPlaying() {
        dismiss(animated: true)
    }
}

// MARK: - Requests

extension VideoPlayerViewController {
    func fetchVideoData() async {
        do {
            let playData = try await WebRequest.requestPlayUrl(aid: aid, cid: cid!)
            print(playData)
            await playmedia(info: playData)

            let info = await WebRequest.requestDetailVideo(aid: aid!)
            setPlayerInfo(title: info?.title, subTitle: info?.ownerName, desp: info?.desc, pic: info?.pic)
        } catch let err {
            if case let .statusFail(code, message) = err as? RequestError {
                showErrorAlertAndExit(message: "请求失败\(code) \(message)，可能需要大会员")
            } else {
                showErrorAlertAndExit(message: "请求失败,\(err)")
            }
            print(err)
        }
    }

    func ensureCid(callback: (() -> Void)? = nil) {
        if let cid = cid, cid > 0 {
            callback?()
            return
        }
        AF.request("https://api.bilibili.com/x/player/pagelist?aid=\(aid!)&jsonp=jsonp").responseData {
            [weak self] resp in
            guard let self = self else { return }
            switch resp.result {
            case let .success(data):
                let json = JSON(data)
                let cid = json["data"][0]["cid"].intValue
                self.cid = cid
                callback?()
            case let .failure(err):
                self.showErrorAlertAndExit(message: "请求cid失败")
                print(err)
            }
        }
    }
}

// MARK: - Player

extension VideoPlayerViewController {
    @MainActor
    func prepare(toPlay asset: AVURLAsset, withKeys requestedKeys: [AnyHashable]) {
        for thisKey in requestedKeys {
            guard let thisKey = thisKey as? String else {
                continue
            }
            var error: NSError?
            let keyStatus = asset.statusOfValue(forKey: thisKey, error: &error)
            if keyStatus == .failed {
                showErrorAlertAndExit(title: error?.localizedDescription ?? "", message: error?.localizedFailureReason ?? "")
                return
            }
        }

        if !asset.isPlayable {
            showErrorAlertAndExit(message: "URL解析错误")
            return
        }

        playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)
        player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 1), queue: .main) { [weak self] time in
            self?.danmuProvider.playerTimeChange(time: time.seconds)
        }
    }
}
