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
    private let playInfo: PlayInfo
    private let playData: PlayerDetailData
    private let reportWatchHistory: Bool
    private let minimizeStalling: Bool
    private let isMuted: Bool
    private let mediaWarmupManager: PlayerMediaWarmupManager?
    private var currentQualityId: Int?
    private var currentPlaybackTime: Double = 0
    private var loadTask: Task<Void, Never>?
    private var loadGeneration = 0

    init(playInfo: PlayInfo,
         detailData: PlayerDetailData,
         reportWatchHistory: Bool = true,
         minimizeStalling: Bool = true,
         isMuted: Bool = false,
         mediaWarmupManager: PlayerMediaWarmupManager? = nil)
    {
        self.playInfo = playInfo
        playData = detailData
        self.reportWatchHistory = reportWatchHistory
        self.minimizeStalling = minimizeStalling
        self.isMuted = isMuted
        self.mediaWarmupManager = mediaWarmupManager
        currentQualityId = playData.videoPlayURLInfo.quality
    }

    func playerDidLoad(playerVC: AVPlayerViewController) {
        self.playerVC = playerVC
        playerVC.player = nil
        startLoad(urlInfo: playData.videoPlayURLInfo, playerInfo: playData.playerInfo)
    }

    func playerWillStart(player: AVPlayer) {
        if let playerStartPos = playData.playerStartPos {
            player.seek(to: CMTime(seconds: Double(playerStartPos), preferredTimescale: 1), toleranceBefore: .zero, toleranceAfter: .zero)
        }
    }

    func playerDidDismiss(playerVC: AVPlayerViewController) {
        guard reportWatchHistory else { return }
        guard let currentTime = playerVC.player?.currentTime().seconds, currentTime > 0 else { return }
        WebRequest.reportWatchHistory(aid: playData.aid, cid: playData.cid, currentTime: Int(currentTime), epid: playData.epid, seasonId: playData.seasonId, subType: playData.subType)
    }

    func playerWillCleanUp(playerVC: AVPlayerViewController) {
        invalidatePendingLoad(tearingDown: true)
    }

    func playerDidCleanUp(player: AVPlayer) {
        player.pause()
        player.replaceCurrentItem(with: nil)
    }

    private func startLoad(urlInfo: VideoPlayURLInfo,
                           playerInfo: PlayerInfo?,
                           maxQuality: Int? = nil,
                           streamIndex: Int? = nil,
                           isQualitySwitch: Bool = false)
    {
        let generation = beginLoadGeneration()
        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.playmedia(urlInfo: urlInfo,
                                         playerInfo: playerInfo,
                                         generation: generation,
                                         maxQuality: maxQuality,
                                         streamIndex: streamIndex,
                                         isQualitySwitch: isQualitySwitch)
            } catch is CancellationError {
                return
            } catch {
                Logger.warn("[player] Failed to prepare media: \(error)")
            }
        }
    }

    private func beginLoadGeneration() -> Int {
        loadTask?.cancel()
        loadTask = nil
        loadGeneration += 1
        return loadGeneration
    }

    private func invalidatePendingLoad(tearingDown: Bool) {
        loadTask?.cancel()
        loadTask = nil
        loadGeneration += 1
        playerDelegate = nil
        if tearingDown {
            playerVC = nil
        }
    }

    private func ensureActiveLoad(_ generation: Int) throws -> AVPlayerViewController {
        guard !Task.isCancelled,
              loadGeneration == generation,
              let playerVC
        else {
            throw CancellationError()
        }
        return playerVC
    }

    @MainActor
    private func playmedia(urlInfo: VideoPlayURLInfo,
                           playerInfo: PlayerInfo?,
                           generation: Int,
                           maxQuality: Int? = nil,
                           streamIndex: Int? = nil,
                           isQualitySwitch: Bool = false) async throws
    {
        let playerVC = try ensureActiveLoad(generation)
        let prepared = try await preparedMedia(urlInfo: urlInfo,
                                               playerInfo: playerInfo,
                                               maxQuality: maxQuality,
                                               streamIndex: streamIndex,
                                               isQualitySwitch: isQualitySwitch)
        let delegate = prepared.delegate
        let asset = prepared.asset
        playerDelegate = delegate

        // AVKit 不允许在同一场全屏播放里反复切换该属性，因此只在首次装配资源时计算一次。
        if !isQualitySwitch {
            playerVC.appliesPreferredDisplayCriteriaAutomatically = shouldApplyContentMatch(delegate: delegate)
        }

        try ensureActiveLoad(generation)
        await prepare(toPlay: asset, generation: generation)
    }

    private func preparedMedia(urlInfo: VideoPlayURLInfo,
                               playerInfo: PlayerInfo?,
                               maxQuality: Int?,
                               streamIndex: Int?,
                               isQualitySwitch: Bool) async throws -> PreparedPlayerMedia
    {
        if !isQualitySwitch,
           maxQuality == nil,
           streamIndex == nil,
           let mediaWarmupManager
        {
            return try await mediaWarmupManager.preparedMedia(for: playInfo)
        }
        return try await PlayerMediaFactory.prepare(aid: playData.aid,
                                                    urlInfo: urlInfo,
                                                    playerInfo: playerInfo,
                                                    maxQuality: maxQuality,
                                                    streamIndex: streamIndex)
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
            let generation = beginLoadGeneration()
            try await playmedia(urlInfo: playData.videoPlayURLInfo,
                                playerInfo: playData.playerInfo,
                                generation: generation,
                                maxQuality: qualityId,
                                streamIndex: streamIndex,
                                isQualitySwitch: true)

            // 恢复播放位置并继续播放
            guard loadGeneration == generation,
                  !Task.isCancelled,
                  playerVC != nil,
                  let newPlayer = playerVC?.player
            else { return }
            await newPlayer.seek(to: CMTime(seconds: currentPlaybackTime, preferredTimescale: 1), toleranceBefore: .zero, toleranceAfter: .zero)
            guard loadGeneration == generation, !Task.isCancelled else { return }
            newPlayer.play()
        } catch is CancellationError {
            return
        } catch {
            Logger.warn("[quality] Failed to switch quality: \(error)")
        }
    }

    private func shouldApplyContentMatch(delegate: BilibiliVideoResourceLoaderDelegate) -> Bool {
        guard Settings.contentMatch else { return false }
        guard Settings.contentMatchOnlyInHDR else { return true }
        return delegate.isHDR == true
    }

    @MainActor
    func prepare(toPlay asset: AVURLAsset, generation: Int) async {
        guard loadGeneration == generation,
              !Task.isCancelled,
              let playerVC
        else { return }
        let playerItem = AVPlayerItem(asset: asset)

        // 设置 preferredPeakBitRate 为一个很高的值，让 AVPlayer 优先选择高码率流
        // 0 表示无限制，让 AVPlayer 根据网络条件自动选择最高可用码率
        playerItem.preferredPeakBitRate = 0

        let player = AVPlayer(playerItem: playerItem)
        player.automaticallyWaitsToMinimizeStalling = minimizeStalling
        player.isMuted = isMuted
        guard loadGeneration == generation, !Task.isCancelled else {
            player.pause()
            player.replaceCurrentItem(with: nil)
            return
        }
        playerVC.player = nil
        guard loadGeneration == generation, !Task.isCancelled else {
            player.pause()
            player.replaceCurrentItem(with: nil)
            return
        }
        playerVC.player = player
    }
}
