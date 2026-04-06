//
//  NewVideoPlayerViewModel.swift
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
    let isBangumi: Bool

    var playerStartPos: Int?
    var detail: VideoDetail?
    var clips: [VideoPlayURLInfo.ClipInfo]?
    var playerInfo: PlayerInfo?
    var videoPlayURLInfo: VideoPlayURLInfo
}

class VideoPlayerViewModel {
    var onPluginReady = PassthroughSubject<[CommonPlayerPlugin], String>()
    var onPluginRemove = PassthroughSubject<CommonPlayerPlugin, Never>()
    var onExit: (() -> Void)?
    var nextProvider: VideoNextProvider?

    private var playInfo: PlayInfo
    private let danmuProvider = VideoDanmuProvider(enableDanmuFilter: Settings.enableDanmuFilter,
                                                   enableDanmuRemoveDup: Settings.enableDanmuRemoveDup)
    private var videoDetail: VideoDetail?
    private var cancellable = Set<AnyCancellable>()
    private var playPlugin: BVideoPlayPlugin?
    private var infoPlugin: BVideoInfoPlugin?
    private var qualityPlugin: QualitySelectionPlugin?

    init(playInfo: PlayInfo) {
        self.playInfo = playInfo
    }

    func load() async {
        do {
            let data = try await loadVideoInfo()
            let plugin = await generatePlayerPlugin(data)
            onPluginReady.send(plugin)
        } catch let err {
            onPluginReady.send(completion: .failure(err.localizedDescription))
        }
    }

    private func loadVideoInfo() async throws -> PlayerDetailData {
        try await initPlayInfo()
        let data = try await fetchVideoData()
        await danmuProvider.initVideo(cid: data.cid, startPos: data.playerStartPos ?? 0)
        return data
    }

    private func initPlayInfo() async throws {
        if !playInfo.isCidVaild {
            playInfo.cid = try await WebRequest.requestCid(aid: playInfo.aid)
        }
        BiliBiliUpnpDMR.shared.sendVideoSwitch(aid: playInfo.aid, cid: playInfo.cid ?? 0)
    }

    private func updateVideoDetailIfNeeded() async {
        if videoDetail == nil || videoDetail?.View.aid != playInfo.aid {
            videoDetail = try? await WebRequest.requestDetailVideo(aid: playInfo.aid)
        }
    }

