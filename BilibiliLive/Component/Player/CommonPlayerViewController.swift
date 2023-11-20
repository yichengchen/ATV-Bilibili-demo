//
//  CommonPlayerViewController.swift
//  BilibiliLive
//
//  Created by Etan Chen on 2021/4/4.
//

import AVKit
import Kingfisher
import UIKit

class CommonPlayerViewController: UIViewController {
    let playerVC = AVPlayerViewController()
    let overlayView = CommonPlayerOverlayView()
    var allowChangeSpeed = true
    var playerStartPos: Int?
    var maskProvider: MaskProvider? {
        didSet { if maskProvider != nil { setupMask() }}
    }

    var danMuView: DanmakuView { overlayView.danMuView }

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

    var player: AVPlayer? {
        get {
            playerVC.player
        }
        set {
            playerVC.player = newValue
            if let player = newValue {
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

    private var retryCount = 0
    private let maxRetryCount = 3
    private var observer: NSKeyValueObservation?
    private var rateObserver: NSKeyValueObservation?
    private var videoOutput: AVPlayerItemVideoOutput?
    private var playerInfo: [AVMetadataItem]?
    private var debugTimer: Timer?
    private var debugEnable: Bool { debugTimer?.isValid ?? false }

    // MARK: Lifecycle

    deinit {
        stopDebug()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(playerVC)
        view.addSubview(playerVC.view)
        playerVC.didMove(toParent: self)
        playerVC.view.makeConstraintsToBindToSuperview()
        playerVC.appliesPreferredDisplayCriteriaAutomatically = Settings.contentMatch
        playerVC.allowsPictureInPicturePlayback = true
        playerVC.delegate = self
        playerVC.contentOverlayView?.addSubview(overlayView)
        overlayView.makeConstraintsToBindToSuperview()
        setNeedsFocusUpdate()
        updateFocusIfNeeded()
        setupPlayerMenu()
    }

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        return [self.playerVC.view]
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillAppear(animated)
        danMuView.stop()
    }

    // MARK: Public

    func setPlayerInfo(title: String?, subTitle: String?, desp: String?, pic: URL?) {
        let desp = desp?.components(separatedBy: "\n").joined(separator: " ")
        let mapping: [AVMetadataIdentifier: Any?] = [
            .commonIdentifierTitle: title,
            .iTunesMetadataTrackSubTitle: subTitle,
            .commonIdentifierDescription: desp,
        ]
        let meta = mapping.compactMap { createMetadataItem(for: $0, value: $1) }
        playerInfo = meta
        playerItem?.externalMetadata = meta

        if let pic = pic {
            let resource = Kingfisher.ImageResource(downloadURL: pic)
            KingfisherManager.shared.retrieveImage(with: resource) {
                [weak self] result in
                guard let self = self,
                      let data = try? result.get().image.pngData(),
                      let item = self.createMetadataItem(for: .commonIdentifierArtwork, value: data)
                else { return }

                self.playerInfo?.removeAll { $0.identifier == .commonIdentifierArtwork }
                self.playerInfo?.append(item)
                self.playerItem?.externalMetadata = self.playerInfo ?? []
            }
        }
    }

    func createMetadataItem(for identifier: AVMetadataIdentifier,
                            value: Any?) -> AVMetadataItem?
    {
        if value == nil { return nil }
        let item = AVMutableMetadataItem()
        item.identifier = identifier
        item.value = value as? NSCopying & NSObjectProtocol
        // Specify "und" to indicate an undefined language.
        item.extendedLanguageTag = "und"
        return item.copy() as? AVMetadataItem
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

    // MARK: For Override

    func extraInfoForPlayerError() -> String {
        return ""
    }

    func retryPlay() -> Bool {
        return false
    }

    func playerStatusDidChange() {}

    func playDidEnd() {}

    func additionDebugInfo() -> String { return "" }
}

// MARK: Private

extension CommonPlayerViewController {
    private func setupPlayerMenu() {
        var menus = [UIMenuElement]()
        let danmuImage = UIImage(systemName: "list.bullet.rectangle.fill")
        let danmuImageDisable = UIImage(systemName: "list.bullet.rectangle")
        let danmuAction = UIAction(title: "Show Danmu", image: danMuView.isHidden ? danmuImageDisable : danmuImage) {
            [weak self] action in
            guard let self = self else { return }
            Settings.defaultDanmuStatus.toggle()
            self.danMuView.isHidden.toggle()
            action.image = self.danMuView.isHidden ? danmuImageDisable : danmuImage
        }
        menus.append(danmuAction)

        let danmuDurationMenu = UIMenu(title: "弹幕展示时长", options: [.displayInline, .singleSelection], children: [4, 6, 8].map { dur in
            UIAction(title: "\(dur) 秒", state: dur == Settings.danmuDuration ? .on : .off) { _ in Settings.danmuDuration = dur }
        })
        let danmuAILevelMenu = UIMenu(title: "弹幕屏蔽等级", options: [.displayInline, .singleSelection], children: [Int32](1...10).map { level in
            UIAction(title: "\(level)", state: level == Settings.danmuAILevel ? .on : .off) { _ in Settings.danmuAILevel = level }
        })
        let danmuSettingMenu = UIMenu(title: "弹幕设置", image: UIImage(systemName: "keyboard.badge.ellipsis"), children: [danmuDurationMenu, danmuAILevelMenu])
        menus.append(danmuSettingMenu)

        let debugEnableImage = UIImage(systemName: "terminal.fill")
        let debugDisableImage = UIImage(systemName: "terminal")
        let debugAction = UIAction(title: "Debug", image: debugEnable ? debugEnableImage : debugDisableImage) {
            [weak self] action in
            guard let self = self else { return }
            if self.debugEnable {
                self.stopDebug()
                action.image = debugDisableImage
            } else {
                action.image = debugEnableImage
                self.startDebug()
            }
        }

        if allowChangeSpeed {
            // Create ∞ and ⚙ images.
            let loopImage = UIImage(systemName: "infinity")
            let gearImage = UIImage(systemName: "gearshape")

            // Create an action to enable looping playback.
            let loopAction = UIAction(title: "循环播放", image: loopImage, state: Settings.loopPlay ? .on : .off) {
                action in
                action.state = (action.state == .off) ? .on : .off
                Settings.loopPlay = action.state == .on
            }

            let playSpeedArray = [PlaySpeed(name: "0.5X", value: 0.5),
                                  PlaySpeed(name: "0.75X", value: 0.75),
                                  PlaySpeed(name: "1X", value: 1),
                                  PlaySpeed(name: "1.25X", value: 1.25),
                                  PlaySpeed(name: "1.5X", value: 1.5),
                                  PlaySpeed(name: "2X", value: 2)]

            let speedActions = playSpeedArray.map { playSpeed in
                UIAction(title: playSpeed.name, state: player?.rate ?? 1 == playSpeed.value ? .on : .off) { [weak self] _ in
                    guard let self else { return }
                    player?.currentItem?.audioTimePitchAlgorithm = .timeDomain
                    if #available(tvOS 16.0, *) {
                        playerVC.selectSpeed(AVPlaybackSpeed(rate: playSpeed.value, localizedName: playSpeed.name))
                    } else {
                        player?.rate = playSpeed.value
                    }
                    danMuView.playingSpeed = playSpeed.value
                }
            }
            let playSpeedMenu = UIMenu(title: "播放速度", options: [.displayInline, .singleSelection], children: speedActions)
            let menu = UIMenu(title: "播放设置", image: gearImage, children: [playSpeedMenu, loopAction, debugAction])
            menus.append(menu)
        } else {
            menus.append(debugAction)
        }

        playerVC.transportBarCustomMenuItems = menus
    }
}

// MARK: Player Notify

extension CommonPlayerViewController {
    private func removeObservarPlayerItem() {
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
    }

    private func observePlayerItem(_ playerItem: AVPlayerItem) {
        observer = playerItem.observe(\.status, options: [.new, .old]) {
            [weak self] _, _ in
            self?.playerStatusDidChangeInternal()
        }
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(playerDidFinishPlaying),
                                               name: .AVPlayerItemDidPlayToEndTime,
                                               object: playerItem)
    }

    private func playerStatusDidChangeInternal() {
        Logger.debug("player status: \(player?.currentItem?.status.rawValue ?? -1)")
        switch player?.currentItem?.status {
        case .readyToPlay:
            if maskProvider?.needVideoOutput() == true {
                setUpOutput()
            }
            startPlay()
        case .failed:
            removeObservarPlayerItem()
            Logger.debug(player?.currentItem?.error ?? "no error")
            Logger.debug(player?.currentItem?.errorLog() ?? "no error log")
            if retryCount < maxRetryCount, !retryPlay() {
                let log = playerItem?.errorLog()
                let errorLogData = log?.extendedLogData() ?? Data()
                var str = String(data: errorLogData, encoding: .utf8) ?? ""
                str = str.split(separator: "\n").dropFirst(4).joined()
                showErrorAlertAndExit(title: "播放器失败", message: str + extraInfoForPlayerError())
            }
            retryCount += 1
        default:
            break
        }
        playerStatusDidChange()
    }

    private func startPlay() {
        guard player?.rate == 0 && player?.error == nil else { return }
        if let playerStartPos = playerStartPos {
            player?.seek(to: CMTime(seconds: Double(playerStartPos), preferredTimescale: 1), toleranceBefore: .zero, toleranceAfter: .zero)
        }
        player?.play()
    }

    @objc private func playerDidFinishPlaying() {
        playDidEnd()
    }
}

// MARK: Masks

extension CommonPlayerViewController {
    private func setupMask() {
        guard let maskProvider else { return }
        Logger.info("mask provider is \(maskProvider)")
        let interval = CMTime(seconds: 1.0 / CGFloat(maskProvider.preferFPS()),
                              preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player?.addPeriodicTimeObserver(forInterval: interval, queue: .main, using: {
            [weak self, weak maskProvider] time in
            guard let self else { return }
            guard self.danMuView.isHidden == false else { return }
            maskProvider?.getMask(for: time, frame: self.danMuView.frame) {
                maskLayer in
                self.danMuView.layer.mask = maskLayer
            }
        })
    }

    private func setUpOutput() {
        guard videoOutput == nil, let videoItem = player?.currentItem else { return }
        let pixelBuffAttributes = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
        ]
        let videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: pixelBuffAttributes)
        videoItem.add(videoOutput)
        self.videoOutput = videoOutput
        maskProvider?.setVideoOutout(ouput: videoOutput)
    }
}

