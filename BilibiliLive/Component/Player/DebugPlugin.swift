//
//  DebugPlugin.swift
//  BilibiliLive
//
//  Created by yicheng on 2024/5/25.
//

import AVKit
import UIKit

class DebugPlugin: CommonPlayerPlugin {
    private var debugView: UILabel?
    private weak var containerView: UIView?
    private var debugTimer: Timer?
    private weak var player: AVPlayer?
    private var debugEnable: Bool { debugTimer?.isValid ?? false }

    var customInfo: String = ""
    var additionDebugInfo: (() -> String)?

    func addViewToPlayerOverlay(container: UIView) {
        containerView = container
    }

    func playerDidChange(player: AVPlayer) {
        self.player = player
    }

    func addMenuItems(current: [UIMenuElement]) -> [UIMenuElement] {
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
        if let setting = current.compactMap({ $0 as? UIMenu })
            .first(where: { $0.identifier == UIMenu.Identifier(rawValue: "setting") })
        {
            var child = setting.children
            child.append(debugAction)
            setting.replacingChildren(child)
            return []
        }
        return [debugAction]
    }

    deinit {
        debugTimer?.invalidate()
    }

    private func startDebug() {
        if debugView == nil {
            debugView = UILabel()
            debugView?.backgroundColor = UIColor.black.withAlphaComponent(0.8)
            debugView?.textColor = UIColor.white
            containerView?.addSubview(debugView!)
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

    private func fetchDebugInfo() -> String {
        let bitrateStr: (Double) -> String = {
            bit in
            String(format: "%.2fMbps", bit / 1024.0 / 1024.0)
        }
        guard let player else { return "Player no init" }

        var logs = """
        time control status: \(player.timeControlStatus.rawValue) \(player.reasonForWaitingToPlay?.rawValue ?? "")
        player status:\(player.status.rawValue)
        """

        guard let log = player.currentItem?.accessLog() else { return logs }
        guard let item = log.events.last else { return logs }
        let uri = item.uri ?? ""
        let addr = item.serverAddress ?? ""
        let changes = item.numberOfServerAddressChanges
        let dropped = item.numberOfDroppedVideoFrames
        let stalls = item.numberOfStalls
        let averageAudioBitrate = item.averageAudioBitrate
        let averageVideoBitrate = item.averageVideoBitrate
        let indicatedBitrate = item.indicatedBitrate
        let observedBitrate = item.observedBitrate
        logs += """
        uri:\(uri), ip:\(addr), change:\(changes)
        drop:\(dropped) stalls:\(stalls)
        bitrate audio:\(bitrateStr(averageAudioBitrate)), video: \(bitrateStr(averageVideoBitrate))
        observedBitrate:\(bitrateStr(observedBitrate))
        indicatedAverageBitrate:\(bitrateStr(indicatedBitrate))
        """

        if let additionDebugInfo = additionDebugInfo?() {
            logs = additionDebugInfo + "\n" + logs
        }
        if customInfo.isEmpty == false {
            logs = logs + "\n" + customInfo
        }
        return logs
    }
}
