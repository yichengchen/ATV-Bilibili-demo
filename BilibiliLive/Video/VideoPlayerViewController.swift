//
//  VideoPlayerViewController.swift
//  BilibiliLive
//
//  Created by Etan Chen on 2021/4/4.
//

import UIKit
import Alamofire
import SwiftyJSON
import SwiftyXMLParser
import AVKit
import AVFoundation

class VideoPlayerViewController: CommonPlayerViewController {
    var cid:Int!
    var aid:Int!
    var position: Float = 0.0
    
    private var allDanmus = [Danmu]()
    private var playingDanmus = [Danmu]()
    private var playerDelegate: CustomPlaylistDelegate?
    private let danmuProvider = VideoDanmuProvider()
    
    deinit {
        guard let currentTime = player?.currentTime().seconds, currentTime>0 else { return }
        guard let csrf = CookieHandler.shared.csrf() else { return }
        AF.request("https://api.bilibili.com/x/v2/history/report", method: .post, parameters: ["aid": aid!, "cid": cid!, "progress": currentTime, "csrf": csrf]).resume()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        ensureCid {
            [weak self] in
            guard let self = self else { return }
            self.fetchVideoData()
            self.danmuProvider.cid = self.cid
            self.danmuProvider.fetchDanmuData()
        }
        danmuProvider.onShowDanmu = {
            [weak self] in
            self?.danMuView.shoot(danmaku: $0)
        }
    }
    
    
    func playmedia(json: JSON) {
        NativePlayerContentApiPorvider.shared.setVideo(info: json)
        playDash(url:  "http://127.0.0.1:\(NativePlayerContentApiPorvider.shared.port)/playitem.mpd")
        danMuView.play()
    }
    
    override func playerDidFinishPlaying() {
        dismiss(animated: true)
    }
}


// MARK: - Requests
extension VideoPlayerViewController {
    func fetchVideoData() {
        ApiRequest.requestJSON("https://api.bilibili.com/x/player/playurl?avid=\(aid!)&cid=\(cid!)&qn=116&type=&fnver=0&fnval=16&otype=json") { [weak self] resp in
            switch resp {
            case .success(let data):
                self?.playmedia(json: data)
            case .failure(let error):
                switch error {
                case .statusFail(let code):
                    self?.showErrorAlertAndExit(message: "请求失败\(code)，可能需要大会员")
                default:
                    self?.showErrorAlertAndExit(message: "请求失败,\(error)")
                }
            }
        }
    }
    
    func ensureCid(callback:(()->Void)?=nil) {
        if cid > 0 {
            callback?()
            return
        }
        AF.request("https://api.bilibili.com/x/player/pagelist?aid=\(aid!)&jsonp=jsonp").responseData {
            [weak self] resp in
            guard let self = self else { return }
            switch resp.result {
            case .success(let data):
                let json = JSON(data)
                let cid = json["data"][0]["cid"].intValue
                self.cid = cid
                callback?()
            case .failure(let err):
                self.showErrorAlertAndExit(message: "请求cid失败")
                print(err)
            }
        }
    }
}


// MARK: - Player
extension VideoPlayerViewController {
    func playDash(url:String) {
        playerStartPos = .zero
        let playURL = URL(string: toCustomUrl(url))!
        let headers: [String: String] = [
            "User-Agent": "Bilibili/APPLE TV",
            "Referer": "https://www.bilibili.com/video/av\(aid!)"
        ]
        let asset = AVURLAsset(url: playURL, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        playerDelegate = CustomPlaylistDelegate()
        let resourceLoader = asset.resourceLoader
        
        resourceLoader.setDelegate(playerDelegate, queue: DispatchQueue(label: "loader"))
        let requestedKeys = ["playable"]
        asset.loadValuesAsynchronously(forKeys: requestedKeys, completionHandler: {
            DispatchQueue.main.async {
                self.prepare(toPlay: asset, withKeys: requestedKeys)
            }
        })
    }
    
    func prepare(toPlay asset: AVURLAsset, withKeys requestedKeys: [AnyHashable]) {
        for thisKey in requestedKeys {
            guard let thisKey = thisKey as? String else {
                continue
            }
            var error: NSError?
            let keyStatus = asset.statusOfValue(forKey: thisKey, error: &error)
            if keyStatus == .failed {
                showErrorAlertAndExit(title: error?.localizedDescription ?? "", message: error?.localizedFailureReason ?? "")
                return
            }
        }
        
        if !asset.isPlayable {
            showErrorAlertAndExit(message: "URL解析错误")
            return
        }

        let playerItem = AVPlayerItem(asset: asset)
        observePlayerItem(playerItem)
        
        player = AVPlayer(playerItem: playerItem)
        player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 1), queue: .main) { [weak self] time in
            self?.danmuProvider.playerTimeChange(time: time.seconds)
        }
    }
}
