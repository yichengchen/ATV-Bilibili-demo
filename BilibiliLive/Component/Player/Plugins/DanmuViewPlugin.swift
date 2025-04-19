//
//  DanmuViewPlugin.swift
//  BilibiliLive
//
//  Created by yicheng on 2024/5/23.
//

import AVKit
import Combine
import UIKit

protocol DanmuProviderProtocol {
    var observerPlayerTime: Bool { get }
    var onSendTextModel: PassthroughSubject<DanmakuTextCellModel, Never> { get }
    func playerTimeChange(time: TimeInterval)
}

class DanmuViewPlugin: NSObject {
    let danMuView = DanmakuView()

    init(provider: DanmuProviderProtocol) {
        danmuProvider = provider
        super.init()
        provider.onSendTextModel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.shoot($0)
            }.store(in: &cancellable)

        Defaults.shared.$showDanmu
            .receive(on: DispatchQueue.main)
            .sink {
                [weak self] in
                self?.danMuView.isHidden = !$0
            }.store(in: &cancellable)
    }

    private let danmuProvider: DanmuProviderProtocol
    private var timeObserver: Any?
    private var cancellable = Set<AnyCancellable>()

    private func shoot(_ model: DanmakuCellModel) {
        danMuView.shoot(danmaku: model)
    }
}

extension DanmuViewPlugin: CommonPlayerPlugin {
    func playerWillStart(player: AVPlayer) {
        guard danmuProvider.observerPlayerTime else {
            return
        }
        player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 1),
                                       queue: DispatchQueue.global())
        { [weak self] time in
            guard let self else { return }
            if !Defaults.shared.showDanmu { return }
            let seconds = time.seconds
            danmuProvider.playerTimeChange(time: seconds)
        }
    }

    func playerDidCleanUp(player: AVPlayer) {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
    }

    func addViewToPlayerOverlay(container: UIView) {
        container.addSubview(danMuView)
        danMuView.makeConstraintsToBindToSuperview()
        danMuView.setNeedsLayout()
        danMuView.layoutIfNeeded()
        danMuView.paddingTop = 5
        danMuView.trackHeight = 50
        danMuView.displayArea = Settings.danmuArea.percent
        danMuView.recaculateTracks()
    }

    func playerDidStart(player: AVPlayer) {
        danMuView.play()
    }

    func playerDidPause(player: AVPlayer) {
        danMuView.pause()
    }

    func addMenuItems(current: inout [UIMenuElement]) -> [UIMenuElement] {
        let danmuImage = UIImage(systemName: "list.bullet.rectangle.fill")
        let danmuImageDisable = UIImage(systemName: "list.bullet.rectangle")
        let danmuAction = UIAction(title: "Show Danmu", image: danMuView.isHidden ? danmuImageDisable : danmuImage) {
            action in
            Defaults.shared.showDanmu.toggle()
            action.image = Defaults.shared.showDanmu ? danmuImage : danmuImageDisable
        }
        let danmuDurationMenu = UIMenu(title: "弹幕展示时长", options: [.displayInline, .singleSelection], children: [4, 6, 8].map { dur in
            UIAction(title: "\(dur) 秒", state: dur == Settings.danmuDuration ? .on : .off) { _ in Settings.danmuDuration = dur }
        })
        let danmuAILevelMenu = UIMenu(title: "弹幕屏蔽等级", options: [.displayInline, .singleSelection], children: [Int32](1...10).map { level in
            UIAction(title: "\(level)", state: level == Settings.danmuAILevel ? .on : .off) { _ in Settings.danmuAILevel = level }
        })
        let danmuSettingMenu = UIMenu(title: "弹幕设置", image: UIImage(systemName: "keyboard.badge.ellipsis"), children: [danmuDurationMenu, danmuAILevelMenu])

        return [danmuAction, danmuSettingMenu]
    }
}
