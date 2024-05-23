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

    private func fetchVideoData() async throws -> PlayerDetailData {
        assert(playInfo.isCidVaild)
        let aid = playInfo.aid
        let cid = playInfo.cid!
        let info = try? await WebRequest.requestPlayerInfo(aid: aid, cid: cid)
        do {
            let playData: VideoPlayURLInfo
            var clipInfos: [VideoPlayURLInfo.ClipInfo]?
            if playInfo.isBangumi {
                playData = try await WebRequest.requestPcgPlayUrl(aid: aid, cid: cid)
                clipInfos = playData.clip_info_list
            } else {
                playData = try await WebRequest.requestPlayUrl(aid: aid, cid: cid)
            }

            var detail = PlayerDetailData(aid: playInfo.aid, cid: playInfo.cid!, epid: playInfo.epid, isBangumi: playInfo.isBangumi, clips: clipInfos, playerInfo: info, videoPlayURLInfo: playData)

            if let info, info.last_play_cid == cid, playData.dash.duration - info.playTimeInSecond > 5, Settings.continuePlay {
                detail.playerStartPos = info.playTimeInSecond
            }

            return detail

            //        updatePlayerCharpter(playerInfo: playerInfo)

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
            } else if info?.is_upower_exclusive == true {
                throw "该视频为充电专属视频 \(err)"
            } else {
                throw err
            }
        }
    }

    @MainActor private func generatePlayerPlugin(_ data: PlayerDetailData) async -> [CommonPlayerPlugin] {
        let player = BVideoPlayPlugin(detailData: data)
        let danmu = DanmuViewPlugin(provider: danmuProvider)

        return [player, danmu]
    }
}
