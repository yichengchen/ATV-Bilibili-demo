//
//  CommonPlayerViewController.swift
//  BilibiliLive
//
//  Created by Etan Chen on 2021/4/4.
//

import UIKit
import AVKit

class CommonPlayerViewController: AVPlayerViewController {
    let danMuView = DanmakuView()
    
    var playerStartPos: CMTime?
    private var retryCount = 0
    private let maxRetryCount = 3
    deinit {
        removeObservarPlayerItem(player?.currentItem)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        initDanmuView()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        danMuView.recaculateTracks()
        danMuView.paddingTop = 5
        danMuView.trackHeight = 50
        danMuView.displayArea = 0.8
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillAppear(animated)
        danMuView.stop()
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status" {
            print("player status: \(player?.currentItem?.status.rawValue ?? -1)")
            switch player?.currentItem?.status {
            case .readyToPlay:
                startPlay()
            case .failed:
                removeObservarPlayerItem(player?.currentItem)
                if retryCount<maxRetryCount, !retryPlay() {
                    showErrorAlertAndExit(title: "播放失败", message: "播放器失败")
                }
                retryCount+=1
            default:
                break
            }
        }
    }
    
    func removeObservarPlayerItem(_ playerItem: AVPlayerItem?) {
        playerItem?.removeObserver(self, forKeyPath: "status")
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
    }
    
    func observePlayerItem(_ playerItem: AVPlayerItem) {
        playerItem.addObserver(self, forKeyPath: "status", options: [.new], context: nil)
        NotificationCenter.default.addObserver(self,
                                 selector: #selector(playerDidFinishPlaying),
                                 name: .AVPlayerItemDidPlayToEndTime,
                                 object: playerItem
                    )
    }
    
    func retryPlay() -> Bool {
        return false
    }
    
    @objc func playerDidFinishPlaying() {
        // need override
    }
    
    func showErrorAlertAndExit(title: String="播放失败", message: String="未知错误") {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let actionOk = UIAlertAction(title: "OK", style: .default) {
            [weak self] _ in
            self?.dismiss(animated: true, completion: nil)
        }
        alertController.addAction(actionOk)
        present(alertController, animated: true, completion: nil)
    }
    
    private func startPlay() {
        guard player?.rate == 0 && player?.error == nil else { return }
        if let playerStartPos = playerStartPos {
            player?.seek(to: playerStartPos)
        }
        player?.play()
    }
    
    private func initDanmuView() {
        view.addSubview(danMuView)
        danMuView.makeConstraintsToBindToSuperview()
    }
}
