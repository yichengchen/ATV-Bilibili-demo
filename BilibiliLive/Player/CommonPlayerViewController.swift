//
//  CommonPlayerViewController.swift
//  BilibiliLive
//
//  Created by Etan Chen on 2021/4/4.
//

import UIKit
import AVKit
import Kingfisher

class CommonPlayerViewController: AVPlayerViewController {
    let danMuView = DanmakuView()
    
    var playerStartPos: CMTime?
    private var retryCount = 0
    private let maxRetryCount = 3
    private var observer: NSKeyValueObservation?
    private var rateObserver: NSKeyValueObservation?
    var playerItem: AVPlayerItem? {
        didSet {
            if let playerItem = playerItem {
                removeObservarPlayerItem()
                observePlayerItem(playerItem)
                if let playerInfo = playerInfo {
                    playerItem.externalMetadata = playerInfo
                }
            }
        }
    }
    
    override var player: AVPlayer? {
        didSet {
            if let player = player {
                rateObserver = player.observe(\.rate, options: [.old, .new]) {
                    [weak self] player, _ in
                    guard let self = self else { return }
                    if player.rate > 0, self.danMuView.status == .pause {
                        self.danMuView.play()
                    } else if player.rate == 0, self.danMuView.status == .play {
                        self.danMuView.pause()
                    }
                }
            } else {
                rateObserver = nil
            }
        }
    }
    
    private var playerInfo: [AVMetadataItem]?
    
    deinit {
        observer = nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        initDanmuView()
        setupPlayerMenu()
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
    
    func setPlayerInfo(title:String?, subTitle:String?, desp: String?, pic: String?) {
        let desp = desp?.components(separatedBy: "\n").joined(separator: " ")
        let mapping: [AVMetadataIdentifier: Any?] = [
            .commonIdentifierTitle: title,
            .iTunesMetadataTrackSubTitle: subTitle,
            .commonIdentifierDescription: desp,
        ]
        let meta = mapping.compactMap { createMetadataItem(for:$0, value:$1) }
        playerInfo = meta
        playerItem?.externalMetadata = meta
        
        if let pic = pic, let imageURL = URL(string:pic) {
            let resource = ImageResource(downloadURL: imageURL)
            KingfisherManager.shared.retrieveImage(with: resource) {
                [weak self] result in
                guard let self = self,
                      let data = try? result.get().image.pngData(),
                      let item = self.createMetadataItem(for: .commonIdentifierArtwork, value: data)
                else { return }
                
                self.playerInfo?.removeAll{ $0.identifier == .commonIdentifierArtwork }
                self.playerInfo?.append(item)
                self.playerItem?.externalMetadata = self.playerInfo ?? []
            }
        }
    }
    
    
    private func createMetadataItem(for identifier: AVMetadataIdentifier,
                                    value: Any?) -> AVMetadataItem? {
        if value == nil {return nil}
        let item = AVMutableMetadataItem()
        item.identifier = identifier
        item.value = value as? NSCopying & NSObjectProtocol
        // Specify "und" to indicate an undefined language.
        item.extendedLanguageTag = "und"
        return item.copy() as? AVMetadataItem
    }
    
    private func setupPlayerMenu() {
        let danmuImage = UIImage(systemName: "list.bullet.rectangle.fill")
        let danmuImageDisable = UIImage(systemName: "list.bullet.rectangle")
        let danmuAction = UIAction(title: "Show Danmu", image: danMuView.isHidden ? danmuImageDisable : danmuImage) {
            [weak self] action in
            guard let self = self else { return }
            self.danMuView.isHidden.toggle()
            action.image = self.danMuView.isHidden ? danmuImageDisable : danmuImage
        }
        transportBarCustomMenuItems = [danmuAction]
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
