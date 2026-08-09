//
//  BVideoPlayPlugin.swift
//  BilibiliLive
//
//  Created by yicheng on 2024/5/24.
//

import AVKit
import UIKit

class BVideoPlayPlugin: NSObject, CommonPlayerPlugin {
    var onLoadFailure: ((String) -> Void)?

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
    // 记录最近一次实际用于加载的 maxQuality/streamIndex，host 切换时原样复用，
    // 不去动用户当前的画质模式（自动多档 fallback 还是手动锁定某一档）
    private var lastMaxQuality: Int?
    private var lastStreamIndex: Int?

    private var networkLogTimer: Timer?
    private var lastStalls = 0
    private var lastDroppedFrames = 0
    private var cdnProbeReport = ""
    private var isProbingCDN = false

    // 运行时 CDN 健康检测：只在真实卡顿时换 host，不用 observed/indicated 比特率比
    // （indicated 常是峰值 BANDWIDTH，播放流畅时 observed 低于它完全正常）
    private var stallUnhealthyStreak = 0
    private var isEvaluatingHostSwitch = false
    private var lastHostSwitchAt: Date?
    /// 连续几次处于卡顿/等待缓冲才触发，避免单次抖动
    private let stallTriggerCount = 2
    /// 换完 host 后的冷静期，避免连续误触发
    private let hostSwitchCooldown: TimeInterval = 30
    private let networkLogInterval: TimeInterval = 5
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

    deinit {
        networkLogTimer?.invalidate()
    }

