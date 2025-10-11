//
//  CommonPlayerViewController.swift
//  BilibiliLive
//
//  Created by yicheng on 2024/5/23.
//

import AVKit
import UIKit

class CommonPlayerViewController: UIViewController {
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
        if activePlugins.contains(where: { $0 == plugin }) {
            return
        }
        plugin.addViewToPlayerOverlay(container: playerVC.contentOverlayView!)
        activePlugins.append(plugin)
        plugin.playerDidLoad(playerVC: playerVC)
        if playerVC.transportBarCustomMenuItems.isEmpty == false {
            updateMenus()
        }
    }

    func removePlugin(plugin: CommonPlayerPlugin) {
        activePlugins.removeAll { $0 == plugin }
    }

    func playerDidEnd(player: AVPlayer) {}

    func showErrorAlertAndExit(title: String = "播放失败", message: String = "未知错误") {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let actionOk = UIAlertAction(title: "OK", style: .default) {
            [weak self] _ in
            self?.dismiss(animated: true, completion: nil)
        }
        alertController.addAction(actionOk)
        present(alertController, animated: true, completion: nil)
    }

    func updateMenus() {
        var menus = [UIMenuElement]()
        for activePlugin in activePlugins {
            let newMenus = activePlugin.addMenuItems(current: &menus)
            menus.append(contentsOf: newMenus)
        }
        playerVC.transportBarCustomMenuItems = menus
    }
}

extension CommonPlayerViewController {
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
            updateMenus()
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
            playerDidEnd(player: player)
        }
    }
}

extension CommonPlayerViewController: AVPlayerViewControllerDelegate {
    @objc func playerViewControllerShouldDismiss(_ playerViewController: AVPlayerViewController) -> Bool {
        if let presentedViewController = UIViewController.topMostViewController() as? CommonPlayerViewController,
           presentedViewController.playerVC == playerViewController
        {
            dismiss(animated: true)
            return false
        }
        return false
    }

    @objc func playerViewControllerShouldAutomaticallyDismissAtPictureInPictureStart(_: AVPlayerViewController) -> Bool {
        return true
    }

    func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
        PipRecorder.shared.playingPipViewController.append(self)
    }

    func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
        PipRecorder.shared.playingPipViewController.removeAll { $0.playerVC == playerViewController }
    }

    @objc func playerViewController(_ playerViewController: AVPlayerViewController,
                                    restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void)
    {
        let presentedViewController = UIViewController.topMostViewController()
        guard let containerPlayer = PipRecorder.shared.playingPipViewController.first(where: { $0.playerVC == playerViewController }) else {
            completionHandler(false)
            return
        }
        if presentedViewController is CommonPlayerViewController {
            let parent = presentedViewController.presentingViewController
            presentedViewController.dismiss(animated: false) {
                parent?.present(containerPlayer, animated: false)
                completionHandler(true)
            }
        } else {
            presentedViewController.present(containerPlayer, animated: false) {
                completionHandler(true)
            }
        }
    }

    class PipRecorder {
        static let shared = PipRecorder()
        var playingPipViewController = [CommonPlayerViewController]()
    }
}
