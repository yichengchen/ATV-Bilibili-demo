//
//  BVideoPlayPlugin.swift
//  BilibiliLive
//
//  Created by yicheng on 2024/5/24.
//

import AVKit

class BVideoPlayPlugin: NSObject, CommonPlayerPlugin {
    private weak var playerVC: AVPlayerViewController?
    private var playerDelegate: BilibiliVideoResourceLoaderDelegate?
    private let playData: PlayerDetailData
    private var currentQualityId: Int?
    private var currentPlaybackTime: Double = 0

    init(detailData: PlayerDetailData) {
        playData = detailData
        currentQualityId = playData.videoPlayURLInfo.quality
    }

    func playerDidLoad(playerVC: AVPlayerViewController) {
        self.playerVC = playerVC
        playerVC.player = nil
        playerVC.appliesPreferredDisplayCriteriaAutomatically = Settings.contentMatch
        Task {
            try? await playmedia(urlInfo: playData.videoPlayURLInfo, playerInfo: playData.playerInfo)
        }
    }

    func playerWillStart(player: AVPlayer) {
        if let playerStartPos = playData.playerStartPos {
            player.seek(to: CMTime(seconds: Double(playerStartPos), preferredTimescale: 1), toleranceBefore: .zero, toleranceAfter: .zero)
        }
    }

    func playerDidDismiss(playerVC: AVPlayerViewController) {
        guard let currentTime = playerVC.player?.currentTime().seconds, currentTime > 0 else { return }
        WebRequest.reportWatchHistory(aid: playData.aid, cid: playData.cid, currentTime: Int(currentTime), epid: playData.epid, seasonId: playData.seasonId, subType: playData.subType)
    }

    @MainActor
    private func playmedia(urlInfo: VideoPlayURLInfo, playerInfo: PlayerInfo?, maxQuality: Int? = nil, streamIndex: Int? = nil, isQualitySwitch: Bool = false) async throws {
        let playURL = URL(string: BilibiliVideoResourceLoaderDelegate.URLs.play)!
        let headers: [String: String] = [
            "User-Agent": Keys.userAgent,
            "Referer": Keys.referer(for: playData.aid),
        ]
        let asset = AVURLAsset(url: playURL, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        playerDelegate = BilibiliVideoResourceLoaderDelegate()
        playerDelegate?.setBilibili(info: urlInfo, subtitles: playerInfo?.subtitle?.subtitles ?? [], aid: playData.aid, maxQuality: maxQuality, streamIndex: streamIndex)

        // 只在初次加载时设置 appliesPreferredDisplayCriteriaAutomatically，切换画质时跳过
        if !isQualitySwitch {
            if Settings.contentMatchOnlyInHDR {
                if playerDelegate?.isHDR != true {
                    playerVC?.appliesPreferredDisplayCriteriaAutomatically = false
                }
            }
        }

        asset.resourceLoader.setDelegate(playerDelegate, queue: DispatchQueue(label: "loader"))
        let playable = try await asset.load(.isPlayable)
        if !playable {
            throw "加载资源失败"
        }
        await prepare(toPlay: asset)
    }

    @MainActor
    func switchQuality(to qualityId: Int, streamIndex: Int?) async {
        guard let player = playerVC?.player else { return }

        let currentTime = player.currentTime().seconds
        guard currentTime > 0 else { return }

        // 保存当前播放位置
        currentPlaybackTime = currentTime
        currentQualityId = qualityId

        // 重新加载视频，使用新的画质
        do {
            try await playmedia(urlInfo: playData.videoPlayURLInfo, playerInfo: playData.playerInfo, maxQuality: qualityId, streamIndex: streamIndex, isQualitySwitch: true)

            // 恢复播放位置并继续播放
            if let newPlayer = playerVC?.player {
                await newPlayer.seek(to: CMTime(seconds: currentPlaybackTime, preferredTimescale: 1), toleranceBefore: .zero, toleranceAfter: .zero)
                newPlayer.play()
            }
        } catch {
            Logger.warn("[quality] Failed to switch quality: \(error)")
        }
    }

    @MainActor
    func prepare(toPlay asset: AVURLAsset) async {
        let playerItem = AVPlayerItem(asset: asset)

        // 设置 preferredPeakBitRate 为一个很高的值，让 AVPlayer 优先选择高码率流
        // 0 表示无限制，让 AVPlayer 根据网络条件自动选择最高可用码率
        playerItem.preferredPeakBitRate = 0

        let player = AVPlayer(playerItem: playerItem)
        playerVC?.player = player
    }
}
