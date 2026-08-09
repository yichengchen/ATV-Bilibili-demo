//
//  VideoPlayerViewModel.swift
//  BilibiliLive
//
//  Created by yicheng on 2024/5/23.
//

import Combine
import UIKit

struct PlayerDetailData {
    let aid: Int
    let cid: Int
    let epid: Int? // 港澳台解锁需要
    let seasonId: Int? // 番剧 season_id
    let subType: Int? // 0: 普通视频 1：番剧 2：电影 3：纪录片 4：国创 5：电视剧 7：综艺

    var playerStartPos: Int?
    var detail: VideoDetail?
    var clips: [VideoPlayURLInfo.ClipInfo]?
    var playerInfo: PlayerInfo?
    var videoPlayURLInfo: VideoPlayURLInfo

    var isBangumi: Bool {
        return epid ?? 0 > 0 || seasonId ?? 0 > 0
    }
}

@MainActor
class VideoPlayerViewModel {
    let loadResult = PassthroughSubject<Result<[CommonPlayerPlugin], String>, Never>()
    var onExit: (() -> Void)?
    var onPlayInfoChanged: ((PlayInfo) -> Void)?
    var onShowDetail: ((PlayInfo) -> Void)?
    var sequenceProvider: VideoSequenceProvider?

    private var playInfo: PlayInfo
    private let playMode: VideoPlayerMode
    private let playContextCache: PlayContextCache?
    private let mediaWarmupManager: PlayerMediaWarmupManager?
    private let previewMuted: Bool
    private let startTimeOverride: Int?
    private let startTimeOverrideContentIdentity: String
    private var videoDetail: VideoDetail?
    private var cancellable = Set<AnyCancellable>()
    private var loadTask: Task<Void, Never>?
    private var loadGeneration = 0

    init(playInfo: PlayInfo,
         playMode: VideoPlayerMode = .regular,
         playContextCache: PlayContextCache? = nil,
         mediaWarmupManager: PlayerMediaWarmupManager? = nil,
         previewMuted: Bool = true,
         startTimeOverride: Int? = nil)
    {
        self.playInfo = playInfo
        self.playMode = playMode
        self.playContextCache = playContextCache
        self.mediaWarmupManager = mediaWarmupManager
        self.previewMuted = previewMuted
        self.startTimeOverride = startTimeOverride
        startTimeOverrideContentIdentity = playInfo.contentIdentity
    }

    var currentPlayInfo: PlayInfo {
        playInfo
    }

    func load() {
        startLoad(for: playInfo)
    }

    func cancelLoading() {
        loadTask?.cancel()
        loadTask = nil
        loadGeneration += 1
    }

    private func startLoad(for requestedPlayInfo: PlayInfo) {
        loadTask?.cancel()
        loadGeneration += 1
        let generation = loadGeneration
        let task = Task { [weak self] in
            guard let self else { return }
            await performLoad(for: requestedPlayInfo, generation: generation)
        }
        loadTask = task
    }

    private func performLoad(for requestedPlayInfo: PlayInfo, generation: Int) async {
        defer {
            if loadGeneration == generation {
                loadTask = nil
            }
        }
        do {
            let (resolvedPlayInfo, data) = try await loadVideoInfo(for: requestedPlayInfo)
            guard !Task.isCancelled, loadGeneration == generation else { return }

            let danmuProvider = VideoDanmuProvider(enableDanmuFilter: Settings.enableDanmuFilter,
                                                   enableDanmuRemoveDup: Settings.enableDanmuRemoveDup)
            await danmuProvider.initVideo(cid: data.cid, startPos: data.playerStartPos ?? 0)
            guard !Task.isCancelled, loadGeneration == generation else { return }

            playInfo = resolvedPlayInfo
            videoDetail = data.detail
            BiliBiliUpnpDMR.shared.sendVideoSwitch(aid: resolvedPlayInfo.aid, cid: data.cid)
            cancellable.removeAll()
            let plugins = generatePlayerPlugin(data,
                                               playInfo: resolvedPlayInfo,
                                               danmuProvider: danmuProvider)
            guard !Task.isCancelled, loadGeneration == generation else { return }
            loadResult.send(.success(plugins))
        } catch is CancellationError {
            return
        } catch let err {
            guard !Task.isCancelled, loadGeneration == generation else { return }
            loadResult.send(.failure(err.localizedDescription))
        }
    }

