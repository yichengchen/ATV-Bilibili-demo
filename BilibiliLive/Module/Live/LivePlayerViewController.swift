//
//  PlayerViewController.swift
//  BilibiliLive
//
//  Created by Etan on 2021/3/27.
//

import UIKit
import Alamofire
import SwiftyJSON
import AVKit

class LivePlayerViewController: CommonPlayerViewController {
    enum LiveError: Error {
        case noLiving
    }
    
    var room: LiveRoom? {
        didSet {
            roomID = room?.roomID ?? 0
        }
    }
    private var roomID: Int = 0
    private var danMuProvider: LiveDanMuProvider?
    private var url: URL?
        
    override func viewDidLoad() {
        allowChangeSpeed = false
        super.viewDidLoad()
        refreshRoomsID(){
            [weak self] in
            guard let self = self else { return }
            self.initDataSource()
            self.initPlayer()
        }
        danMuView.play()
        setPlayerInfo(title: room?.title, subTitle: nil, desp: room?.owner, pic: room?.cover?.absoluteString)
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
        if var url = self.url {
            if Settings.livePlayerHack {
                var components = URLComponents(string: url.absoluteString)!
                components.query = nil
                url = components.url ?? url
                danMuProvider?.start()
                danMuView.play()
            }

            let headers: [String: String] = [
                "User-Agent": "Bilibili/APPLE TV",
                "Referer": "https://live.bilibili.com"
            ]
            let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
            playerItem = AVPlayerItem(asset: asset)
            player = AVPlayer(playerItem: playerItem)
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
    
    func refreshRoomsID(complete:(()->Void)?=nil) {
        let url = "https://api.live.bilibili.com/room/v1/Room/room_init?id=\(roomID)"
        AF.request(url).responseData {
            [weak self] resp in
            guard let self = self else { return }
            switch resp.result {
            case .success(let object):
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
            case .failure(let error):
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
    
    
    func initPlayer() {
        let requestUrl = "https://api.live.bilibili.com/room/v1/Room/playUrl?cid=\(roomID)&platform=h5&otype=json&quality=10000"
        AF.request(requestUrl).responseData {
            [unowned self] resp in
            switch resp.result {
            case .success(let object):
                let json = JSON(object)
                if let playUrl = json["data"]["durl"].arrayValue.first?["url"].string {
                    self.url = URL(string: playUrl)!
                    self.play()
                } else {
                    dismiss(animated: true, completion: nil)
                }
                break
            case .failure(let err):
                print(err)
                dismiss(animated: true, completion: nil)
            }
        }
    }
}

