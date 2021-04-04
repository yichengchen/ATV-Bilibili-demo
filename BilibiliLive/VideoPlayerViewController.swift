//
//  VideoPlayerViewController.swift
//  BilibiliLive
//
//  Created by Etan Chen on 2021/4/4.
//

import Foundation
import Alamofire
import SwiftyJSON

class VideoPlayerViewController: UIViewController {
    var cid:Int!
    var aid:Int!
    let playerVC = CommonPlayerViewController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(playerVC)
        view.addSubview(playerVC.view)
        playerVC.didMove(toParent: self)
        fetchData()
    }
    
    func fetchData() {
        AF.request("https://api.bilibili.com/x/player/playurl?avid=\(aid!)&cid=\(cid!)&qn=80&type=&fnver=0&fnval=16&otype=json")
            .responseJSON  { response in
                switch response.result {
                case .success(let data):
                    self.playmedia(json: JSON(data))
                case .failure(let error):
                    print(error)
                    break
                }
        }
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
    }
}
