//
//  BUpnpPlugin.swift
//  BilibiliLive
//
//  Created by yicheng on 2024/5/25.
//

import AVFoundation
import Foundation
class BUpnpPlugin: NSObject, CommonPlayerPlugin {
    let duration: Int?

    init(duration: Int?) {
        self.duration = duration
    }

    func playerWillStart(player: AVPlayer) {
        guard let duration else { return }
        player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 5, preferredTimescale: 1), queue: .global()) { time in
            DispatchQueue.main.async {
                BiliBiliUpnpDMR.shared.sendProgress(duration: duration, current: Int(time.seconds))
            }
        }
    }

    func playerDidStart(player: AVPlayer) {
        DispatchQueue.main.async {
            BiliBiliUpnpDMR.shared.sendStatus(status: .playing)
        }
    }

    func playerDidPause(player: AVPlayer) {
        DispatchQueue.main.async {
            BiliBiliUpnpDMR.shared.sendStatus(status: .paused)
        }
    }

    func playerDidEnd(player: AVPlayer) {
        DispatchQueue.main.async {
            BiliBiliUpnpDMR.shared.sendStatus(status: .end)
        }
    }

    func playerDidFail(player: AVPlayer) {
        DispatchQueue.main.async {
            BiliBiliUpnpDMR.shared.sendStatus(status: .stop)
        }
    }

    func playerDidCleanUp(player: AVPlayer) {
        DispatchQueue.main.async {
            BiliBiliUpnpDMR.shared.sendStatus(status: .stop)
        }
    }
}
