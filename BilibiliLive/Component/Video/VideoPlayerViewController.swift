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

struct PlayInfo {
    let aid: Int
    var cid: Int? = 0
    var epid: Int? = 0 // 港澳台解锁需要
    var isBangumi: Bool = false

    var isCidVaild: Bool {
        return cid ?? 0 > 0
    }
}

class VideoNextProvider {
    init(seq: [PlayInfo]) {
        playSeq = seq
    }

    private var index = 0
    private let playSeq: [PlayInfo]
    func reset() {
        index = 0
    }

    func getNext() -> PlayInfo? {
        index += 1
        if index < playSeq.count {
            return playSeq[index]
        }
        return nil
    }
}

class VideoPlayerViewController: CommonPlayerViewController {
    var playInfo: PlayInfo
    init(playInfo: PlayInfo) {
        self.playInfo = playInfo
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var data: VideoDetail?
    var nextProvider: VideoNextProvider?
    private var allDanmus = [Danmu]()
    private var playingDanmus = [Danmu]()
    private var playerDelegate: BilibiliVideoResourceLoaderDelegate?
    private let danmuProvider = VideoDanmuProvider()
    private var clipInfos: [VideoPlayURLInfo.ClipInfo]?
    private var skipAction: UIAction?
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard let currentTime = player?.currentTime().seconds, currentTime > 0 else { return }

        if let cid = playInfo.cid, cid > 0 {
            WebRequest.reportWatchHistory(aid: playInfo.aid, cid: cid, currentTime: Int(currentTime))
        }
        BiliBiliUpnpDMR.shared.sendStatus(status: .stop)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        Task {
            await initPlayer()
        }
        danmuProvider.onShowDanmu = {
            [weak self] in
            self?.danMuView.shoot(danmaku: $0)
        }
    }

    private func initPlayer() async {
        if !playInfo.isCidVaild {
            do {
                playInfo.cid = try await WebRequest.requestCid(aid: playInfo.aid)
            } catch let err {
                self.showErrorAlertAndExit(message: "请求cid失败,\(err.localizedDescription)")
            }
        }
        await fetchVideoData()
        danmuProvider.reset()
        danmuProvider.cid = playInfo.cid
        danmuProvider.fetchDanmuData()
    }

