//
//  CommonPlayerViewController.swift
//  BilibiliLive
//
//  Created by Etan Chen on 2021/4/4.
//

import UIKit
import AVKit

class CommonPlayerViewController: AVPlayerViewController {
    var playerTimeChanged: ((TimeInterval) -> Void)?=nil
    var didSeek: ((TimeInterval)->Void)?=nil
    var didPause:(()->Void)?=nil
    var didPlay: (()->Void)?=nil
    var didEnd: (()->Void)?=nil


    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
//    func initPlayer() {
//        self.player = AVPlayer(url: URL(string: playUrl)!)
//        self.player?.play()
//    }
}