    private func loadVideoInfo(for playInfo: PlayInfo) async throws -> (PlayInfo, PlayerDetailData) {
        let resolvedPlayInfo = try await PlayInfoResolver.resolve(playInfo)
        try Task.checkCancellation()
        let data = try await fetchVideoData(for: resolvedPlayInfo)
        try Task.checkCancellation()
        return (resolvedPlayInfo, data)
    }

    private func fetchVideoDetail(aid: Int, existing: VideoDetail?) async -> VideoDetail? {
        if let existing { return existing }
        return try? await WebRequest.requestDetailVideo(aid: aid)
    }

    private func fetchVideoData(for playInfo: PlayInfo) async throws -> PlayerDetailData {
        assert(playInfo.isCidVaild)
        let existingVideoDetail = videoDetail?.View.aid == playInfo.aid ? videoDetail : nil
        if !playInfo.isBangumi, let playContextCache {
            let cached = try await playContextCache.context(for: playInfo, mode: playContextMode)
            let resolvedDetail = cached.detail ?? existingVideoDetail

            var detail = PlayerDetailData(aid: playInfo.aid,
                                          cid: cached.cid,
                                          epid: playInfo.epid,
                                          seasonId: playInfo.seasonId,
                                          subType: playInfo.subType,
                                          detail: resolvedDetail,
                                          clips: nil,
                                          playerInfo: cached.playerInfo,
                                          videoPlayURLInfo: cached.videoPlayURLInfo)

            let lastPlayCid = playInfo.lastPlayCid ?? cached.playerInfo?.last_play_cid ?? 0
            let playTimeInSecond = playInfo.playTimeInSecond ?? cached.playerInfo?.playTimeInSecond ?? 0
            detail.playerStartPos = resolvedPlayerStartPos(cid: cached.cid,
                                                           duration: cached.videoPlayURLInfo.dash.duration,
                                                           lastPlayCid: lastPlayCid,
                                                           playTimeInSecond: playTimeInSecond,
                                                           playInfo: playInfo)
            return detail
        }

        let aid = playInfo.aid
        let cid = playInfo.cid!
        async let infoReq = try? WebRequest.requestPlayerInfo(aid: aid, cid: cid)
        async let detailReq = fetchVideoDetail(aid: aid, existing: existingVideoDetail)
        do {
            let playData: VideoPlayURLInfo
            var clipInfos: [VideoPlayURLInfo.ClipInfo]?

            if playInfo.isBangumi {
                do {
                    playData = try await WebRequest.requestPcgPlayUrl(aid: aid, cid: cid, options: playContextMode.requestOptions)
                } catch let err as RequestError {
                    if case let .statusFail(code, _) = err,
                       code == -404 || code == -10403,
                       let data = try await fetchAreaLimitPcgVideoData(for: playInfo)
                    {
                        playData = data
                    } else {
                        throw err
                    }
                }

                clipInfos = playData.clip_info_list
            } else {
                playData = try await WebRequest.requestPlayUrl(aid: aid, cid: cid, options: playContextMode.requestOptions)
            }

            let info = await infoReq
            let resolvedDetail = await detailReq

            var detail = PlayerDetailData(aid: playInfo.aid, cid: playInfo.cid!, epid: playInfo.epid, seasonId: playInfo.seasonId, subType: playInfo.subType, detail: resolvedDetail, clips: clipInfos, playerInfo: info, videoPlayURLInfo: playData)

            let last_play_cid = playInfo.lastPlayCid ?? info?.last_play_cid ?? 0
            let playTimeInSecond = playInfo.playTimeInSecond ?? info?.playTimeInSecond ?? 0
            detail.playerStartPos = resolvedPlayerStartPos(cid: cid,
                                                           duration: playData.dash.duration,
                                                           lastPlayCid: last_play_cid,
                                                           playTimeInSecond: playTimeInSecond,
                                                           playInfo: playInfo)

            return detail

        } catch let err {
            if case let .statusFail(code, message) = err as? RequestError {
                throw "\(code) \(message)，可能需要大会员"
            } else if await infoReq?.is_upower_exclusive == true {
                throw "该视频为充电专属视频 \(err)"
            } else {
                throw err
            }
        }
    }

