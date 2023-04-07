//
//  VLCLivePlayerViewController.swift
//  BilibiliLive
//
//  Created by yicheng on 2023/4/6.
//

import Foundation
import TVVLCKit
class VLCLivePlayerViewController: UIViewController {
    let player = VLCMediaPlayer()
    let playerView = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(playerView)
        playerView.makeConstraintsToBindToSuperview()
        player.drawable = playerView
    }

    func play(url: URL) {
        let videoMedia = VLCMedia(url: url)
        videoMedia.addOptions([
            "http-user-agent": "Mozilla/5.0 (iPad; CPU OS 8_1_3 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Version/8.0 Mobile/12B466 Safari/600.1.4",
        ])
        player.media = videoMedia
        player.play()
    }
}