    private func fetchVideoData() async throws -> PlayerDetailData {
        assert(playInfo.isCidVaild)
        let aid = playInfo.aid
        guard let cid = playInfo.cid else {
            throw "Video cid is missing"
        }
        async let infoReq = try? WebRequest.requestPlayerInfo(aid: aid, cid: cid)
        async let detailUpdate: () = updateVideoDetailIfNeeded()
        do {
            let playData: VideoPlayURLInfo
            var clipInfos: [VideoPlayURLInfo.ClipInfo]?

            if playInfo.isBangumi {
                Logger.info("[Bangumi] 开始播放番剧: aid=\(aid), cid=\(cid), epid=\(String(describing: playInfo.epid))")
                do {
                    playData = try await WebRequest.requestPcgPlayUrl(aid: aid, cid: cid)
                    Logger.info("[Bangumi] 番剧播放URL获取成功")
                } catch let err as RequestError {
                    Logger.warn("[Bangumi] 番剧播放URL获取失败: \(err)")
                    if case let .statusFail(code, message) = err {
                        Logger.info("[Bangumi] 错误码: \(code), 消息: \(message)")
                        // 区域限制常见错误码: -404, -10403, 6002105
                        if code == -404 || code == -10403 || code == 6002105 {
                            Logger.info("[Bangumi] 检测到区域限制，尝试港澳台解锁")
                            if let data = try await fetchAreaLimitPcgVideoData() {
                                playData = data
                                Logger.info("[Bangumi] 港澳台解锁成功")
                            } else {
                                Logger.warn("[Bangumi] 港澳台解锁返回nil")
                                throw err
                            }
                        } else {
                            throw err
                        }
                    } else {
                        throw err
                    }
                }

                clipInfos = playData.clip_info_list
            } else {
                playData = try await WebRequest.requestPlayUrl(aid: aid, cid: cid)
            }

            let info = await infoReq
            _ = await detailUpdate

            var detail = PlayerDetailData(aid: playInfo.aid, cid: cid, epid: playInfo.epid, seasonId: playInfo.seasonId, isBangumi: playInfo.isBangumi, detail: videoDetail, clips: clipInfos, playerInfo: info, videoPlayURLInfo: playData)

            if let info, info.last_play_cid == cid, playData.dash.duration - info.playTimeInSecond > 5, Settings.continuePlay {
                detail.playerStartPos = info.playTimeInSecond
            }

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

    private func playNext(newPlayInfo: PlayInfo) {
        playInfo = newPlayInfo

        // 移除旧的播放、清晰度和信息插件，确保插件不会累积
        if let playPlugin {
            Logger.debug("playNext: remove previous playPlugin: \(playPlugin)")
            onPluginRemove.send(playPlugin)
        }
        if let qualityPlugin {
            Logger.debug("playNext: remove previous qualityPlugin")
            onPluginRemove.send(qualityPlugin)
        }
        if let infoPlugin {
            Logger.debug("playNext: remove previous infoPlugin")
            onPluginRemove.send(infoPlugin)
        }

        Task {
            do {
                // 加载下一个视频数据
                let data = try await loadVideoInfo()

                // 初始化下一个视频播放器组件
                let player = BVideoPlayPlugin(detailData: data)
                playPlugin = player

                // 初始化清晰度选择插件
                let quality = QualitySelectionPlugin(playURLInfo: data.videoPlayURLInfo)
                quality.onQualityChange = { [weak self] newQn in
                    guard let self else { return }
                    Logger.info("[VideoPlayer] Quality change requested: \(newQn)")
                    self.reloadCurrentVideo()
                }
                qualityPlugin = quality

                // 创建新的信息插件
                let info = BVideoInfoPlugin()
                infoPlugin = info
                if let detail = data.detail {
                    var title = detail.title
                    var subTitle = detail.ownerName
                    let pages = detail.View.pages ?? []
                    if pages.count > 1, let index = pages.firstIndex(where: { $0.cid == playInfo.cid }) {
                        let page = pages[index]
                        title = page.part
                        subTitle += "·\(detail.title)"
                    }
                    info.title = title
                    info.subTitle = subTitle
                    info.desp = detail.View.desc
                    info.pic = detail.pic
                    info.viewPoints = data.playerInfo?.view_points
                    Logger.debug("playNext: setup infoPlugin - title: \(title), subTitle: \(subTitle)")
                }

                // 呈现新插件（包括 infoPlugin）
                onPluginReady.send([player, quality, info])
            } catch let err {
                Logger.warn("[VideoPlayer] playNext failed: \(err.localizedDescription)")
            }
        }
    }

    /// 重新加载当前视频（用于清晰度切换）
    private func reloadCurrentVideo() {
        // 移除旧的播放和清晰度插件
        if let playPlugin {
            Logger.debug("reloadCurrentVideo: remove previous playPlugin for quality change")
            onPluginRemove.send(playPlugin)
        }
        if let qualityPlugin {
            Logger.debug("reloadCurrentVideo: remove previous qualityPlugin")
            onPluginRemove.send(qualityPlugin)
        }

        Task {
            do {
                // 重新获取视频播放信息（会使用新的清晰度设置）
                let playData: VideoPlayURLInfo
                guard let cid = playInfo.cid else {
                    throw "Video cid is missing"
                }

                if playInfo.isBangumi {
                    playData = try await WebRequest.requestPcgPlayUrl(aid: playInfo.aid, cid: cid)
                } else {
                    playData = try await WebRequest.requestPlayUrl(aid: playInfo.aid, cid: cid)
                }

                // 构建新的播放数据
                var newData = PlayerDetailData(
                    aid: playInfo.aid,
                    cid: cid,
                    epid: playInfo.epid,
                    seasonId: playInfo.seasonId,
                    isBangumi: playInfo.isBangumi,
                    detail: videoDetail,
                    clips: nil,
                    playerInfo: nil,
                    videoPlayURLInfo: playData
                )
                // 不设置起始位置，让播放器从当前位置继续（如果可能）
                newData.playerStartPos = nil

                // 初始化新播放器组件
                let player = BVideoPlayPlugin(detailData: newData)
                playPlugin = player

                // 初始化新的清晰度选择插件
                let quality = QualitySelectionPlugin(playURLInfo: playData)
                quality.onQualityChange = { [weak self] newQn in
                    guard let self else { return }
                    Logger.info("[VideoPlayer] Quality change requested: \(newQn)")
                    self.reloadCurrentVideo()
                }
                qualityPlugin = quality

                onPluginReady.send([player, quality])
                Logger.info("[VideoPlayer] Reloaded video with new quality: \(playData.quality)")
            } catch let err {
                Logger.warn("[VideoPlayer] Failed to reload video: \(err.localizedDescription)")
            }
        }
    }

    private func updateInfoPlugin(_ data: PlayerDetailData) {
        if let detail = data.detail, let infoPlugin {
            // 默认视频标题作主标题 up主用户名作副标题
            var title = detail.title
            var subTitle = detail.ownerName
            // 分页播放时则以分页标题作主标题 up主用户名+视频标题作副标题
            let pages = detail.View.pages ?? []
            if pages.count > 1, let index = pages.firstIndex(where: { $0.cid == playInfo.cid }) {
                let page = pages[index]
                title = page.part
                subTitle += "·\(detail.title)"
            }
            infoPlugin.title = title
            infoPlugin.subTitle = subTitle
            infoPlugin.desp = detail.View.desc
            infoPlugin.pic = detail.pic
            infoPlugin.viewPoints = data.playerInfo?.view_points
            Logger.debug("updateInfoPlugin: title: \(title) subTitle: \(subTitle)")
        }
    }

    @MainActor private func generatePlayerPlugin(_ data: PlayerDetailData) async -> [CommonPlayerPlugin] {
        let player = BVideoPlayPlugin(detailData: data)
        let danmu = DanmuViewPlugin(provider: danmuProvider)
        let upnp = BUpnpPlugin(duration: data.detail?.View.duration)
        let debug = DebugPlugin()
        let playSpeed = SpeedChangerPlugin()
        playSpeed.$currentPlaySpeed.sink { [weak danmu] speed in
            danmu?.danMuView.playingSpeed = speed.value
        }.store(in: &cancellable)

        let playlist = VideoPlayListPlugin(nextProvider: nextProvider)
        playlist.onPlayEnd = { [weak self] in
            self?.onExit?()
        }
        playlist.onPlayNextWithInfo = {
            [weak self] info in
            guard let self else { return }
            playNext(newPlayInfo: info)
        }

        playPlugin = player

        // 清晰度选择插件
        let quality = QualitySelectionPlugin(playURLInfo: data.videoPlayURLInfo)
        quality.onQualityChange = { [weak self] newQn in
            guard let self else { return }
            Logger.info("[VideoPlayer] Quality change requested: \(newQn)")
            // 重新加载当前视频以应用新清晰度
            self.reloadCurrentVideo()
        }
        qualityPlugin = quality

        var plugins: [CommonPlayerPlugin] = [player, danmu, playSpeed, upnp, debug, playlist, quality]

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

        infoPlugin = BVideoInfoPlugin()
        updateInfoPlugin(data)
        if let infoPlugin {
            plugins.append(infoPlugin)
        }

        return plugins
    }
}

// 港澳台解锁
extension VideoPlayerViewModel {
    private func fetchAreaLimitPcgVideoData() async throws -> VideoPlayURLInfo? {
        Logger.info("[AreaLimit] 检查港澳台解锁状态: \(Settings.areaLimitUnlock)")
        guard Settings.areaLimitUnlock else {
            Logger.debug("[AreaLimit] 港澳台解锁未启用")
            return nil
        }
        guard let epid = playInfo.epid, epid > 0 else {
            Logger.debug("[AreaLimit] 无有效epid: \(String(describing: playInfo.epid))")
            return nil
        }

        Logger.info("[AreaLimit] 获取番剧信息: epid=\(epid)")
        let season = try await WebRequest.requestBangumiSeasonView(epid: epid)
        let checkTitle = season.title.contains("僅") ? season.title : season.effectiveSeriesTitle
        Logger.info("[AreaLimit] 番剧标题: \(checkTitle)")
        let checkAreaList = parseAreaByTitle(title: checkTitle)
        Logger.info("[AreaLimit] 解析区域列表: \(checkAreaList)")
        guard !checkAreaList.isEmpty else {
            Logger.debug("[AreaLimit] 无需解锁区域")
            return nil
        }

        guard let cid = playInfo.cid else {
            Logger.warn("[AreaLimit] 无有效cid")
            return nil
        }
        Logger.info("[AreaLimit] 开始请求: epid=\(epid), cid=\(cid), areas=\(checkAreaList)")
        let playData = try await requestAreaLimitPcgPlayUrl(epid: epid, cid: cid, areaList: checkAreaList)
        return playData
    }

    private func requestAreaLimitPcgPlayUrl(epid: Int, cid: Int, areaList: [String]) async throws -> VideoPlayURLInfo? {
        for area in areaList {
            Logger.info("[AreaLimit] 尝试区域: \(area)")
            do {
                let result = try await WebRequest.requestAreaLimitPcgPlayUrl(epid: epid, cid: cid, area: area)
                Logger.info("[AreaLimit] 区域 \(area) 请求成功")
                return result
            } catch let err {
                Logger.warn("[AreaLimit] 区域 \(area) 请求失败: \(err)")
                if area == areaList.last {
                    Logger.warn("[AreaLimit] 所有区域尝试失败，抛出最后错误")
                    throw err
                } else {
                    Logger.debug("[AreaLimit] 继续尝试下一个区域...")
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
