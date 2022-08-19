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
    var allDanmus = [Danmu]()
    var playingDanmus = [Danmu]()
    let danMuView = DanmakuView()
    var position: Float = 0.0
    private var playerDelegate: CustomPlaylistDelegate?
    
    deinit {
        //        guard let currentTime = player?.currentTime(), currentTime>0 else { return }
        //        let progress = playerVC.player.time.value.intValue / 1000
        //        guard progress > 0 else { return }
        //        guard let csrf = CookieHandler.shared.csrf() else { return }
        //        AF.request("https://api.bilibili.com/x/v2/history/report", method: .post, parameters: ["aid": aid!, "cid": cid!, "progress": progress, "csrf": csrf]).resume()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        ensureCid {
            [weak self] in
            self?.fetchVideoData()
            self?.fetchDanmuData()
        }
        view.addSubview(danMuView)
        danMuView.makeConstraintsToBindToSuperview()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillAppear(animated)
        danMuView.stop()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        danMuView.recaculateTracks()
        danMuView.paddingTop = 5
        danMuView.trackHeight = 50
        danMuView.displayArea = 0.8
    }
    
    
    func fetchVideoData() {
        ApiRequest.requestJSON("https://api.bilibili.com/x/player/playurl?avid=\(aid!)&cid=\(cid!)&qn=116&type=&fnver=0&fnval=16&otype=json") { [weak self ] resp in
            switch resp {
            case .success(let data):
                self?.playmedia(json: data)
            case .failure(let error):
                print(error)
                self?.showErrorAlert()
            }
        }
    }
    
    func ensureCid(callback:(()->Void)?=nil) {
        if cid > 0 {
            callback?()
            return
        }
        AF.request("https://api.bilibili.com/x/player/pagelist?aid=\(aid!)&jsonp=jsonp").responseJSON {
            [weak self] resp in
            guard let self = self else { return }
            switch resp.result {
            case .success(let data):
                let json = JSON(data)
                let cid = json["data"][0]["cid"].intValue
                self.cid = cid
                callback?()
            case .failure(let err):
                print(err)
            }
        }
    }
    
    func fetchDanmuData() {
        AF.request("https://api.bilibili.com/x/v1/dm/list.so?oid=\(cid!)").responseString(encoding:.utf8) {
            [weak self] resp in
            guard let self = self else { return }
            switch resp.result {
            case .success(let data):
                self.parseDanmuData(data: data)
            case .failure(let err):
                print(err)
            }
        }
    }
    
    func parseDanmuData(data: String) {
        guard let xml = try? XML.parse(data) else { return }
        allDanmus = xml["i"]["d"].all?.map{ xml in
            Danmu(xml.attributes["p"]!, str: xml.text!)
        } ?? []
        allDanmus.sort {
            $0.time < $1.time
        }
        print("danmu count: \(allDanmus.count)")
        playingDanmus = allDanmus
    }
    
    func showErrorAlert() {
        let alert = UIAlertController()
        alert.addAction(UIAlertAction(title: "请求失败，可能需要大会员", style: .default, handler: { [weak self] _ in
            self?.dismiss(animated: true, completion: nil)
        }))
        present(alert, animated: true, completion: nil)
        return
    }
    
    func playmedia(json: JSON) {
        guard json["data"].exists() else {
            showErrorAlert()
            return
        }
        NativePlayerContentApiPorvider.shared.setVideo(info: json)

        playDash(url:  "http://127.0.0.1:\(NativePlayerContentApiPorvider.shared.port)/playitem.mpd")
        danMuView.play()
    }
    
    func playerTimeChange(time: TimeInterval) {
        let advanceTime = time.advanced(by: 1)
        while let first = playingDanmus.first, first.time <= advanceTime {
            let danmu = playingDanmus.removeFirst()
            let offset = advanceTime - danmu.time
            let model = DanmakuTextCellModel(str: danmu.text)
            model.color = UIColor(number: danmu.color)
            switch danmu.mode {
            case 1,2,3:
                model.type = .floating
            case 4:
                model.type = .bottom
            case 5:
                model.type = .top
            default:
                continue
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + offset) {
                [weak self] in
                self?.danMuView.shoot(danmaku: model)
            }
        }
    }
    
    func resetPlayingDanmu(time: TimeInterval) {
        let idx = allDanmus.firstIndex(where: {$0.time > time}) ?? allDanmus.endIndex
        playingDanmus = Array(allDanmus[idx ..< allDanmus.endIndex])
    }
    
    let playableKey = "playable"
    private var playerItem: AVPlayerItem?

    func playDash(url:String) {
        let playURL = URL(string: toCustomUrl(url))!
        let headers: [String: String] = [
            "User-Agent": "Bilibili/APPLE TV",
            "Referer": "https://www.bilibili.com/video/av\(aid!)"
        ]
        let asset = AVURLAsset(url: playURL, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        playerDelegate = CustomPlaylistDelegate()
        let resourceLoader = asset.resourceLoader
        
        resourceLoader.setDelegate(playerDelegate, queue: DispatchQueue(label: "loader"))
        let requestedKeys = [playableKey]
        asset.loadValuesAsynchronously(forKeys: requestedKeys, completionHandler: {
            DispatchQueue.main.async {
                self.prepare(toPlay: asset, withKeys: requestedKeys)
            }
        })
    }
    
    func prepare(toPlay asset: AVURLAsset, withKeys requestedKeys: [AnyHashable]) {
        // Make sure that the value of each key has loaded successfully.
        for thisKey in requestedKeys {
            guard let thisKey = thisKey as? String else {
                continue
            }
            var error: NSError?
            let keyStatus = asset.statusOfValue(forKey: thisKey, error: &error)
            if keyStatus == .failed {
                assetFailedToPrepare(forPlayback: error)
                return
            }
        }
        
        // Use the AVAsset playable property to detect whether the asset can be played.
        if !asset.isPlayable {
            // Generate an error describing the failure.
            let localizedDescription =
            NSLocalizedString("Item cannot be played", comment: "Item cannot be played description")
            let localizedFailureReason = NSLocalizedString("The contents of the resource at the specified URL are not playable.", comment: "Item cannot be played failure reason")
            let errorDict = [
                NSLocalizedDescriptionKey: localizedDescription,
                NSLocalizedFailureReasonErrorKey: localizedFailureReason,
            ]
            let assetCannotBePlayedError = NSError(domain: Bundle.main.bundleIdentifier ?? "", code: 0, userInfo: errorDict)
            
            // Display the error to the user.
            assetFailedToPrepare(forPlayback: assetCannotBePlayedError)
            
            return
        }
        
        // At this point we're ready to set up for playback of the asset.

        // Create a new instance of AVPlayerItem from the now successfully loaded AVAsset.
        playerItem = AVPlayerItem(asset: asset)
        playerItem?.addObserver(self, forKeyPath: "status", options: [.new], context: nil)

        let player = AVPlayer(playerItem: playerItem)
        self.player = player
        
        player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 1), queue: .main) { time in
            self.playerTimeChange(time: time.seconds)
        }
        
    }
    
    func startPlay() {
        guard player?.rate == 0 && player?.error == nil else { return }
        player?.seek(to: .zero)
        player?.play()
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status" {
            print("player status: \(self.playerItem?.status.rawValue ?? -1)")
            if self.playerItem?.status == .readyToPlay {
                startPlay()
            }
        }
    }
    
    func assetFailedToPrepare(forPlayback error: Error?) {
        let title = error?.localizedDescription ?? ""
        let message = (error as NSError?)?.localizedFailureReason ?? ""
        
        // Display the error.
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        // We add buttons to the alert controller by creating UIAlertActions:
        let actionOk = UIAlertAction(title: "OK",
                                     style: .default,
                                     handler: nil) // You can use a block here to handle a press on this button
        
        alertController.addAction(actionOk)
        
        present(alertController, animated: true, completion: nil)
    }
}


struct Danmu : Codable{
    var time:TimeInterval
    var mode:Int
    var fontSize:Int
    var color:Int
    var text:String
    
    init(_ attr: String, str: String) {
        text = str
        let attrs:[String] = attr.components(separatedBy: ",")
        time = TimeInterval(attrs[0])!
        mode = Int(attrs[1])!
        fontSize = Int(attrs[2])!
        color = Int(attrs[3])!
    }
}


extension UIColor {
    public convenience init(number: Int) {
        let r, g, b: CGFloat
        r = CGFloat((number & 0x00ff0000) >> 16) / 255
        g = CGFloat((number & 0x0000ff00) >> 8) / 255
        b = CGFloat(number & 0x000000ff) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