    /// 供 DebugPlugin 浮层显示的网络诊断信息
    var networkDebugInfo: String {
        var lines = [String]()
        if let host = playerDelegate?.currentSegmentHost {
            lines.append("segment host: \(host)")
        }
        if !cdnProbeReport.isEmpty {
            lines.append(cdnProbeReport)
        }
        return lines.joined(separator: "\n")
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

    func playerDidStart(player _: AVPlayer) {
        startNetworkLogging()
    }

    func playerDidCleanUp(player: AVPlayer) {
        stopNetworkLogging()
        player.pause()
        player.replaceCurrentItem(with: nil)
    }

    func addMenuItems(current: inout [UIMenuElement]) -> [UIMenuElement] {
        // 挂进「播放设置」，与 Debug 并列（依赖 SpeedChangerPlugin 先创建 setting 菜单）
        let action = UIAction(title: isProbingCDN ? "CDN 测速中…" : "CDN 测速",
                              image: UIImage(systemName: "speedometer"))
        { [weak self] _ in
            self?.probeCDN()
        }
        if let setting = current.compactMap({ $0 as? UIMenu })
            .first(where: { $0.identifier == UIMenu.Identifier(rawValue: "setting") }),
            let index = current.firstIndex(of: setting)
        {
            current[index] = setting.replacingChildren(setting.children + [action])
            return []
        }
        return []
    }

    private func probeCDN() {
        guard !isProbingCDN else { return }
        let candidates = playerDelegate?.cdnCandidates ?? []
        guard !candidates.isEmpty else {
            cdnProbeReport = "无候选 CDN"
            return
        }
        let currentHost = playerDelegate?.currentSegmentHost
        isProbingCDN = true
        cdnProbeReport = "CDN 测速中…"
        Task { @MainActor [weak self] in
            let report = await CDNDiagnostics.run(urls: candidates, currentHost: currentHost)
            self?.cdnProbeReport = report
            self?.isProbingCDN = false
        }
    }

    private func startNetworkLogging() {
        guard networkLogTimer == nil else { return }
        networkLogTimer = Timer.scheduledTimer(withTimeInterval: networkLogInterval, repeats: true) { [weak self] _ in
            self?.logNetworkStatus()
        }
    }

    private func stopNetworkLogging() {
        networkLogTimer?.invalidate()
        networkLogTimer = nil
    }

    private func logNetworkStatus() {
        guard let player = playerVC?.player,
              let item = player.currentItem,
              let event = item.accessLog()?.events.last
        else { return }
        // event.uri 是内部 variant playlist 的地址（我们用的是自定义 atv://dash/N scheme），
        // 解析出来的 host 恒为 "dash"，跟实际连的 CDN 无关；真实 host 记录在 playerDelegate 里。
        let host = playerDelegate?.currentSegmentHost ?? "-"
        let observedBps = event.observedBitrate
        let indicatedBps = event.indicatedBitrate
        let effectiveIndicated = effectiveIndicatedBitrate(from: indicatedBps)
        let observed = String(format: "%.1f", observedBps / 1_000_000)
        let indicated = String(format: "%.1f", indicatedBps / 1_000_000)
        let effective = String(format: "%.1f", effectiveIndicated / 1_000_000)
        let stalls = event.numberOfStalls
        let dropped = event.numberOfDroppedVideoFrames
        let tcs = player.timeControlStatus
        let waiting = player.reasonForWaitingToPlay?.rawValue ?? "-"
        let keepUp = item.isPlaybackLikelyToKeepUp
        let buffered = bufferedSeconds(of: item)
        let stallDelta = stalls - lastStalls
        Logger.info("playback host \(host) observed \(observed)Mbps indicated \(indicated)Mbps effective \(effective)Mbps stalls \(stalls)(+\(stallDelta)) dropped \(dropped)(+\(dropped - lastDroppedFrames)) serverChanges \(event.numberOfServerAddressChanges) tcs \(tcs.rawValue) wait \(waiting) keepUp \(keepUp) buffered \(String(format: "%.1f", buffered))s")
        lastStalls = stalls
        lastDroppedFrames = dropped

        checkStallHealth(stallDelta: stallDelta, buffered: buffered, currentHost: host)
    }

    /// 用户明确暂停（.paused）。卡缓冲/断网时是 .waitingToPlayAtSpecifiedRate，仍应做健康检测。
    private var isUserPaused: Bool {
        playerVC?.player?.timeControlStatus == .paused
    }

    private var isWaitingToPlay: Bool {
        playerVC?.player?.timeControlStatus == .waitingToPlayAtSpecifiedRate
    }

    /// access log 的 indicated 在起播/loading 时常为 0 或负值；日志里的 effective 用流声明平均带宽兜底。
    private func effectiveIndicatedBitrate(from accessLogIndicated: Double) -> Double {
        if accessLogIndicated > 0 { return accessLogIndicated }
        guard let declared = playerDelegate?.primaryVideoBandwidth, declared > 0 else { return 0 }
        return Double(declared)
    }

    private func bufferedSeconds(of item: AVPlayerItem) -> Double {
        guard let range = item.loadedTimeRanges.first?.timeRangeValue else { return 0 }
        let end = range.start.seconds + range.duration.seconds
        let current = item.currentTime().seconds
        guard end.isFinite, current.isFinite else { return 0 }
        return max(0, end - current)
    }

    /// 只根据真实卡顿触发换源：正在 waiting，或本周期新增了 stall。
    /// 播放流畅时仅 observed < indicated 不触发——indicated 常是峰值，低一些完全正常。
    private func checkStallHealth(stallDelta: Int, buffered: Double, currentHost: String) {
        guard !isUserPaused, !isEvaluatingHostSwitch else {
            stallUnhealthyStreak = 0
            return
        }
        if let lastSwitch = lastHostSwitchAt, Date().timeIntervalSince(lastSwitch) < hostSwitchCooldown {
            return
        }

        let unhealthy = isWaitingToPlay || stallDelta > 0
        if unhealthy {
            stallUnhealthyStreak += 1
        } else {
            stallUnhealthyStreak = 0
            return
        }
        guard stallUnhealthyStreak >= stallTriggerCount else { return }
        stallUnhealthyStreak = 0

        let requiredMbps = Double(playerDelegate?.primaryVideoBandwidth ?? 0) / 1_000_000
        Logger.info("[cdn] 检测到卡顿 (waiting=\(isWaitingToPlay), stallDelta=\(stallDelta), buffered \(String(format: "%.1f", buffered))s)，重新测速")
        Task { @MainActor [weak self] in
            await self?.evaluateHostSwitch(currentHost: currentHost, requiredMbps: requiredMbps)
        }
    }

    @MainActor
    private func evaluateHostSwitch(currentHost: String, requiredMbps: Double) async {
        guard !isEvaluatingHostSwitch else { return }
        guard !isUserPaused else { return }
        let candidates = playerDelegate?.cdnCandidates ?? []
        guard candidates.count > 1 else { return }
        isEvaluatingHostSwitch = true
        defer { isEvaluatingHostSwitch = false }

        Logger.info("[cdn] \(currentHost) 因卡顿重新测速 \(candidates.count) 个候选")
        let results = await CDNDiagnostics.probeAll(urls: candidates)
        // 测速是异步的，期间用户可能已手动暂停；换源会重建 AVPlayer，必须取消
        guard !isUserPaused else {
            Logger.info("[cdn] 用户已暂停，取消 host 切换")
            return
        }
        let ranked = results.filter { $0.mbps != nil }.sorted { ($0.mbps ?? -1) > ($1.mbps ?? -1) }
        guard !ranked.isEmpty else {
            Logger.info("[cdn] 候选测速全部失败，保持 \(currentHost)")
            return
        }

        // 优先更快的非当前节点；若短测速仍显示当前最快，则取第二名做强制尝试
        let alternate = ranked.first(where: { $0.host != currentHost })
        guard let target = alternate, let targetMbps = target.mbps else {
            Logger.info("[cdn] 没有其他可用候选，保持 \(currentHost)")
            return
        }
        if requiredMbps > 0, targetMbps < requiredMbps * 0.5 {
            Logger.info("[cdn] 备选 \(target.host) (\(String(format: "%.1f", targetMbps))Mbps) 远低于流码率，放弃切换")
            return
        }

        let currentMbps = ranked.first(where: { $0.host == currentHost })?.mbps
        let reason: String
        if let currentMbps, targetMbps > currentMbps * 1.3 {
            reason = "测速明显更快"
        } else if let currentMbps, targetMbps >= currentMbps * 0.7 {
            // 短测速乐观且接近时，当前节点已真实卡顿，强制换一个试试
            reason = "测速接近但已卡顿，强制尝试"
        } else if currentMbps == nil {
            reason = "当前节点测速失败"
        } else {
            Logger.info("[cdn] 备选 \(target.host) (\(String(format: "%.1f", targetMbps))Mbps) 明显慢于当前 \(currentHost) (\(String(format: "%.1f", currentMbps!))Mbps)，保持")
            return
        }

        lastHostSwitchAt = Date()
        Logger.info("[cdn] 切换 host: \(currentHost) -> \(target.host) (实测\(String(format: "%.1f", targetMbps))Mbps, \(reason))")
        await switchHost(to: target.host)
    }

    @MainActor
    private func switchHost(to host: String) async {
        guard let player = playerVC?.player else { return }
        // 必须在换源前记下播放意图：新 AVPlayer 默认就是 .paused，换源后再读 isUserPaused 会误判成用户暂停
        let shouldResume = !isUserPaused
        guard shouldResume else {
            Logger.info("[cdn] 用户已暂停，取消 host 切换")
            return
        }
        let currentTime = player.currentTime().seconds
        guard currentTime > 0 else { return }
        currentPlaybackTime = currentTime

        // 关掉 readyToPlay 自动 play，改由下面按 shouldResume 显式 play；异步恢复默认，避开尚未送达的 status KVO
        let commonVC = playerVC?.parent as? CommonPlayerViewController
        commonVC?.autoPlayWhenReady = false
        defer {
            DispatchQueue.main.async {
                commonVC?.autoPlayWhenReady = true
            }
        }

        do {
            let generation = beginLoadGeneration()
            try await playmedia(urlInfo: playData.videoPlayURLInfo,
                                playerInfo: playData.playerInfo,
                                generation: generation,
                                maxQuality: lastMaxQuality,
                                streamIndex: lastStreamIndex,
                                preferredHost: host,
                                isQualitySwitch: true)
            if let newPlayer = playerVC?.player {
                await newPlayer.seek(to: CMTime(seconds: currentPlaybackTime, preferredTimescale: 1), toleranceBefore: .zero, toleranceAfter: .zero)
                if shouldResume {
                    newPlayer.play()
                } else {
                    newPlayer.pause()
                }
            }
        } catch {
            Logger.warn("[cdn] 切换 host 失败: \(error)")
        }
    }

    func playerDidDismiss(playerVC: AVPlayerViewController) {
        guard reportWatchHistory else { return }
        guard let currentTime = playerVC.player?.currentTime().seconds, currentTime > 0 else { return }
        WebRequest.reportWatchHistory(aid: playData.aid, cid: playData.cid, currentTime: Int(currentTime), epid: playData.epid, seasonId: playData.seasonId, subType: playData.subType)
    }

    /// 与资源加载器选主视频流的逻辑对齐，取出该流各 CDN host 的代表 URL，供起播轻量测速。
    private func primaryCDNCandidates(from info: VideoPlayURLInfo, maxQuality: Int?, streamIndex: Int?) -> [String] {
        var videos = info.dash.video
        if Settings.preferAvc {
            let videosMap = Dictionary(grouping: videos, by: { $0.id })
            for (key, values) in videosMap {
                if values.contains(where: { !$0.isHevc }) {
                    videos.removeAll(where: { $0.id == key && $0.isHevc })
                }
            }
        }
        if let streamIndex, streamIndex < info.dash.video.count {
            videos = [info.dash.video[streamIndex]]
        } else if let maxQuality {
            let matching = videos.filter { $0.id == maxQuality }
            if let best = matching.max(by: { $0.bandwidth < $1.bandwidth }) {
                videos = [best]
            } else {
                videos = matching
            }
        } else {
            let qualityLimit = Settings.mediaQuality.qn
            videos = videos.filter { $0.id <= qualityLimit }
            if let highest = videos.map(\.id).max() {
                videos = videos.filter { $0.id == highest }
            }
        }
        videos.sort { $0.bandwidth > $1.bandwidth }
        guard let primary = videos.first else { return [] }
        var seenHosts = Set<String>()
        return primary.playableURLs.filter { url in
            guard let host = URLComponents(string: url)?.host else { return false }
            return seenHosts.insert(host).inserted
        }
    }

    func playerWillCleanUp(playerVC: AVPlayerViewController) {
        invalidatePendingLoad(tearingDown: true)
    }

    private func startLoad(urlInfo: VideoPlayURLInfo,
                           playerInfo: PlayerInfo?,
                           maxQuality: Int? = nil,
                           streamIndex: Int? = nil,
                           isQualitySwitch: Bool = false)
    {
        let generation = beginLoadGeneration()
        loadTask = Task { @MainActor [weak self] in
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
                guard !Task.isCancelled,
                      self.loadGeneration == generation,
                      self.playerVC != nil
                else { return }
                Logger.warn("[player] Failed to prepare media: \(error)")
                self.onLoadFailure?(error.localizedDescription)
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
                           preferredHost: String? = nil,
                           isQualitySwitch: Bool = false) async throws
    {
        _ = try ensureActiveLoad(generation)
        let prepared = try await preparedMedia(urlInfo: urlInfo,
                                               playerInfo: playerInfo,
                                               maxQuality: maxQuality,
                                               streamIndex: streamIndex,
                                               preferredHost: preferredHost,
                                               isQualitySwitch: isQualitySwitch)
        // The await above may finish after a newer load generation. Validate
        // before retaining its resource-loader delegate or touching the player.
        let playerVC = try ensureActiveLoad(generation)
        let delegate = prepared.delegate
        let asset = prepared.asset
        playerDelegate = delegate

        // AVKit 不允许在同一场全屏播放里反复切换该属性，因此只在首次装配资源时计算一次。
        if !isQualitySwitch {
            playerVC.appliesPreferredDisplayCriteriaAutomatically = shouldApplyContentMatch(delegate: delegate)
        }

        await prepare(toPlay: asset, generation: generation)
    }

    private func preparedMedia(urlInfo: VideoPlayURLInfo,
                               playerInfo: PlayerInfo?,
                               maxQuality: Int?,
                               streamIndex: Int?,
                               preferredHost: String?,
                               isQualitySwitch: Bool) async throws -> PreparedPlayerMedia
    {
        if !isQualitySwitch,
           maxQuality == nil,
           streamIndex == nil,
           preferredHost == nil,
           let mediaWarmupManager
        {
            return try await mediaWarmupManager.preparedMedia(for: playInfo)
        }
        lastStalls = 0
        lastDroppedFrames = 0
        lastMaxQuality = maxQuality
        lastStreamIndex = streamIndex

        var resolvedHost = preferredHost
        if resolvedHost == nil {
            let candidates = primaryCDNCandidates(from: urlInfo, maxQuality: maxQuality, streamIndex: streamIndex)
            if let best = await CDNDiagnostics.pickFastestHost(urls: candidates) {
                resolvedHost = best
                Logger.info("[cdn] 起播选用 host: \(best)")
            }
        }

        return try await PlayerMediaFactory.prepare(aid: playData.aid,
                                                    urlInfo: urlInfo,
                                                    playerInfo: playerInfo,
                                                    maxQuality: maxQuality,
                                                    streamIndex: streamIndex,
                                                    preferredHost: resolvedHost)
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

        // 之前设成 60s 是为了扛 CDN 吞吐抖动，但 BANDWIDTH 声明错误的根因已修复，
        // 实测 CDN 吞吐充裕，不再需要这么激进的预缓冲。60s 在连续快进时的副作用是：
        // 每次 seek 都会立刻为新位置起一大批 60s 的 range 请求，下一个 seek 一来又整体取消重来，
        // 密集 seek 下网络连接层疲于开连接/取消，表现为长时间无响应。降到 15s 大幅减少这种抖动。
        playerItem.preferredForwardBufferDuration = 15

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
