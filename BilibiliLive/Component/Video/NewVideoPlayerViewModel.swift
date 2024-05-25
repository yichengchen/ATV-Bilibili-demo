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
    let isBangumi: Bool

    var playerStartPos: Int?
    var detail: VideoDetail?
    var clips: [VideoPlayURLInfo.ClipInfo]?
    var playerInfo: PlayerInfo?
    var videoPlayURLInfo: VideoPlayURLInfo
}

class NewVideoPlayerViewModel {
    var onPluginReady = PassthroughSubject<[CommonPlayerPlugin], String>()

    private var playInfo: PlayInfo
    private let danmuProvider = VideoDanmuProvider()
    private var videoDetail: VideoDetail?
    init(playInfo: PlayInfo) {
        self.playInfo = playInfo
    }

    func load() async {
        do {
            try await initPlayInfo()
            let data = try await fetchVideoData()
            await danmuProvider.initVideo(cid: data.cid, startPos: data.playerStartPos ?? 0)
            let plugin = await generatePlayerPlugin(data)
            onPluginReady.send(plugin)

        } catch let err {
            onPluginReady.send(completion: .failure(err.localizedDescription))
        }
    }

    private func initPlayInfo() async throws {
        if !playInfo.isCidVaild {
            playInfo.cid = try await WebRequest.requestCid(aid: playInfo.aid)
        }
        BiliBiliUpnpDMR.shared.sendVideoSwitch(aid: playInfo.aid, cid: playInfo.cid ?? 0)
    }

    private func updateVideoDetailIfNeeded() async {
        if videoDetail == nil {
            videoDetail = try? await WebRequest.requestDetailVideo(aid: playInfo.aid)
        }
    }

    private func fetchVideoData() async throws -> PlayerDetailData {
        assert(playInfo.isCidVaild)
        let aid = playInfo.aid
        let cid = playInfo.cid!
        async let infoReq = try? WebRequest.requestPlayerInfo(aid: aid, cid: cid)
        async let detailUpdate: () = updateVideoDetailIfNeeded()
        do {
            let playData: VideoPlayURLInfo
            var clipInfos: [VideoPlayURLInfo.ClipInfo]?

            if playInfo.isBangumi {
                playData = try await WebRequest.requestPcgPlayUrl(aid: aid, cid: cid)
                clipInfos = playData.clip_info_list
            } else {
                playData = try await WebRequest.requestPlayUrl(aid: aid, cid: cid)
            }

            let info = await infoReq
            _ = await detailUpdate

            var detail = PlayerDetailData(aid: playInfo.aid, cid: playInfo.cid!, epid: playInfo.epid, isBangumi: playInfo.isBangumi, detail: videoDetail, clips: clipInfos, playerInfo: info, videoPlayURLInfo: playData)

            if let info, info.last_play_cid == cid, playData.dash.duration - info.playTimeInSecond > 5, Settings.continuePlay {
                detail.playerStartPos = info.playTimeInSecond
            }

            return detail

        } catch let err {
            if case let .statusFail(code, message) = err as? RequestError {
                if code == -404 || code == -10403 {
//              解锁港澳台番剧处理
//                do {
//                    if let ok = try await fetchAreaLimitVideoData(), ok {
//                        return
//                    }
//                } catch let err {
//                }
                }
                throw "\(code) \(message)，可能需要大会员"
            } else if await infoReq?.is_upower_exclusive == true {
                throw "该视频为充电专属视频 \(err)"
            } else {
                throw err
            }
        }
    }

    @MainActor private func generatePlayerPlugin(_ data: PlayerDetailData) async -> [CommonPlayerPlugin] {
        let player = BVideoPlayPlugin(detailData: data)
        let danmu = DanmuViewPlugin(provider: danmuProvider)
        let upnp = BUpnpPlugin(duration: data.detail?.View.duration)
        let debug = DebugPlugin()
        var plugins: [CommonPlayerPlugin] = [player, danmu, upnp, debug]

        if let clips = data.clips {
            let clip = BVideoClipsPlugin(clipInfos: clips)
            plugins.append(clip)
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

        if let detail = data.detail {
            let info = BVideoInfoPlugin(title: detail.title, subTitle: detail.ownerName, desp: detail.View.desc, pic: detail.pic, viewPoints: data.playerInfo?.view_points)
            plugins.append(info)
        }

        return plugins
    }
}
