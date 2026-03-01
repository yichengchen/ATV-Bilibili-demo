//
//  VideoPlayListPlugin.swift
//  BilibiliLive
//
//  Created by yicheng on 2024/5/26.
//

import AVKit

class VideoPlayListPlugin: NSObject, CommonPlayerPlugin {
    private let playNextActionIdentifierPrefix = "play.next"
    var onPlayEnd: (() -> Void)?
    var onPlayNextWithInfo: ((PlayInfo) -> Void)?

    let nextProvider: VideoNextProvider?
    private weak var playerVC: AVPlayerViewController?

    init(nextProvider: VideoNextProvider?) {
        self.nextProvider = nextProvider
    }

    func playerDidLoad(playerVC: AVPlayerViewController) {
        self.playerVC = playerVC
    }

    func playerWillStart(player: AVPlayer) {
        guard let playerVC, let nextProvider, nextProvider.count > 1 else { return }

        MainActor.callSafely { [weak self] in
            guard let self = self else { return }
            // Remove previous "next" action if present
            if let last = playerVC.infoViewActions.last,
               last.identifier.rawValue.hasPrefix(self.playNextActionIdentifierPrefix)
            {
                playerVC.infoViewActions.removeLast()
            }

            if let next = nextProvider.peekNext() {
                let nextAction = UIAction(title: "下一集",
                                          image: UIImage(systemName: "forward.end.fill"),
                                          identifier: .init(rawValue: "\(self.playNextActionIdentifierPrefix).\(next.aid).\(next.cid ?? 0)"))
                { [weak self] _ in
                    _ = self?.playNext()
                }
                playerVC.infoViewActions.append(nextAction)
            }
        }
    }

    func addMenuItems(current: inout [UIMenuElement]) -> [UIMenuElement] {
        // 循环模式菜单
        let loopActions = LoopMode.allCases.map { mode in
            UIAction(
                title: mode.title,
                image: UIImage(systemName: mode.icon),
                state: Settings.loopMode == mode ? .on : .off
            ) { [weak self] _ in
                Settings.loopMode = mode
                self?.updateLoopModeMenu()
            }
        }

        let loopMenu = UIMenu(
            title: "循环模式",
            image: UIImage(systemName: Settings.loopMode.icon),
            options: [.displayInline, .singleSelection],
            children: loopActions
        )

        // 连续播放开关
        let continousAction = UIAction(
            title: "自动连播",
            image: UIImage(systemName: "play.fill"),
            state: Settings.continouslyPlay ? .on : .off
        ) { action in
            Settings.continouslyPlay.toggle()
            action.state = Settings.continouslyPlay ? .on : .off
        }

        // 添加到播放设置菜单
        if let settingsIndex = current.firstIndex(where: { ($0 as? UIMenu)?.identifier.rawValue == "setting" }),
           let settingsMenu = current[settingsIndex] as? UIMenu
        {
            var children = settingsMenu.children
            children.append(continousAction)
            children.append(loopMenu)
            let newSettingsMenu = settingsMenu.replacingChildren(children)
            current[settingsIndex] = newSettingsMenu
            return []
        }

        // 如果没有播放设置菜单，创建一个新的
        let menu = UIMenu(
            title: "播放设置",
            image: UIImage(systemName: "play.circle"),
            identifier: UIMenu.Identifier(rawValue: "playlist_setting"),
            children: [continousAction, loopMenu]
        )
        return [menu]
    }

    private func updateLoopModeMenu() {
        // 菜单状态会在下次打开时自动更新
        Logger.debug("[PlayListPlugin] Loop mode changed to: \(Settings.loopMode.title)")
    }

    func playerDidEnd(player: AVPlayer) {
        switch Settings.loopMode {
        case .single:
            // 单集循环：重新播放当前视频
            player.currentItem?.seek(to: .zero, completionHandler: nil)
            player.play()
            Logger.debug("[PlayListPlugin] Single loop: replaying current video")

        case .list:
            // 列表循环：播放下一个，如果没有则重置列表
            if !playNext() {
                nextProvider?.reset()
                if !playNext() {
                    // 列表只有一个视频，重新播放
                    player.currentItem?.seek(to: .zero, completionHandler: nil)
                    player.play()
                }
            }
            Logger.debug("[PlayListPlugin] List loop: playing next or reset")

        case .none:
            // 不循环：尝试播放下一个，如果没有则结束
            if Settings.continouslyPlay {
                if !playNext() {
                    onPlayEnd?()
                }
            } else {
                onPlayEnd?()
            }
        }
    }

    private func playNext() -> Bool {
        guard Settings.continouslyPlay else { return false }
        if let next = nextProvider?.getNext() {
            onPlayNextWithInfo?(next)
            return true
        }
        return false
    }
}
