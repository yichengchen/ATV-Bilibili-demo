//
//  SponsorSkipPlugin.swift
//  BilibiliLive
//
//  Created by yicheng on 2/11/2024.
//

import AVKit

class SponsorSkipPlugin: NSObject, CommonPlayerPlugin {
    private var clipInfos: [SponsorBlockRequest.SkipSegment] = []
    private let bvid: String
    private let duration: Double
    private var observers = [Any]()
    private weak var playerVC: AVPlayerViewController?

    private var set = false

    init(bvid: String, duration: Int) {
        self.bvid = bvid
        self.duration = Double(duration)
    }

    func loadClips() async {
        do {
            clipInfos = try await SponsorBlockRequest.getSkipSegments(bvid: bvid)
            clipInfos = clipInfos.filter {
                abs(duration - $0.videoDuration) < 4
            }

            Logger.debug("[SponsorBlockRequest] get segs: \(clipInfos.map { "\($0.start)-\($0.end)" }.joined(separator: ","))")
            if !set, let player = await playerVC?.player {
                set = true
                sendClipToPlayer(player: player)
            }
        } catch {
            print(error)
        }
    }

    func sendClipToPlayer(player: AVPlayer) {
        for clip in clipInfos {
            let start: CMTime
            let end: CMTime

            let buttonText: String
            let autoSkip = Settings.enableSponsorBlock == .jump
            if autoSkip {
                start = CMTime(seconds: clip.start - 5, preferredTimescale: 1)
                end = CMTime(seconds: clip.start, preferredTimescale: 1)
                buttonText = "取消跳过广告"
            } else {
                start = CMTime(seconds: clip.start, preferredTimescale: 1)
                end = CMTime(seconds: clip.end - 1, preferredTimescale: 1)
                buttonText = "跳过广告"
            }

            let skipAction = { [weak player, weak self] in
                player?.seek(to: CMTime(seconds: Double(clip.end), preferredTimescale: 1), toleranceBefore: .zero, toleranceAfter: .zero)
                self?.playerVC?.contextualActions = []
            }

            let startObserver = player.addBoundaryTimeObserver(forTimes: [NSValue(time: start)], queue: .main) {
                [weak self] in
                guard let self = self else { return }
                let action: UIAction
                let identifier = UIAction.Identifier(clip.UUID)
                if autoSkip {
                    action = UIAction(title: buttonText, identifier: identifier) { [weak self] _ in
                        self?.playerVC?.contextualActions = []
                    }
                } else {
                    action = UIAction(title: buttonText, identifier: identifier) { _ in skipAction() }
                }
                playerVC?.contextualActions = [action]
            }
            observers.append(startObserver)

            let endObserver = player.addBoundaryTimeObserver(forTimes: [NSValue(time: end)], queue: .main) {
                [weak self] in
                guard let self = self else { return }
                if let action = playerVC?.contextualActions.first,
                   action.identifier.rawValue == clip.UUID, autoSkip
                {
                    skipAction()
                }
                playerVC?.contextualActions = []
            }
            observers.append(endObserver)
        }
    }

    func playerDidLoad(playerVC: AVPlayerViewController) {
        self.playerVC = playerVC
        Task {
            await loadClips()
        }
    }

    func playerWillStart(player: AVPlayer) {
        if !clipInfos.isEmpty {
            set = true
            sendClipToPlayer(player: player)
        }
    }

    func playerDidCleanUp(player: AVPlayer) {
        for observer in observers {
            player.removeTimeObserver(observer)
        }
    }
}
