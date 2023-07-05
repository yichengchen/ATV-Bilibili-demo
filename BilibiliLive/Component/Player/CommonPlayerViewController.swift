//
//  CommonPlayerViewController.swift
//  BilibiliLive
//
//  Created by Etan Chen on 2021/4/4.
//

import AVKit
import Kingfisher
import UIKit
import Vision

protocol MaskProvider: AnyObject {
    func getMask(for time: CMTime, frame: CGRect, onGet: @escaping (CALayer) -> Void)
    func needVideoOutput() -> Bool
    func setVideoOutout(ouput: AVPlayerItemVideoOutput)
    func preferFPS() -> Int
}

class CommonPlayerViewController: AVPlayerViewController {
    let danMuView = DanmakuView()
    var allowChangeSpeed = true
    var playerStartPos: Int?
    private var retryCount = 0
    private let maxRetryCount = 3
    private var observer: NSKeyValueObservation?
    private var rateObserver: NSKeyValueObservation?
    private var debugView: UILabel?
    var maskProvider: MaskProvider?

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

    var videoOutput: AVPlayerItemVideoOutput?

    private var playerInfo: [AVMetadataItem]?

    deinit {
        stopDebug()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        appliesPreferredDisplayCriteriaAutomatically = Settings.contentMatch
        allowsPictureInPicturePlayback = true
        delegate = self
        initDanmuView()
        setupPlayerMenu()
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

    func extraInfoForPlayerError() -> String {
        return ""
    }

    func playerStatusDidChange() {
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
    }

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
                UIAction(title: playSpeed.name, state: player?.rate ?? 1 == playSpeed.value ? .on : .off) { [weak self] action in
                    self?.player?.currentItem?.audioTimePitchAlgorithm = .timeDomain
                    if #available(tvOS 16.0, *) {
                        self?.selectSpeed(AVPlaybackSpeed(rate: playSpeed.value, localizedName: playSpeed.name))
                    } else {
                        self?.player?.rate = playSpeed.value
                    }
                    self?.danMuView.playingSpeed = playSpeed.value
                }
            }
            let playSpeedMenu = UIMenu(title: "播放速度", options: [.displayInline, .singleSelection], children: speedActions)
            let menu = UIMenu(title: "播放设置", image: gearImage, children: [playSpeedMenu, loopAction, debugAction])
            menus.append(menu)
        } else {
            menus.append(debugAction)
        }

        transportBarCustomMenuItems = menus
    }

    private func removeObservarPlayerItem() {
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
    }

    private func observePlayerItem(_ playerItem: AVPlayerItem) {
        observer = playerItem.observe(\.status, options: [.new, .old]) {
            [weak self] _, _ in
            self?.playerStatusDidChange()
        }
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(playerDidFinishPlaying),
                                               name: .AVPlayerItemDidPlayToEndTime,
                                               object: playerItem)
    }

    func setupMask() {
        guard let maskProvider else { return }
//        danMuView.backgroundColor = UIColor.red.withAlphaComponent(0.5)
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

    func retryPlay() -> Bool {
        return false
    }

    @objc private func playerDidFinishPlaying() {
        playDidEnd()
    }

    func playDidEnd() {}

    func showErrorAlertAndExit(title: String = "播放失败", message: String = "未知错误") {
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
            player?.seek(to: CMTime(seconds: Double(playerStartPos), preferredTimescale: 1), toleranceBefore: .zero, toleranceAfter: .zero)
        }
        player?.play()
    }

    private func fetchDebugInfo() -> String {
        let bitrateStr: (Double) -> String = {
            bit in
            return String(format: "%.2fMbps", bit / 1024.0 / 1024.0)
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

    func additionDebugInfo() -> String { return "" }

    var debugTimer: Timer?
    var debugEnable: Bool { debugTimer?.isValid ?? false }
    private func startDebug() {
        if debugView == nil {
            debugView = UILabel()
            debugView?.backgroundColor = UIColor.black.withAlphaComponent(0.8)
            debugView?.textColor = UIColor.white
            view.addSubview(debugView!)
            debugView?.numberOfLines = 0
            debugView?.font = UIFont.systemFont(ofSize: 26)
            debugView?.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(12)
                make.right.equalToSuperview().offset(-12)
                make.width.equalTo(800)
            }
        }
        debugView?.isHidden = false
        debugTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            let info = self?.fetchDebugInfo()
            self?.debugView?.text = info
        }
    }

    private func stopDebug() {
        debugTimer?.invalidate()
        debugTimer = nil
        debugView?.isHidden = true
    }

    private func initDanmuView() {
        view.addSubview(danMuView)
        danMuView.accessibilityLabel = "danmuView"
        danMuView.makeConstraintsToBindToSuperview()
        danMuView.isHidden = !Settings.defaultDanmuStatus
    }

    func setUpOutput() {
        guard videoOutput == nil, let videoItem = player?.currentItem else { return }
        let pixelBuffAttributes = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
        ]
        let videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: pixelBuffAttributes)
        videoItem.add(videoOutput)
        self.videoOutput = videoOutput
        maskProvider?.setVideoOutout(ouput: videoOutput)
    }

    func ensureDanmuViewFront() {
        view.bringSubviewToFront(danMuView)
        danMuView.play()
    }
}

extension CommonPlayerViewController: AVPlayerViewControllerDelegate {
    @objc func playerViewControllerShouldDismiss(_ playerViewController: AVPlayerViewController) -> Bool {
        if let presentedViewController = UIViewController.topMostViewController() as? AVPlayerViewController,
           presentedViewController == playerViewController
        {
            return true
        }
        return false
    }

    @objc func playerViewControllerShouldAutomaticallyDismissAtPictureInPictureStart(_ playerViewController: AVPlayerViewController) -> Bool {
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
                (playerViewController as? CommonPlayerViewController)?.ensureDanmuViewFront()
            }
        } else {
            presentedViewController.present(playerViewController, animated: false) {
                completionHandler(true)
                (playerViewController as? CommonPlayerViewController)?.ensureDanmuViewFront()
            }
        }
    }
}

struct PlaySpeed {
    var name: String
    var value: Float
}
