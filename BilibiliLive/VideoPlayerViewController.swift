//
//  VideoPlayerViewController.swift
//  BilibiliLive
//
//  Created by Etan Chen on 2021/4/4.
//

import Foundation
import Alamofire
import SwiftyJSON
import SwiftyXMLParser

class VideoPlayerViewController: UIViewController {
    var cid:Int!
    var aid:Int!
    let playerVC = CommonPlayerViewController()
    var allDanmus = [Danmu]()
    var playingDanmus = [Danmu]()
    let danMuView = DanmakuView()
    
    deinit {
        print("deinit")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupPlayer()
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
    
    func setupPlayer() {
        addChild(playerVC)
        view.addSubview(playerVC.view)
        playerVC.didMove(toParent: self)
        playerVC.playerTimeChanged = {
            [weak self] time in
            self?.playerTimeChange(time: time)
        }
        playerVC.didSeek = {
            [weak self] time in
            self?.resetPlayingDanmu(time: time)
        }
        playerVC.didPlay = {
            [weak self] in
            self?.danMuView.play()
        }
        
        playerVC.didPause = {
            [weak self] in
            self?.danMuView.pause()
        }
    }
    
    func fetchVideoData() {
        AF.request("https://api.bilibili.com/x/player/playurl?avid=\(aid!)&cid=\(cid!)&qn=116&type=&fnver=0&fnval=16&otype=json")
            .responseJSON  {
                [weak self] response in
                guard let self = self else { return }
                switch response.result {
                case .success(let data):
                    self.playmedia(json: JSON(data))
                case .failure(let error):
                    print(error)
                }
            }
    }
    
    func ensureCid(callback:(()->Void)?=nil) {
        if cid > 0 {
            callback?()
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
        playingDanmus = allDanmus
    }
    
    func playmedia(json: JSON) {
        let video = json["data"]["dash"]["video"][1]["base_url"].stringValue
        let audio = json["data"]["dash"]["audio"].arrayValue.last!["baseUrl"].stringValue
        
        let videoMedia = VLCMedia(url: URL(string: video)!)
        videoMedia.addOptions([
            "http-user-agent": "Bilibili/APPLE TV",
            "http-referrer": "https://www.bilibili.com/video/av\(aid!)"
        ])
        let player = playerVC.player
        player.media = videoMedia
        player.addPlaybackSlave(URL(string: audio)!, type: VLCMediaPlaybackSlaveType.audio, enforce: true)
        player.play()
        danMuView.play()
    }
    
    func playerTimeChange(time: TimeInterval) {
        while let first = playingDanmus.first, first.time <= time {
            let danmu = playingDanmus.removeFirst()
            let model = DanmakuTextCellModel(str: danmu.text)
            danMuView.shoot(danmaku: model)
        }
    }
    
    func resetPlayingDanmu(time: TimeInterval) {
        let idx = allDanmus.firstIndex(where: {$0.time > time}) ?? allDanmus.endIndex
        playingDanmus = Array(allDanmus[idx ..< allDanmus.endIndex])
    }
}


struct Danmu : Codable{
    var time:TimeInterval
    var mode:Int
    var fontSize:Int
    var color:String
    var text:String
    
    init(_ attr: String, str: String) {
        text = str
        let attrs:[String] = attr.components(separatedBy: ",")
        time = TimeInterval(attrs[0])!
        mode = Int(attrs[1])!
        fontSize = Int(attrs[2])!
        color = attrs[3]
    }
}
