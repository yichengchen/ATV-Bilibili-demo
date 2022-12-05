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
    }

    var room: LiveRoom? {
        didSet {
            roomID = room?.room_id ?? 0
        }
    }

    private var roomID: Int = 0
    private var danMuProvider: LiveDanMuProvider?
    private var url: URL?
    private var playInfo: PlayInfo?

    override func viewDidLoad() {
        allowChangeSpeed = false
        requiresLinearPlayback = true
        super.viewDidLoad()
        refreshRoomsID {
            [weak self] in
            guard let self = self else { return }
            self.initDataSource()
            Task {
                let success = await self.initPlayer()
                if !success {
                    self.initPlayerBackUp()
                }
            }
        }
        danMuView.play()
        setPlayerInfo(title: room?.title, subTitle: nil, desp: room?.ownerName, pic: room?.pic)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillAppear(animated)
        danMuProvider?.stop()
    }

    override func retryPlay() -> Bool {
        play()
        return true
    }

    func play() {
        if let url = url {
            danMuProvider?.start()
            danMuView.play()

            let headers: [String: String] = [
                "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/107.0.0.0 Safari/537.36",
                "Referer": "https://live.bilibili.com",
            ]
            let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
            playerItem = AVPlayerItem(asset: asset)
            player = AVPlayer(playerItem: playerItem)
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

    func refreshRoomsID(complete: (() -> Void)? = nil) {
        let url = "https://api.live.bilibili.com/room/v1/Room/room_init?id=\(roomID)"
        AF.request(url).responseData {
            [weak self] resp in
            guard let self = self else { return }
            switch resp.result {
            case let .success(object):
                let json = JSON(object)
                let isLive = json["data"]["live_status"].intValue == 1
                if !isLive {
                    self.endWithError(err: LiveError.noLiving)
                    return
                }
                if let newID = json["data"]["room_id"].int {
                    self.roomID = newID
                }
                complete?()
            case let .failure(error):
                self.endWithError(err: error)
            }
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
        return "\n\(playInfo?.formate ?? "")\n\(playInfo?.url ?? "")"
    }

    struct PlayInfo {
        let formate: String?
        let url: String
    }

    func initPlayer() async -> Bool {
        let requestUrl = "https://api.live.bilibili.com/xlive/web-room/v2/index/getRoomPlayInfo?room_id=\(roomID)&protocol=1&format=0,1,2&codec=0,1&qn=10000&platform=web&ptype=8&dolby=5&panorama=1"
        guard let data = try? await AF.request(requestUrl).serializingData().result.get() else {
            return false
        }
        var playInfos = [PlayInfo]()
        let json = JSON(data)

        for stream in json["data"]["playurl_info"]["playurl"]["stream"].arrayValue {
            for content in stream["format"].arrayValue {
                let formate = content["format_name"].stringValue
                let codecs = content["codec"].arrayValue

                for codec in codecs {
                    let baseUrl = codec["base_url"].stringValue
                    for url_info in codec["url_info"].arrayValue {
                        let host = url_info["host"]
                        let extra = url_info["extra"]
                        let url = "\(host)\(baseUrl)\(extra)"
                        let playInfo = PlayInfo(formate: formate, url: url)
                        playInfos.append(playInfo)
                    }
                }
            }
        }

        if let info = playInfos.first(where: { $0.formate == "fmp4" }) ?? playInfos.first {
            print("play =>", info)
            url = URL(string: info.url)!
            playInfo = info
            play()
            return true
        }
        return false
    }

    func initPlayerBackUp() {
        let requestUrl = "https://api.live.bilibili.com/room/v1/Room/playUrl?cid=\(roomID)&platform=h5&otype=json&quality=10000"
        AF.request(requestUrl).responseData {
            [unowned self] resp in
            switch resp.result {
            case let .success(object):
                let json = JSON(object)
                if let playUrl = json["data"]["durl"].arrayValue.first?["url"].string {
                    var components = URLComponents(string: playUrl)!
                    components.query = nil
                    self.url = components.url ?? URL(string: playUrl)!
                    playInfo = PlayInfo(formate: "old", url: playUrl)
                    self.play()
                } else {
                    dismiss(animated: true, completion: nil)
                }
            case let .failure(err):
                print(err)
                dismiss(animated: true, completion: nil)
            }
        }
    }
}
