//
//  CommonPlayerViewController.swift
//  BilibiliLive
//
//  Created by Etan Chen on 2021/4/4.
//

import UIKit

class CommonPlayerViewController: UIViewController {
    let player = VLCMediaPlayer()
    let playerView = UIView()
    let controlView = PlayerControlView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(playerView)
        playerView.makeConstraintsToBindToSuperview()
        player.drawable = playerView
        player.delegate = self
        
        controlView.delegate = self
        view.addSubview(controlView)
        controlView.makeConstraints {
            [$0.leadingAnchor.constraint(equalTo: view.leadingAnchor),
             $0.trailingAnchor.constraint(equalTo: view.trailingAnchor),
             $0.bottomAnchor.constraint(equalTo: view.bottomAnchor),
             $0.heightAnchor.constraint(equalToConstant: 120)]
        }
    }
}

extension CommonPlayerViewController: VLCMediaPlayerDelegate {
    func mediaPlayerStateChanged(_ aNotification: Notification!) {
        switch player.state {
        case .buffering:
            break
        default:
            break
        }
    }
    
    func mediaPlayerTimeChanged(_ aNotification: Notification!) {
        controlView.duration = TimeInterval(player.media.length.intValue/1000)
        controlView.current = TimeInterval(player.time.intValue/1000)
    }
}

extension CommonPlayerViewController: PlayerControlViewDelegate {
    func didSeek(to time: TimeInterval) {
        player.time = VLCTime(int: Int32(Int(time)) * 1000)
    }
}
