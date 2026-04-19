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
    private var onLineCandidateChange: ((String) -> Void)?

    init(candidates: [LivePlayUrlInfo], onLineCandidateChange: @escaping (String) -> Void) {
        self.candidates = candidates
        self.onLineCandidateChange = onLineCandidateChange
        super.init()
    }

    func playerDidLoad(playerVC: AVPlayerViewController) {
        self.playerVC = playerVC
    }

    func addMenuItems(current: inout [UIMenuElement]) -> [UIMenuElement] {
        guard !candidates.isEmpty else {
            return []
        }

        if let urlAsset = playerVC?.player?.currentItem?.asset as? AVURLAsset {
            currentUrl = urlAsset.url.absoluteString
        }

        let actions = candidates.enumerated().map { idx, info in
            let title = "#\(idx + 1) \(info.formate ?? ""), \(info.codec_name ?? "")"
            return UIAction(title: title, state: self.currentUrl == info.url ? .on : .off) { [weak self] _ in
                self?.switchLineCandidate(info.url)
            }
        }

        let menu = UIMenu(title: "画面线路", image: UIImage(systemName: "video.fill"), options: [.singleSelection], children: actions)
        return [menu]
    }

    private func switchLineCandidate(_ url: String) {
        onLineCandidateChange?(url)
    }
}