    private func playmedia(urlInfo: VideoPlayURLInfo, playerInfo: PlayerInfo?) async {
        let playURL = URL(string: BilibiliVideoResourceLoaderDelegate.URLs.play)!
        let headers: [String: String] = [
            "User-Agent": "Bilibili/APPLE TV",
            "Referer": "https://www.bilibili.com/video/av\(playInfo.aid)",
        ]
        let asset = AVURLAsset(url: playURL, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        playerDelegate = BilibiliVideoResourceLoaderDelegate()
        playerDelegate?.setBilibili(info: urlInfo, subtitles: playerInfo?.subtitle?.subtitles ?? [], aid: playInfo.aid)
        asset.resourceLoader.setDelegate(playerDelegate, queue: DispatchQueue(label: "loader"))
        let requestedKeys = ["playable"]
        await asset.loadValues(forKeys: requestedKeys)
        prepare(toPlay: asset, withKeys: requestedKeys)
        danMuView.play()
        updatePlayerCharpter(playerInfo: playerInfo)
        BiliBiliUpnpDMR.shared.sendVideoSwitch(aid: playInfo.aid, cid: playInfo.cid ?? 0)
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

    override func additionDebugInfo() -> String {
        if let port = playerDelegate?.httpPort.string() {
            return " :" + port
        }
        return ""
    }

    override func playerStatusDidChange() {
        super.playerStatusDidChange()
        switch player?.status {
        case .readyToPlay:
            BiliBiliUpnpDMR.shared.sendStatus(status: .playing)
        case .failed:
            BiliBiliUpnpDMR.shared.sendStatus(status: .stop)
        default:
            break
        }
    }

    func playNext() -> Bool {
        if let next = nextProvider?.getNext() {
            playInfo = next
            Task {
                await initPlayer()
            }
            return true
        }
        return false
    }

    override func playDidEnd() {
        BiliBiliUpnpDMR.shared.sendStatus(status: .end)
        if !playNext() {
            if Settings.loopPlay {
                nextProvider?.reset()
                if !playNext() {
                    playerItem?.seek(to: .zero, completionHandler: nil)
                    player?.play()
                }
                return
            }
            dismiss(animated: true)
        }
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
            let resource = Kingfisher.ImageResource(downloadURL: pic)
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
        assert(playInfo.isCidVaild)
        let aid = playInfo.aid
        let cid = playInfo.cid!
        let info = try? await WebRequest.requestPlayerInfo(aid: aid, cid: cid)
        do {
            let playData: VideoPlayURLInfo
            if playInfo.isBangumi {
                playData = try await WebRequest.requestPcgPlayUrl(aid: aid, cid: cid)
                clipInfos = playData.clip_info_list
            } else {
                playData = try await WebRequest.requestPlayUrl(aid: aid, cid: cid)
            }
            if info?.last_play_cid == cid, let startTime = info?.playTimeInSecond, playData.dash.duration - startTime > 5, Settings.continuePlay {
                playerStartPos = startTime
            }

            await playmedia(urlInfo: playData, playerInfo: info)

            if Settings.danmuMask {
                if let mask = info?.dm_mask,
                   let video = playData.dash.video.first,
                   let fps = info?.dm_mask?.fps, fps > 0
                {
                    maskProvider = BMaskProvider(info: mask, videoSize: CGSize(width: video.width ?? 0, height: video.height ?? 0))
                } else if Settings.vnMask {
                    maskProvider = VMaskProvider()
                }
                setupMask()
            }

            if data == nil {
                data = try? await WebRequest.requestDetailVideo(aid: aid)
            }
            setPlayerInfo(title: data?.title, subTitle: data?.ownerName, desp: data?.View.desc, pic: data?.pic)
        } catch let err {
            if case let .statusFail(code, message) = err as? RequestError {
                if code == -404 || code == -10403 {
                    // 解锁港澳台番剧处理
                    do {
                        if let ok = try await fetchAreaLimitVideoData(), ok {
                            return
                        }
                    } catch let err {
                        showErrorAlertAndExit(message: "请求失败,\(err)")
                    }
                }
                showErrorAlertAndExit(message: "请求失败\(code) \(message)，可能需要大会员")
            } else {
                showErrorAlertAndExit(message: "请求失败,\(err)")
            }
        }
    }

    func fetchAreaLimitVideoData() async throws -> Bool? {
        guard Settings.areaLimitUnlock else { return false }
        guard let epid = playInfo.epid, epid > 0 else { return false }

        let aid = playInfo.aid
        let cid = playInfo.cid!

        let season = try await WebRequest.requestBangumiSeasonView(epid: epid)
        let checkTitle = season.title.contains("僅") ? season.title : season.series_title
        let checkAreaList = parseAreaByTitle(title: checkTitle)
        guard !checkAreaList.isEmpty else { return false }

        let playData = try await requestAreaLimitPcgPlayUrl(epid: epid, cid: cid, areaList: checkAreaList)
        guard let playData = playData else { return false }

        let info = try? await WebRequest.requestPlayerInfo(aid: aid, cid: cid)
        if info?.last_play_cid == cid, let startTime = info?.playTimeInSecond, playData.dash.duration - startTime > 5, Settings.continuePlay {
            playerStartPos = startTime
        } else {
            playerStartPos = 0
        }

        await playmedia(urlInfo: playData, playerInfo: info)

        if Settings.danmuMask {
            if let mask = info?.dm_mask,
               let video = playData.dash.video.first,
               let fps = info?.dm_mask?.fps, fps > 0
            {
                maskProvider = BMaskProvider(info: mask, videoSize: CGSize(width: video.width ?? 0, height: video.height ?? 0))
            } else if Settings.vnMask {
                maskProvider = VMaskProvider()
            }
            setupMask()
        }

        if data == nil {
            if let epi = season.episodes.first(where: { $0.ep_id == epid }) {
                setPlayerInfo(title: epi.index + " " + (epi.index_title ?? ""), subTitle: season.up_info.uname, desp: season.evaluate, pic: epi.cover)
            }
        } else {
            setPlayerInfo(title: data?.title, subTitle: data?.ownerName, desp: data?.View.desc, pic: data?.pic)
        }

        return true
    }

    private func requestAreaLimitPcgPlayUrl(epid: Int, cid: Int, areaList: [String]) async throws -> VideoPlayURLInfo? {
        for area in areaList {
            do {
                return try await WebRequest.requestAreaLimitPcgPlayUrl(epid: epid, cid: cid, area: area)
            } catch let err {
                if area == areaList.last {
                    throw err
                } else {
                    print(err)
                }
            }
        }

        return nil
    }

    private func parseAreaByTitle(title: String) -> [String] {
        if title.isMatch(pattern: "[仅|僅].*[东南亚|其他]") {
            // TODO: 未支持
            return []
        }

        var areas: [String] = []
        if title.isMatch(pattern: "僅.*台") {
            areas.append("tw")
        }
        if title.isMatch(pattern: "僅.*港") {
            areas.append("hk")
        }

        if areas.isEmpty {
            // 标题没有地区限制信息，返回尝试检测的区域
            return ["tw", "hk"]
        } else {
            return areas
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
            guard let self else { return }
            if self.danMuView.isHidden { return }
            let seconds = time.seconds
            self.danmuProvider.playerTimeChange(time: seconds)

            if let duration = self.data?.View.duration {
                BiliBiliUpnpDMR.shared.sendProgress(duration: duration, current: Int(seconds))
            }

            if let clipInfos = self.clipInfos {
                var matched = false
                for clip in clipInfos {
                    if seconds > clip.start, seconds < clip.end {
                        let action = {
                            clip.skipped = true
                            self.player?.seek(to: CMTime(seconds: Double(clip.end), preferredTimescale: 1), toleranceBefore: .zero, toleranceAfter: .zero)
                        }
                        if !(clip.skipped ?? false), Settings.autoSkip {
                            action()
                            self.skipAction = nil
                        } else if self.skipAction?.accessibilityLabel != clip.a11Tag {
                            self.skipAction = UIAction(title: clip.customText) { _ in
                                action()
                            }
                            self.skipAction?.accessibilityLabel = clip.a11Tag
                        }

                        self.contextualActions = [self.skipAction].compactMap { $0 }
                        matched = true
                        break
                    }
                }
                if !matched {
                    self.contextualActions = []
                }
            }
        }
    }
}
