//
//  LiveInfoViewModel.swift
//  BilibiliLive
//
//  Created by yicheng on 2024/5/13.
//

import Alamofire
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
    init(roomID: Int) {
        self.roomID = roomID
    }

    deinit {
        danMuProvider?.stop()
    }

    var onShootDanmu: ((DanmakuTextCellModel) -> Void)?
    var onPlayUrlStr: ((String) -> Void)?
    var onError: ((String) -> Void)?

    func start() {
        Task {
            do {
                try await refreshRoomsID()
                try await initPlayer()
                await initDanmu()
            } catch let err {
                await MainActor.run {
                    onError?(err.localizedDescription)
                }
            }
        }
    }

    func playerDidFailToPlay() {
        Task {
            do {
                playInfos = Array(playInfos.dropFirst())
                if playInfos.isEmpty {
                    try await initPlayer()
                    return
                } else {
                    try await playFirstInfo()
                }
            } catch let err {
                await MainActor.run {
                    onError?(err.localizedDescription)
                }
            }
        }
    }

    func debugInfo() -> String {
        return "\(allPlayInfos.first?.formate ?? "") \(allPlayInfos.first?.current_qn ?? 0)"
    }

    func fetchDespInfo() async -> WebRequest.LiveRoomInfo? {
        return try? await WebRequest.requestLiveBaseInfo(roomID: roomID)
    }

    // Private
    private var allPlayInfos = [LivePlayUrlInfo]()
    private var playInfos = [LivePlayUrlInfo]()
    private var roomID: Int
    private var danMuProvider: LiveDanMuProvider?

    private func refreshRoomsID() async throws {
        let url = "https://api.live.bilibili.com/room/v1/Room/room_init?id=\(roomID)"
        let resp = await AF.request(url).serializingData().result
        switch resp {
        case let .success(object):
            let json = JSON(object)
            let isLive = json["data"]["live_status"].intValue == 1
            if !isLive {
                throw LiveError.noLiving
            }
            if let newID = json["data"]["room_id"].int {
                roomID = newID
            }
        case let .failure(error):
            throw error
        }
    }

    private func initPlayer() async throws {
        allPlayInfos = []
        let requestUrl = "https://api.live.bilibili.com/xlive/web-room/v2/index/getRoomPlayInfo?room_id=\(roomID)&protocol=1&format=0,1,2&codec=0,1&qn=10000&platform=web&ptype=8&dolby=5&panorama=1"
        guard let data = try? await AF.request(requestUrl).serializingData().result.get() else {
            throw LiveError.fetchApiFail
        }
        let json = JSON(data)

        for stream in json["data"]["playurl_info"]["playurl"]["stream"].arrayValue {
            for content in stream["format"].arrayValue {
                let formate = content["format_name"].stringValue
                let codecs = content["codec"].arrayValue

                for codec in codecs {
                    let qn = codec["current_qn"].intValue
                    let baseUrl = codec["base_url"].stringValue
                    for url_info in codec["url_info"].arrayValue {
                        let host = url_info["host"]
                        let extra = url_info["extra"]
                        let url = "\(host)\(baseUrl)\(extra)"
                        let playInfo = LivePlayUrlInfo(formate: formate, url: url, current_qn: qn)
                        allPlayInfos.append(playInfo)
                    }
                }
            }
        }

        allPlayInfos.sort { a, b in
            return a.current_qn ?? 0 > b.current_qn ?? 0
        }

        allPlayInfos.sort { a, b in
            return a.formate == "fmp4"
        }

        Logger.debug("all info arry:\(playInfos)")
        playInfos = allPlayInfos
        try await playFirstInfo()
    }

    func playFirstInfo() async throws {
        if let info = playInfos.first {
            Logger.debug("play =>", playInfos)
            await MainActor.run {
                onPlayUrlStr?(info.url)
            }
        } else {
            throw LiveError.noPlaybackUrl
        }
    }

    private func initDanmu() async {
        danMuProvider = LiveDanMuProvider(roomID: roomID)
        danMuProvider?.onDanmu = {
            [weak self] string in
            let model = DanmakuTextCellModel(str: string)
            DispatchQueue.main.async { [weak self] in
                self?.onShootDanmu?(model)
            }
        }
        danMuProvider?.onSC = {
            [weak self] string in
            let model = DanmakuTextCellModel(str: string)
            model.type = .top
            model.displayTime = 60
            DispatchQueue.main.async { [weak self] in
                self?.onShootDanmu?(model)
            }
        }
        try? await danMuProvider?.start()
    }
}

struct LivePlayUrlInfo {
    let formate: String?
    let url: String
    let current_qn: Int?
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
        return try await request(url: "https://api.live.bilibili.com/room/v1/Room/get_info", parameters: ["room_id": roomID])
    }
}
