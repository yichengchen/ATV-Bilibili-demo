//
//  CommonPlayerPlugin.swift
//  BilibiliLive
//
//  Created by yicheng on 2024/5/25.
//

import AVKit
import UIKit

protocol CommonPlayerPlugin: NSObject {
    func addViewToPlayerOverlay(container: UIView)
    func addMenuItems(current: inout [UIMenuElement]) -> [UIMenuElement]

    func playerDidLoad(playerVC: AVPlayerViewController)
    func playerDidDismiss(playerVC: AVPlayerViewController)
    func playerDidChange(player: AVPlayer)
    func playerItemDidChange(playerItem: AVPlayerItem)

    func playerWillStart(player: AVPlayer)
    func playerDidStart(player: AVPlayer)
    func playerDidPause(player: AVPlayer)
    func playerDidEnd(player: AVPlayer)
    func playerDidFail(player: AVPlayer)
    func playerDidCleanUp(player: AVPlayer)
}

extension CommonPlayerPlugin {
    func addViewToPlayerOverlay(container: UIView) {}
    func addMenuItems(current: inout [UIMenuElement]) -> [UIMenuElement] { return [] }

    func playerWillStart(player: AVPlayer) {}
    func playerDidStart(player: AVPlayer) {}
    func playerDidPause(player: AVPlayer) {}
    func playerDidEnd(player: AVPlayer) {}
    func playerDidFail(player: AVPlayer) {}
    func playerDidCleanUp(player: AVPlayer) {}

    func playerDidLoad(playerVC: AVPlayerViewController) {}
    func playerDidDismiss(playerVC: AVPlayerViewController) {}
    func playerDidChange(player: AVPlayer) {}
    func playerItemDidChange(playerItem: AVPlayerItem) {}
}
