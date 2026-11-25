//
//  BVideoQualityPlugin.swift
//  BilibiliLive
//

import AVKit

class BVideoQualityPlugin: NSObject, CommonPlayerPlugin {
    private weak var playerVC: AVPlayerViewController?
    private let playData: PlayerDetailData
    private var availableQualities: [QualityOption] = []
    private var currentStreamIndex: Int? // 当前正在播放或锁定的流索引
    private var isQualityLocked: Bool = false // 是否手动锁定了具体流
    private var accessLogObserver: NSObjectProtocol?
    private var onQualityChange: ((Int, Int?) -> Void)? // (qualityId, streamIndex)

    struct QualityOption {
        let id: Int
        let title: String
        let groupTitle: String
        let streamIndex: Int // 在 dash.video 数组中的索引（用于精确定位流）
    }

    init(detailData: PlayerDetailData, onQualityChange: @escaping (Int, Int?) -> Void) {
        playData = detailData
        self.onQualityChange = onQualityChange
        super.init()

        // 从 VideoPlayURLInfo 中提取可用画质及默认起播流索引
        extractAvailableQualities()
    }

    deinit {
        removeAccessLogObserver()
    }

    func playerDidLoad(playerVC: AVPlayerViewController) {
        self.playerVC = playerVC
        if let player = playerVC.player {
            observeAccessLog(for: player)
        }
    }

    func playerDidChange(player: AVPlayer) {
        observeAccessLog(for: player)
    }

    func playerDidCleanUp(player _: AVPlayer) {
        removeAccessLogObserver()
    }

    private func extractAvailableQualities() {
        let supportFormats = playData.videoPlayURLInfo.support_formats
        let videoStreams = playData.videoPlayURLInfo.dash.video
        let preferAvc = Settings.preferAvc

        let candidates = videoStreams.enumerated().map { index, stream in
            let format = supportFormats.first { $0.quality == stream.id }
            let fallbackDesc = [format?.new_description, format?.display_desc]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first { !$0.isEmpty }
            return VODStreamCandidate(
                id: stream.id,
                width: stream.width,
                height: stream.height,
                frameRate: stream.frame_rate,
                codecs: stream.codecs,
                bandwidth: stream.bandwidth,
                fallbackDescription: fallbackDesc,
                streamIndex: index
            )
        }

        availableQualities = StreamMenuFormatting.sortVODStreams(candidates, preferAvc: preferAvc).map { candidate in
            let groupTitle = candidate.fallbackDescription ?? "画质 \(candidate.id)"
            return QualityOption(
                id: candidate.id,
                title: StreamMenuFormatting.formatVODStreamTitle(candidate),
                groupTitle: groupTitle,
                streamIndex: candidate.streamIndex
            )
        }

        // 初始选中与播放器起播规则一致的首选流
        currentStreamIndex = StreamMenuFormatting.initialVODStreamIndex(
            streams: candidates,
            qualityLimit: Settings.mediaQuality.qn,
            preferAvc: preferAvc
        )
    }

    private func observeAccessLog(for player: AVPlayer) {
        removeAccessLogObserver()
        _ = syncActiveStreamFromAccessLog(player: player)
        guard let item = player.currentItem else { return }
        accessLogObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemNewAccessLogEntry,
            object: item,
            queue: .main
        ) { [weak self, weak player] _ in
            guard let self, let player, !self.isQualityLocked else { return }
            if self.syncActiveStreamFromAccessLog(player: player) {
                (self.playerVC?.parent as? CommonPlayerViewController)?.updateMenus()
            }
        }
    }

    private func removeAccessLogObserver() {
        if let accessLogObserver {
            NotificationCenter.default.removeObserver(accessLogObserver)
        }
        accessLogObserver = nil
    }

    @discardableResult
    private func syncActiveStreamFromAccessLog(player: AVPlayer) -> Bool {
        guard !isQualityLocked,
              let uri = player.currentItem?.accessLog()?.events.last?.uri,
              let detectedIndex = StreamMenuFormatting.parseDashStreamIndex(fromURI: uri),
              availableQualities.contains(where: { $0.streamIndex == detectedIndex }),
              detectedIndex != currentStreamIndex
        else {
            return false
        }
        currentStreamIndex = detectedIndex
        return true
    }

    func addMenuItems(current _: inout [UIMenuElement]) -> [UIMenuElement] {
        guard !availableQualities.isEmpty else { return [] }

        if let player = playerVC?.player {
            _ = syncActiveStreamFromAccessLog(player: player)
        }

        let qualityImage = UIImage(systemName: "video.fill")

        // 按画质 ID 分组，并在组内保持编码优先级与码率降序
        let groupedQualities = Dictionary(grouping: availableQualities, by: { $0.id })
        let sortedQualityIds = groupedQualities.keys.sorted(by: >)

        // 为每个画质档位创建内联分组，每条流直接显示完整规格（分辨率、帧率、HDR/杜比视界、编码与码率）
        let qualitySubmenus = sortedQualityIds.map { qualityId -> UIMenu in
            let streams = groupedQualities[qualityId] ?? []
            let menuTitle = streams.first?.groupTitle ?? "画质 \(qualityId)"

            let streamActions = streams.map { quality -> UIAction in
                let isCurrentStream = quality.streamIndex == currentStreamIndex
                return UIAction(
                    title: quality.title,
                    state: isCurrentStream ? .on : .off
                ) { [weak self] _ in
                    self?.switchQuality(to: quality)
                }
            }

            return UIMenu(
                title: menuTitle,
                options: [.displayInline],
                children: streamActions
            )
        }

        let qualityMenu = UIMenu(
            title: "画质",
            image: qualityImage,
            identifier: UIMenu.Identifier(rawValue: "quality"),
            children: qualitySubmenus
        )

        return [qualityMenu]
    }

    private func switchQuality(to quality: QualityOption) {
        // 更新状态：标记为手动锁定并立即刷新菜单勾选
        isQualityLocked = true
        currentStreamIndex = quality.streamIndex
        (playerVC?.parent as? CommonPlayerViewController)?.updateMenus()

        // 触发画质切换
        onQualityChange?(quality.id, quality.streamIndex)
    }
}