// MARK: Debugs

extension CommonPlayerViewController {
    private func fetchDebugInfo() -> String {
        let bitrateStr: (Double) -> String = {
            bit in
            String(format: "%.2fMbps", bit / 1024.0 / 1024.0)
        }

        guard let log = player?.currentItem?.accessLog() else { return "no log" }
        guard let item = log.events.last else { return "no event log" }
        let uri = item.uri ?? ""
        let addr = item.serverAddress ?? ""
        let changes = item.numberOfServerAddressChanges
        let dropped = item.numberOfDroppedVideoFrames
        let stalls = item.numberOfStalls
        let averageAudioBitrate = item.averageAudioBitrate
        let averageVideoBitrate = item.averageVideoBitrate
        let indicatedBitrate = item.indicatedBitrate
        let observedBitrate = item.observedBitrate
        return """
        uri:\(uri), ip:\(addr), change:\(changes)
        drop:\(dropped) stalls:\(stalls)
        bitrate audio:\(bitrateStr(averageAudioBitrate)), video: \(bitrateStr(averageVideoBitrate))
        observedBitrate:\(bitrateStr(observedBitrate))
        indicatedAverageBitrate:\(bitrateStr(indicatedBitrate))
        maskProvider: \(String(describing: maskProvider))  \(additionDebugInfo())
        """
    }

    private func startDebug() {
        overlayView.showDebugView()
        debugTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            overlayView.setDebug(text: fetchDebugInfo())
        }
    }

    private func stopDebug() {
        debugTimer?.invalidate()
        debugTimer = nil
        overlayView.hideDebugView()
    }
}

// MARK: - AVPlayerViewControllerDelegate

extension CommonPlayerViewController: AVPlayerViewControllerDelegate {
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
                (playerViewController.parent as? CommonPlayerViewController)?.overlayView.ensureDanmuViewFront()
            }
        } else {
            presentedViewController.present(playerViewController, animated: false) {
                completionHandler(true)
                (playerViewController.parent as? CommonPlayerViewController)?.overlayView.ensureDanmuViewFront()
            }
        }
    }
}

struct PlaySpeed {
    var name: String
    var value: Float
}
