//
//  LineCandidatePlugin.swift
//  BilibiliLive
//

import AVKit
import UIKit

class LineCandidatesPlugin: NSObject, CommonPlayerPlugin {
    private weak var playerVC: AVPlayerViewController?
    private var candidates: [LivePlayUrlInfo]
    private var currentUrl: String?
    private var measuredFPSByURL = [String: Double]()
    private var fpsProbeTask: Task<Void, Never>?
    private var onLineCandidateChange: ((String) -> Void)?

    init(candidates: [LivePlayUrlInfo], onLineCandidateChange: @escaping (String) -> Void) {
        self.candidates = candidates
        currentUrl = candidates.first?.url
        self.onLineCandidateChange = onLineCandidateChange
        super.init()
    }

    deinit {
        fpsProbeTask?.cancel()
    }

    func updateCandidates(_ candidates: [LivePlayUrlInfo]) {
        self.candidates = candidates
        if !candidates.contains(where: { StreamMenuFormatting.isSameStreamURL($0.url, currentUrl) }) {
            currentUrl = candidates.first?.url
        }
        (playerVC?.parent as? CommonPlayerViewController)?.updateMenus()
    }

    func playerDidLoad(playerVC: AVPlayerViewController) {
        self.playerVC = playerVC
        if let player = playerVC.player {
            if let url = currentURL(of: player) {
                currentUrl = url
            }
            if player.rate > 0 {
                scheduleFPSProbeIfNeeded(for: player)
            }
        }
    }

    func playerDidChange(player: AVPlayer) {
        if let url = currentURL(of: player) {
            currentUrl = url
        }
    }

    func playerDidStart(player: AVPlayer) {
        if let url = currentURL(of: player) {
            currentUrl = url
        }
        scheduleFPSProbeIfNeeded(for: player)
    }

    func playerDidCleanUp(player _: AVPlayer) {
        fpsProbeTask?.cancel()
        fpsProbeTask = nil
    }

    func addMenuItems(current _: inout [UIMenuElement]) -> [UIMenuElement] {
        guard !candidates.isEmpty else {
            return []
        }

        if let player = playerVC?.player {
            if player.timeControlStatus == .playing {
                _ = recordMeasuredFPSIfAvailable(from: player)
            }
            if let url = currentURL(of: player) {
                currentUrl = url
            }
        }
        if currentUrl == nil {
            currentUrl = candidates.first?.url
        }

        let actions = candidates.enumerated().map { idx, info in
            let title = StreamMenuFormatting.formatLiveCandidateTitle(
                index: idx,
                candidate: info,
                measuredFPS: measuredFPSByURL[info.url]
            )
            let isSelected = StreamMenuFormatting.isSameStreamURL(self.currentUrl, info.url)
            return UIAction(title: title, state: isSelected ? .on : .off) { [weak self] _ in
                self?.switchLineCandidate(info.url)
            }
        }

        let menu = UIMenu(title: "画面线路", image: UIImage(systemName: "video.fill"), options: [.singleSelection], children: actions)
        return [menu]
    }

    private func scheduleFPSProbeIfNeeded(for player: AVPlayer) {
        guard let url = currentURL(of: player), measuredFPSByURL[url] == nil else {
            return
        }

        fpsProbeTask?.cancel()
        fpsProbeTask = Task { @MainActor [weak self, weak player] in
            // Wait up to 6s for initial buffering to transition into actual .playing
            var startedPlaying = false
            for _ in 0..<12 {
                guard !Task.isCancelled, let player else { return }
                if player.timeControlStatus == .playing {
                    startedPlaying = true
                    break
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
            guard startedPlaying, !Task.isCancelled else { return }

            // Allow ~1.2s of steady frame rendering so currentVideoFrameRate stabilizes
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled,
                  let self,
                  let player,
                  player.timeControlStatus == .playing
            else {
                return
            }
            if self.recordMeasuredFPSIfAvailable(from: player) {
                (self.playerVC?.parent as? CommonPlayerViewController)?.updateMenus()
            }
        }
    }

    private func currentURL(of player: AVPlayer) -> String? {
        (player.currentItem?.asset as? AVURLAsset)?.url.absoluteString
    }

    @discardableResult
    private func recordMeasuredFPSIfAvailable(from player: AVPlayer) -> Bool {
        guard let item = player.currentItem,
              let url = currentURL(of: player),
              measuredFPSByURL[url] == nil
        else {
            return false
        }
        let detected = item.tracks
            .map { Double($0.currentVideoFrameRate) }
            .max() ?? 0
        guard detected >= 10 else {
            return false
        }
        measuredFPSByURL[url] = detected
        return true
    }

    private func switchLineCandidate(_ url: String) {
        currentUrl = url
        (playerVC?.parent as? CommonPlayerViewController)?.updateMenus()
        onLineCandidateChange?(url)
    }
}
