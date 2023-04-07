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
    let danMuView = DanmakuView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(playerView)
        playerView.makeConstraintsToBindToSuperview()
        player.drawable = playerView
        player.delegate = self
        initDanmuView()
    }

    private func initDanmuView() {
        view.addSubview(danMuView)
        danMuView.accessibilityLabel = "danmuView"
        danMuView.makeConstraintsToBindToSuperview()
        danMuView.isHidden = !Settings.defaultDanmuStatus
        danMuView.play()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        danMuView.recaculateTracks()
        danMuView.paddingTop = 5
        danMuView.trackHeight = 50
        danMuView.displayArea = Settings.danmuArea.percent
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillAppear(animated)
        danMuView.stop()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        danMuView.play()
    }

    func play(url: URL) {
        let videoMedia = VLCMedia(url: url)
        videoMedia.addOptions([
            "http-user-agent": "Mozilla/5.0 (iPad; CPU OS 8_1_3 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Version/8.0 Mobile/12B466 Safari/600.1.4",
        ])
        player.media = videoMedia
        player.play()
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

extension VLCLivePlayerViewController: VLCMediaPlayerDelegate {
    func mediaPlayerStateChanged(_ aNotification: Notification) {
        print("mediaPlayerStateChanged", player.state.rawValue)
        if player.state == .ended {
            dismiss(animated: true, completion: nil)
        }
    }
}
