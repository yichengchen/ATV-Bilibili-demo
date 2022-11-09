//
//  VideoPlayerViewController.swift
//  BilibiliLive
//
//  Created by Etan Chen on 2021/4/4.
//

import Alamofire
import AVFoundation
import AVKit
import Kingfisher
import SwiftyJSON
import SwiftyXMLParser
import UIKit

class VideoPlayerViewController: CommonPlayerViewController {
    var cid: Int?
    var aid: Int!
    var data: VideoDetail?
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

    private func playmedia(urlInfo: VideoPlayURLInfo, playerInfo: PlayerInfo?) async {
        let playURL = URL(string: BilibiliVideoResourceLoaderDelegate.URLs.play)!
        let headers: [String: String] = [
            "User-Agent": "Bilibili/APPLE TV",
            "Referer": "https://www.bilibili.com/video/av\(aid!)",
        ]
        let asset = AVURLAsset(url: playURL, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        playerDelegate = BilibiliVideoResourceLoaderDelegate()
        playerDelegate?.setBilibili(info: urlInfo, subtitles: playerInfo?.subtitle?.subtitles ?? [])
        asset.resourceLoader.setDelegate(playerDelegate, queue: DispatchQueue(label: "loader"))
        let requestedKeys = ["playable"]
        await asset.loadValues(forKeys: requestedKeys)
        prepare(toPlay: asset, withKeys: requestedKeys)
        danMuView.play()
        updatePlayerCharpter(playerInfo: playerInfo)
    }

    private func updatePlayerCharpter(playerInfo: PlayerInfo?) {
        let group = DispatchGroup()
        var metas = [AVTimedMetadataGroup]()
        for viewPoint in playerInfo?.view_points ?? [] {
            group.enter()
            convertTimedMetadataGroup(viewPoint: viewPoint) {
                metas.append($0)
                group.leave()
            }
        }
        group.notify(queue: .main) {
            if metas.count > 0 {
                self.playerItem?.navigationMarkerGroups = [AVNavigationMarkersGroup(title: nil, timedNavigationMarkers: metas)]
            }
        }
    }

    override func extraInfoForPlayerError() -> String {
        return playerDelegate?.infoDebugText ?? "-"
    }

    override func playerDidFinishPlaying() {
        dismiss(animated: true)
    }

    private func convertTimedMetadataGroup(viewPoint: PlayerInfo.ViewPoint, onResult: ((AVTimedMetadataGroup) -> Void)? = nil) {
        let mapping: [AVMetadataIdentifier: Any?] = [
            .commonIdentifierTitle: viewPoint.content,
        ]

        var metadatas = mapping.compactMap { createMetadataItem(for: $0, value: $1) }
        let timescale: Int32 = 600
        let cmStartTime = CMTimeMakeWithSeconds(viewPoint.from, preferredTimescale: timescale)
        let cmEndTime = CMTimeMakeWithSeconds(viewPoint.to, preferredTimescale: timescale)
        let timeRange = CMTimeRangeFromTimeToTime(start: cmStartTime, end: cmEndTime)
        if let pic = viewPoint.imgUrl?.addSchemeIfNeed() {
            let resource = ImageResource(downloadURL: pic)
            KingfisherManager.shared.retrieveImage(with: resource) {
                [weak self] result in
                guard let self = self,
                      let data = try? result.get().image.pngData(),
                      let item = self.createMetadataItem(for: .commonIdentifierArtwork, value: data)
                else {
                    onResult?(AVTimedMetadataGroup(items: metadatas, timeRange: timeRange))
                    return
                }
                metadatas.append(item)
                onResult?(AVTimedMetadataGroup(items: metadatas, timeRange: timeRange))
            }
        } else {
            onResult?(AVTimedMetadataGroup(items: metadatas, timeRange: timeRange))
        }
    }
}

// MARK: - Requests

extension VideoPlayerViewController {
    func fetchVideoData() async {
        let info = try? await WebRequest.requestPlayerInfo(aid: aid, cid: cid!)
        let startTime = info?.playTimeInSecond
        do {
            let playData = try await WebRequest.requestPlayUrl(aid: aid, cid: cid!)
            if let startTime = startTime, playData.dash.duration - startTime > 5 {
                playerStartPos = startTime
            }

            await playmedia(urlInfo: playData, playerInfo: info)

            if Settings.danmuMask, let mask = info?.dm_mask,
               let video = playData.dash.video.first,
               let fps = info?.dm_mask?.fps, fps > 0
            {
                maskProvider = BMaskProvider(info: mask, videoSize: CGSize(width: video.width, height: video.height), duration: playData.dash.duration)
                setupMask(fps: fps)
            }

            if data == nil {
                data = try? await WebRequest.requestDetailVideo(aid: aid!)
            }
            setPlayerInfo(title: data?.title, subTitle: data?.ownerName, desp: data?.View.desc, pic: data?.pic)
        } catch let err {
            if case let .statusFail(code, message) = err as? RequestError {
                showErrorAlertAndExit(message: "请求失败\(code) \(message)，可能需要大会员")
            } else {
                showErrorAlertAndExit(message: "请求失败,\(err)")
            }
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
