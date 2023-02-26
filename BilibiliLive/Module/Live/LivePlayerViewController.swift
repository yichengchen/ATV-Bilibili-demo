//
//  PlayerViewController.swift
//  BilibiliLive
//
//  Created by Etan on 2021/3/27.
//

import Alamofire
import AVKit
import Foundation
import SwiftyJSON
import UIKit

class LivePlayerViewController: CommonPlayerViewController {
    enum LiveError: Error {
        case noLiving
        case noPlaybackUrl
        case fetchApiFail
    }

    var room: LiveRoom? {
        didSet {
            roomID = room?.room_id ?? 0
        }
    }

    private var roomID: Int = 0
    private var danMuProvider: LiveDanMuProvider?
    private var failCount = 0
    private var playInfo = [PlayInfo]()

    deinit {
        Logger.debug("deinit live player")
    }

    override func viewDidLoad() {
        allowChangeSpeed = false
        requiresLinearPlayback = true
        super.viewDidLoad()

        Task {
            do {
                try await refreshRoomsID()
                initDataSource()
                try await initPlayer()
            } catch let err {
                endWithError(err: err)
            }
            if let info = try? await WebRequest.requestLiveBaseInfo(roomID: roomID) {
                let subtitle = "\(room?.ownerName ?? "")·\(info.parent_area_name) \(info.area_name)"
                let desp = "\(info.description)\nTags:\(info.tags ?? "")\n Hot words:\(info.hot_words?.joined(separator: ",") ?? "")"
                setPlayerInfo(title: info.title, subTitle: subtitle, desp: desp, pic: room?.pic)
            } else {
                setPlayerInfo(title: room?.title, subTitle: "nil", desp: room?.ownerName, pic: room?.pic)
            }
        }
        danMuView.play()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillAppear(animated)
        danMuProvider?.stop()
    }

    override func retryPlay() -> Bool {
        Logger.warn("play fail, retry")
        failCount += 1
        if playInfo.count > 0 {
            playInfo = Array(playInfo.dropFirst())
        }
        play()
        return true
    }

    func play() {
        if let url = playInfo.first?.url {
            danMuProvider?.start()
            danMuView.play()

            let headers: [String: String] = [
                "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/107.0.0.0 Safari/537.36",
                "Referer": "https://live.bilibili.com",
            ]
            let asset = AVURLAsset(url: URL(string: url)!, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
            playerItem = AVPlayerItem(asset: asset)
            player = AVPlayer(playerItem: playerItem)
        } else {
            showErrorAlertAndExit(title: "url is nil", message: "url: \(playInfo.first?.url.count ?? 0)")
        }
        if Settings.danmuMask, Settings.vnMask {
            maskProvider = VMaskProvider()
            setupMask()
        }
    }

    func endWithError(err: Error) {
        let alert = UIAlertController(title: "播放失败", message: "\(err)", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: {
            [weak self] _ in
            self?.dismiss(animated: true, completion: nil)
        }))
        present(alert, animated: true, completion: nil)
    }

    func refreshRoomsID() async throws {
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

    func initDataSource() {
        danMuProvider = LiveDanMuProvider(roomID: roomID)
        danMuProvider?.onDanmu = {
            [weak self] string in
            let model = DanmakuTextCellModel(str: string)
            self?.danMuView.shoot(danmaku: model)
        }
        danMuProvider?.onSC = {
            [weak self] string in
            let model = DanmakuTextCellModel(str: string)
            model.type = .top
            model.displayTime = 60
            self?.danMuView.shoot(danmaku: model)
        }
        danMuProvider?.start()
    }

    override func additionDebugInfo() -> String {
        return "\n\(playInfo.first?.formate ?? "") \(playInfo.first?.current_qn ?? 0) failed: \(failCount)"
    }

    struct PlayInfo {
        let formate: String?
        let url: String
        let current_qn: Int?
    }

    func initPlayer() async throws {
        let requestUrl = "https://api.live.bilibili.com/xlive/web-room/v2/index/getRoomPlayInfo?room_id=\(roomID)&protocol=1&format=0,1,2&codec=0,1&qn=10000&platform=web&ptype=8&dolby=5&panorama=1"
        guard let data = try? await AF.request(requestUrl).serializingData().result.get() else {
            throw LiveError.fetchApiFail
        }
        var playInfos = [PlayInfo]()
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
                        let playInfo = PlayInfo(formate: formate, url: url, current_qn: qn)
                        playInfos.append(playInfo)
                    }
                }
            }
        }
        Logger.debug("info arry:\(playInfos)")
        let info = playInfos.filter({ $0.formate == "fmp4" })
        if info.count > 0 {
            Logger.debug("play =>", info)
            playInfo = info
            play()
        } else {
            if playInfos.count > 0 {
                Logger.debug("no fmp4 found, play directly")
                playInfo = playInfos
                play()
                return
            }

            throw LiveError.noPlaybackUrl
        }
    }
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
