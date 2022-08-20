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
    private var observer: NSKeyValueObservation?
    var playerItem: AVPlayerItem? {
        didSet {
            if let playerItem = playerItem {
                removeObservarPlayerItem()
                observePlayerItem(playerItem)
            }
        }
    }
    
    deinit {
        observer = nil
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
    
    func playerStatusDidChange() {
        print("player status: \(player?.currentItem?.status.rawValue ?? -1)")
        switch player?.currentItem?.status {
        case .readyToPlay:
            startPlay()
        case .failed:
            removeObservarPlayerItem()
            if retryCount<maxRetryCount, !retryPlay() {
                showErrorAlertAndExit(title: "播放器失败", message: playerItem?.errorLog()?.description ?? "")
            }
            retryCount+=1
        default:
            break
        }
    }
    
    private func removeObservarPlayerItem() {
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
    }
    
    
    private func observePlayerItem(_ playerItem: AVPlayerItem) {
        observer = playerItem.observe(\.status, options:  [.new, .old]) {
            [weak self] _,_  in
            self?.playerStatusDidChange()
        }
        NotificationCenter.default.addObserver(self,
                                 selector: #selector(playerDidFinishPlaying),
                                 name: .AVPlayerItemDidPlayToEndTime,
                                 object: playerItem)
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
