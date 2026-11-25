//
//  LivePlayerViewModel.swift
//  BilibiliLive
//
//  Created by yicheng on 2024/5/13.
//

import Alamofire
import Foundation
import SwiftyJSON

enum LiveError: String, LocalizedError {
    case noLiving
    case noPlaybackUrl
    case fetchApiFail

    var errorDescription: String? {
        rawValue
    }
}

class LivePlayerViewModel {
    init(room: LiveRoom) {
        self.room = room
        roomID = room.room_id
    }

    deinit {
        danMuProvider?.stop()
    }

    var onPluginReady: (([CommonPlayerPlugin]) -> Void)?
    var onError: ((String) -> Void)?

    private let playPlugin = URLPlayPlugin(referer: Keys.liveReferer, isLive: true)
    private let debugPlugin = DebugPlugin()
    private var linePlugin: LineCandidatesPlugin?

    func start() {
        playPlugin.onPlayFail = { [weak self] in
            self?.playerDidFailToPlay()
        }

        debugPlugin.additionDebugInfo = { [weak self] in
            self?.debugInfo() ?? ""
        }

        onPluginReady?([playPlugin, debugPlugin])
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await refreshRoomsID()
                try await initPlayer()

                let danmu = await initDanmu()
                let linePlugin = LineCandidatesPlugin(candidates: allPlayInfos) { [weak self] url in
                    self?.playPlugin.play(urlString: url)
                }
                self.linePlugin = linePlugin
                onPluginReady?(danmu + [linePlugin])

                if let info = await fetchDespInfo() {
                    let subtitle = "\(room.ownerName)·\(info.parent_area_name) \(info.area_name)"
                    let desp = "\(info.description)\nTags:\(info.tags ?? "")"
                    let infoPlugin = BVideoInfoPlugin(title: info.title, subTitle: subtitle, desp: desp, pic: room.pic, viewPoints: nil)
                    onPluginReady?([infoPlugin])
                } else {
                    let infoPlugin = BVideoInfoPlugin(title: room.title, subTitle: nil, desp: nil, pic: room.pic, viewPoints: nil)
                    onPluginReady?([infoPlugin])
                }
            } catch let err {
                onError?(String(describing: err))
            }
        }
    }

    func playerDidFailToPlay() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                playInfos = Array(playInfos.dropFirst())
                if playInfos.isEmpty {
                    retryCount += 1
                    if retryCount > 3 {
                        onError?("播放失败")
                        return
                    }
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    try await initPlayer()
                    return
                } else {
                    try await playFirstInfo()
                }
            } catch let err {
                onError?(err.localizedDescription)
            }
        }
    }

    func debugInfo() -> String {
        return "\(allPlayInfos.first?.formate ?? "") \(allPlayInfos.first?.current_qn ?? 0) retry:\(retryCount)"
    }

    func fetchDespInfo() async -> WebRequest.LiveRoomInfo? {
        return try? await WebRequest.requestLiveBaseInfo(roomID: roomID)
    }

    // Private
    private var allPlayInfos = [LivePlayUrlInfo]()
    private var playInfos = [LivePlayUrlInfo]()
    private var roomID: Int
    private let room: LiveRoom
    private var danMuProvider: LiveDanMuProvider?
    private var retryCount = 0
    private var liveTime: String?

    private func refreshRoomsID() async throws {
        let info = try await WebRequest.requestLiveRoomInit(roomID: roomID)
        if info.live_status != 1 {
            throw LiveError.noLiving
        }
        roomID = info.room_id
        liveTime = info.live_time
    }

    private func initPlayer() async throws {
        let playurl = try await WebRequest.requestLivePlayUrl(roomID: roomID)
        allPlayInfos = playurl.buildSortedCandidates()
        Logger.debug("all info arry:\(allPlayInfos)")
        playInfos = allPlayInfos
        await MainActor.run {
            linePlugin?.updateCandidates(allPlayInfos)
        }
        try await playFirstInfo()
    }

    func playFirstInfo() async throws {
        if let info = playInfos.first {
            Logger.debug("play => \(playInfos)")
            await MainActor.run {
                playPlugin.play(urlString: info.url)
            }
        } else {
            throw LiveError.noPlaybackUrl
        }
    }

    @MainActor private func initDanmu() async -> [CommonPlayerPlugin] {
        danMuProvider = LiveDanMuProvider(roomID: roomID, removeDup: Settings.enableDanmuRemoveDup)
        let danmuPlugin = DanmuViewPlugin(provider: danMuProvider!)

        // Retrieve only the history for the current broadcast session
        let sessionKey = liveTime.flatMap { $0.hasPrefix("0000") ? nil : $0 } ?? "unknown"
        let historyStore = LiveDanmuHistoryStore(roomID: roomID, sessionKey: sessionKey)
        danMuProvider?.historyStore = historyStore
        Task { await historyStore.loadRemoteHistory() }

        try? await danMuProvider?.start()
        var plugins: [CommonPlayerPlugin] = [danmuPlugin, LiveDanmuHistoryPlugin(store: historyStore)]
        if Settings.danmuMask, Settings.vnMask {
            let plugin = MaskViewPugin(maskView: danmuPlugin.danMuView, maskProvider: VMaskProvider())
            plugins.append(plugin)
        }

        return plugins
    }
}

extension WebRequest.EndPoint {
    static let liveRoomInfo = "https://api.live.bilibili.com/room/v1/Room/get_info"
    static let liveRoomStream = "https://api.live.bilibili.com/xlive/web-room/v2/index/getRoomPlayInfo"
    static let liveRoomInit = "https://api.live.bilibili.com/room/v1/Room/room_init"
}

extension WebRequest {
    struct LiveRoomInfo: Codable {
        let description: String
        let parent_area_name: String
        let title: String
        let tags: String?
        let area_name: String
        let hot_words: [String]?
    }

    static func requestLiveBaseInfo(roomID: Int) async throws -> LiveRoomInfo {
        return try await request(url: EndPoint.liveRoomInfo, parameters: ["room_id": roomID])
    }

    struct LiveRoomInit: Codable {
        var live_status: Int
        var room_id: Int
        var live_time: String?
    }

    static func requestLiveRoomInit(roomID: Int) async throws -> LiveRoomInit {
        return try await request(url: EndPoint.liveRoomInfo, parameters: ["id": roomID])
    }

    static func requestLivePlayUrl(roomID: Int) async throws -> LivePlayUrlPayload {
        struct LiveRoomStreamInfo: Codable {
            let playurl_info: PlayUrlInfo

            struct PlayUrlInfo: Codable {
                let playurl: LivePlayUrlPayload
            }
        }
        let info: LiveRoomStreamInfo = try await request(url: EndPoint.liveRoomStream,
                                                         parameters: ["room_id": roomID,
                                                                      "protocol": "1",
                                                                      "format": "0,1,2",
                                                                      "codec": "0,1",
                                                                      "qn": "30000",
                                                                      "platform": "web",
                                                                      "ptype": "8",
                                                                      "dolby": "5",
                                                                      "panorama": 1])
        return info.playurl_info.playurl
    }
}