    private func updatePlayInfo(_ newPlayInfo: PlayInfo) {
        playInfo = newPlayInfo
        onPlayInfoChanged?(newPlayInfo)
        startLoad(for: newPlayInfo)
    }

    private func resolvedPlayerStartPos(cid: Int,
                                        duration: Int,
                                        lastPlayCid: Int,
                                        playTimeInSecond: Int,
                                        playInfo: PlayInfo) -> Int?
    {
        if let startTimeOverride,
           startTimeOverrideContentIdentity == playInfo.contentIdentity,
           duration - startTimeOverride > 5
        {
            return startTimeOverride
        }
        if lastPlayCid == cid,
           duration - playTimeInSecond > 5,
           Settings.continuePlay
        {
            return playTimeInSecond
        }
        return nil
    }

    func retryCurrent() {
        load()
    }

    func playNextFromSequence() async -> Bool {
        guard let next = await sequenceProvider?.moveNext() else { return false }
        updatePlayInfo(next)
        return true
    }

    func playPreviousFromSequence() async -> Bool {
        guard let previous = sequenceProvider?.movePrevious() else { return false }
        updatePlayInfo(previous)
        return true
    }

    func playTemporaryOverride(_ temporaryPlayInfo: PlayInfo) {
        guard temporaryPlayInfo.sequenceKey != currentPlayInfo.sequenceKey else { return }
        sequenceProvider.map { provider in
            MainActor.assumeIsolated {
                provider.pushTemporary(temporaryPlayInfo)
            }
        }
        updatePlayInfo(temporaryPlayInfo)
    }

    func preloadNeighborsIfNeeded() async {
        guard playMode == .feedFlow, let playContextCache, let sequenceProvider else { return }
        let current = sequenceProvider.current() ?? currentPlayInfo
        let priority = [current,
                        sequenceProvider.peekNext(),
                        sequenceProvider.peekPrevious()].compactMap { $0 }.uniqued()
        for info in priority {
            guard !Task.isCancelled else { return }
            await playContextCache.preload(playInfo: info, mode: .regular)
        }
        guard !Task.isCancelled else { return }
        await playContextCache.trim(keeping: priority)
        for info in priority {
            guard !Task.isCancelled else { return }
            await mediaWarmupManager?.preload(playInfo: info)
        }
    }

