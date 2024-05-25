//
//  NewCommonPlayerViewController.swift
//  BilibiliLive
//
//  Created by yicheng on 2024/5/23.
//

import AVKit
import UIKit

protocol CommonPlayerPlugin {
    func addViewToPlayerOverlay(container: UIView)
    func addMenuItems(current: [UIMenuElement]) -> [UIMenuElement]

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
    func addMenuItems(current: [UIMenuElement]) -> [UIMenuElement] { return [] }

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

class NewCommonPlayerViewController: UIViewController {
    private let playerVC = AVPlayerViewController()
    private var activePlugins = [CommonPlayerPlugin]()
    private var observations = Set<NSKeyValueObservation>()
    private var rateObserver: NSKeyValueObservation?
    private var statusObserver: NSKeyValueObservation?
    private var isEnd = false
    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(playerVC)
        view.addSubview(playerVC.view)
        playerVC.didMove(toParent: self)
        playerVC.view.snp.makeConstraints { $0.edges.equalToSuperview() }
        playerVC.allowsPictureInPicturePlayback = true
        playerVC.delegate = self
        
        let playerObservation = playerVC.observe(\.player) { [weak self] vc, obs in
            if let oldPlayer = obs.oldValue, let oldPlayer {
                self?.activePlugins.forEach { $0.playerDidCleanUp(player: oldPlayer) }
            }
            self?.playerDidChange(player: vc.player)
        }
        observations.insert(playerObservation)
        activePlugins.forEach { $0.playerDidLoad(playerVC: playerVC) }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        activePlugins.forEach { $0.playerDidDismiss(playerVC: playerVC) }
    }

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        return [playerVC.view]
    }

    func addPlugin(plugin: CommonPlayerPlugin) {
        plugin.addViewToPlayerOverlay(container: playerVC.contentOverlayView!)
        activePlugins.append(plugin)
        plugin.playerDidLoad(playerVC: playerVC)
    }

    func showErrorAlertAndExit(title: String = "播放失败", message: String = "未知错误") {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let actionOk = UIAlertAction(title: "OK", style: .default) {
            [weak self] _ in
            self?.dismiss(animated: true, completion: nil)
        }
        alertController.addAction(actionOk)
        present(alertController, animated: true, completion: nil)
    }
}

extension NewCommonPlayerViewController {
    private func playerDidChange(player: AVPlayer?) {
        if let player {
            activePlugins.forEach { $0.playerDidChange(player: player) }
            rateObserver = player.observe(\.rate, options: [.old, .new]) {
                [weak self] _player, obs in
                DispatchQueue.main.async { [weak self] in
                    self?.playerRateDidChange(player: player)
                }
            }
            if let playItem = player.currentItem {
                observePlayerItem(playItem)
            }
            var menus = [UIMenuElement]()
            activePlugins.forEach {
                let newMenus = $0.addMenuItems(current: menus)
                menus.append(contentsOf: newMenus)
            }
            playerVC.transportBarCustomMenuItems = menus
        } else {
            rateObserver = nil
        }
    }

    private func playerRateDidChange(player: AVPlayer) {
        if player.rate > 0 {
            activePlugins.forEach { $0.playerDidStart(player: player) }
        } else if player.rate == 0 {
            if !isEnd {
                activePlugins.forEach { $0.playerDidPause(player: player) }
            }
        }
    }

    private func observePlayerItem(_ playerItem: AVPlayerItem) {
        statusObserver = playerItem.observe(\.status, options: [.new, .old]) {
            [weak self] item, _ in
            guard let self, let player = playerVC.player else { return }
            switch item.status {
            case .readyToPlay:
                isEnd = false
                activePlugins.forEach { $0.playerWillStart(player: player) }
                player.play()
            case .failed:
                activePlugins.forEach { $0.playerDidFail(player: player) }
            default:
                break
            }
        }
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: .main) { [weak self] note in
            guard let self, let player = playerVC.player else { return }
            isEnd = true
            activePlugins.forEach { $0.playerDidEnd(player: player) }
        }
    }
}


extension NewCommonPlayerViewController: AVPlayerViewControllerDelegate {
    @objc func playerViewControllerShouldDismiss(_ playerViewController: AVPlayerViewController) -> Bool {
        if let presentedViewController = UIViewController.topMostViewController() as? AVPlayerViewController,
           presentedViewController == playerViewController
        {
            return true
        }
        return false
    }

    @objc func playerViewControllerShouldAutomaticallyDismissAtPictureInPictureStart(_: AVPlayerViewController) -> Bool {
        return true
    }

    @objc func playerViewController(_ playerViewController: AVPlayerViewController,
                                    restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void)
    {
        let presentedViewController = UIViewController.topMostViewController()
        if presentedViewController is AVPlayerViewController {
            let parent = presentedViewController.presentingViewController
            presentedViewController.dismiss(animated: false) {
                parent?.present(playerViewController, animated: false)
                completionHandler(true)
            }
        } else {
            presentedViewController.present(playerViewController, animated: false) {
                completionHandler(true)
            }
        }
    }
}
