//
//  VideoPlayListPlugin.swift
//  BilibiliLive
//
//  Created by yicheng on 2024/5/26.
//

import AVKit

class VideoPlayListPlugin: NSObject, CommonPlayerPlugin {
    private let playNextActionIdentifierPrefix = "play.next"
    private weak var playerVC: AVPlayerViewController?
    var onPlayEnd: (() -> Void)?
    var onPlayNextWithInfo: ((PlayInfo) -> Void)?

    let nextProvider: VideoNextProvider?

    init(nextProvider: VideoNextProvider?) {
        self.nextProvider = nextProvider
    }

    func playerDidLoad(playerVC: AVPlayerViewController) {
        self.playerVC = playerVC
    }

    func playerWillStart(player: AVPlayer) {
        guard let playerVC, let nextProvider, nextProvider.count > 1 else { return }

        // 仅当最后一项是我们之前添加的 "next" action 时才移除，避免误删其他自定义 action
        if let last = playerVC.infoViewActions.last,
           last.identifier.rawValue.hasPrefix(playNextActionIdentifierPrefix)
        {
            playerVC.infoViewActions.removeLast()
        }

        if let next = nextProvider.peekNext() {
            let title = next.title ?? "下一集"
            let nextAction = UIAction(title: title,
                                      image: UIImage(systemName: "forward.end.fill"),
                                      identifier: .init(rawValue: "\(playNextActionIdentifierPrefix).\(next.aid).\(next.cid ?? 0)"))
            { [weak self] _ in
                _ = self?.playNext()
            }
            playerVC.infoViewActions.append(nextAction)
        }
    }

    func addMenuItems(current: inout [UIMenuElement]) -> [UIMenuElement] {
        let loopImage = UIImage(systemName: "infinity")
        let loopAction = UIAction(title: "循环播放", image: loopImage, state: Settings.loopPlay ? .on : .off) {
            action in
            action.state = (action.state == .off) ? .on : .off
            Settings.loopPlay = action.state == .on
        }
        if let setting = current.compactMap({ $0 as? UIMenu })
            .first(where: { $0.identifier == UIMenu.Identifier(rawValue: "setting") })
        {
            var child = setting.children
            child.append(loopAction)
            if let index = current.firstIndex(of: setting) {
                current[index] = setting.replacingChildren(child)
            }
            return []
        }
        return [loopAction]
    }

    func playerDidEnd(player: AVPlayer) {
        if !playNext() {
            if Settings.loopPlay {
                nextProvider?.reset()
                if !playNext() {
                    player.currentItem?.seek(to: .zero, completionHandler: nil)
                    player.play()
                }
                return
            }
            onPlayEnd?()
        }
    }

    private func playNext() -> Bool {
        if let next = nextProvider?.getNext() {
            onPlayNextWithInfo?(next)
            return true
        }
        return false
    }
}
