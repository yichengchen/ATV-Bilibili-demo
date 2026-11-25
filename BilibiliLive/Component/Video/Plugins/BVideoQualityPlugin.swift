//
//  BVideoQualityPlugin.swift
//  BilibiliLive
//

import AVKit

class BVideoQualityPlugin: NSObject, CommonPlayerPlugin {
    private weak var playerVC: AVPlayerViewController?
    private let playData: PlayerDetailData
    private var availableQualities: [QualityOption] = []
    private var currentStreamIndex: Int? // 当前选中的流索引
    private var isQualityLocked: Bool = false // 是否手动锁定了画质
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

        // 从 VideoPlayURLInfo 中提取可用画质
        extractAvailableQualities()
    }

    func playerDidLoad(playerVC: AVPlayerViewController) {
        self.playerVC = playerVC
    }

    private func extractAvailableQualities() {
        let supportFormats = playData.videoPlayURLInfo.support_formats
        let videoStreams = playData.videoPlayURLInfo.dash.video

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

        availableQualities = StreamMenuFormatting.sortVODStreams(candidates, preferAvc: Settings.preferAvc).map { candidate in
            let groupTitle = candidate.fallbackDescription ?? "画质 \(candidate.id)"
            return QualityOption(
                id: candidate.id,
                title: StreamMenuFormatting.formatVODStreamTitle(candidate),
                groupTitle: groupTitle,
                streamIndex: candidate.streamIndex
            )
        }
    }

    func addMenuItems(current _: inout [UIMenuElement]) -> [UIMenuElement] {
        guard !availableQualities.isEmpty else { return [] }

        let qualityImage = UIImage(systemName: "video.fill")

        // 按画质 ID 分组，并在组内保持按码率降序
        let groupedQualities = Dictionary(grouping: availableQualities, by: { $0.id })
        let sortedQualityIds = groupedQualities.keys.sorted(by: >)

        // 为每个画质档位创建内联分组，每条流直接显示完整规格（分辨率、帧率、HDR/杜比视界、编码与码率）
        let qualitySubmenus = sortedQualityIds.map { qualityId -> UIMenu in
            let streams = groupedQualities[qualityId] ?? []
            let menuTitle = streams.first?.groupTitle ?? "画质 \(qualityId)"

            let streamActions = streams.map { quality -> UIAction in
                let isCurrentStream = quality.streamIndex == currentStreamIndex && isQualityLocked
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
        // 更新状态：标记为手动锁定
        isQualityLocked = true
        currentStreamIndex = quality.streamIndex

        // 触发画质切换
        onQualityChange?(quality.id, quality.streamIndex)
    }
}