    private func generatePlayerPlugin(_ data: PlayerDetailData,
                                      playInfo: PlayInfo,
                                      danmuProvider: VideoDanmuProvider) -> [CommonPlayerPlugin]
    {
        let playplugin = BVideoPlayPlugin(playInfo: playInfo,
                                          detailData: data,
                                          reportWatchHistory: playMode != .preview,
                                          minimizeStalling: true,
                                          isMuted: playMode == .preview && previewMuted,
                                          mediaWarmupManager: playMode == .feedFlow ? mediaWarmupManager : nil)
        playplugin.onLoadFailure = { [weak self] message in
            self?.loadResult.send(.failure(message))
        }

        if playMode == .preview {
            return [playplugin]
        }

        let danmu = DanmuViewPlugin(provider: danmuProvider)
        let upnp = BUpnpPlugin(duration: data.detail?.View.duration)
        let debug = DebugPlugin()
        debug.additionDebugInfo = { [weak playplugin] in
            playplugin?.networkDebugInfo ?? ""
        }
        let playSpeed = SpeedChangerPlugin()
        playSpeed.$currentPlaySpeed.sink { [weak danmu] speed in
            danmu?.danMuView.playingSpeed = speed.value
        }.store(in: &cancellable)

        let playlist = VideoPlayListPlugin(sequenceProvider: sequenceProvider)
        playlist.onPlayEnd = { [weak self] in
            guard self?.playMode == .regular else { return }
            self?.onExit?()
        }
        playlist.onPlayNextWithInfo = {
            [weak self] info in
            guard let self else { return }
            updatePlayInfo(info)
        }
        playlist.onShowCurrentDetail = { [weak self] info in
            self?.onShowDetail?(info)
        }

        // SpeedChangerPlugin creates the shared settings menu that later plugins extend.
        var plugins: [CommonPlayerPlugin] = [playSpeed, playplugin, danmu, upnp, debug, playlist]

        if !data.isBangumi, let detail = data.detail {
            let infoTabs = VideoPlayerInfoTabsPlugin(detail: detail,
                                                     currentPlayInfo: playInfo,
                                                     sequenceProvider: sequenceProvider)
            infoTabs.onSelectDiscovery = { [weak self] info in
                self?.playTemporaryOverride(info)
            }
            plugins.append(infoTabs)
        }

        // 添加画质选择器插件
        let qualitySelector = BVideoQualityPlugin(detailData: data) { [weak playplugin] qualityId, streamIndex in
            Task { @MainActor in
                await playplugin?.switchQuality(to: qualityId, streamIndex: streamIndex)
            }
        }

        plugins.append(qualitySelector)

        if let clips = data.clips {
            let clip = BVideoClipsPlugin(clipInfos: clips)
            plugins.append(clip)
        }

        if Settings.enableSponsorBlock != .none, let bvid = data.detail?.View.bvid, let duration = data.detail?.View.duration {
            let sponsor = SponsorSkipPlugin(bvid: bvid, duration: duration)
            plugins.append(sponsor)
        }

        if Settings.danmuMask {
            if let mask = data.playerInfo?.dm_mask,
               let video = data.videoPlayURLInfo.dash.video.first,
               mask.fps > 0
            {
                let maskProvider = BMaskProvider(info: mask, videoSize: CGSize(width: video.width ?? 0, height: video.height ?? 0))
                plugins.append(MaskViewPugin(maskView: danmu.danMuView, maskProvider: maskProvider))
            } else if Settings.vnMask {
                let maskProvider = VMaskProvider()
                plugins.append(MaskViewPugin(maskView: danmu.danMuView, maskProvider: maskProvider))
            }
        }

        // 默认视频标题作主标题 up主用户名作副标题
        if let detail = data.detail {
            var title = detail.title
            var subTitle = detail.ownerName
            // 分页播放时则以分页标题作主标题 up主用户名+视频标题作副标题
            let pages = detail.View.pages ?? []
            if pages.count > 1, let index = pages.firstIndex(where: { $0.cid == playInfo.cid }) {
                let page = pages[index]
                title = page.part
                subTitle += "·\(detail.title)"
            }
            let infoPlugin = BVideoInfoPlugin(title: title, subTitle: subTitle, desp: detail.View.desc, pic: detail.pic, viewPoints: data.playerInfo?.view_points)
            plugins.append(infoPlugin)
            Logger.debug("updateInfoPlugin: title: \(title) subTitle: \(subTitle)")
        }

        return plugins
    }

    private var playContextMode: PlayContextMode {
        switch playMode {
        case .preview:
            return .preview
        case .regular, .feedFlow:
            return .regular
        }
    }
}

// 港澳台解锁
extension VideoPlayerViewModel {
    private func fetchAreaLimitPcgVideoData(for playInfo: PlayInfo) async throws -> VideoPlayURLInfo? {
        guard Settings.areaLimitUnlock else { return nil }
        guard let epid = playInfo.epid, epid > 0 else { return nil }

        let season = try await WebRequest.requestBangumiSeasonView(epid: epid)
        let checkTitle = season.title.contains("僅") ? season.title : season.series_title
        let checkAreaList = parseAreaByTitle(title: checkTitle)
        guard !checkAreaList.isEmpty else { return nil }

        let playData = try await requestAreaLimitPcgPlayUrl(epid: epid, cid: playInfo.cid!, areaList: checkAreaList)
        return playData
    }

    private func requestAreaLimitPcgPlayUrl(epid: Int, cid: Int, areaList: [String]) async throws -> VideoPlayURLInfo? {
        for area in areaList {
            do {
                return try await WebRequest.requestAreaLimitPcgPlayUrl(epid: epid,
                                                                       cid: cid,
                                                                       area: area,
                                                                       options: playContextMode.requestOptions)
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
