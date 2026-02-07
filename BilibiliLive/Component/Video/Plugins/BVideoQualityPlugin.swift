//
//  BVideoQualityPlugin.swift
//  BilibiliLive
//

import AVKit

class BVideoQualityPlugin: NSObject, CommonPlayerPlugin {
    private weak var playerVC: AVPlayerViewController?
    private let playData: PlayerDetailData
    private var availableQualities: [QualityOption] = []
    private var currentQualityId: Int?
    private var currentStreamIndex: Int? // 当前选中的流索引
    private var isQualityLocked: Bool = false // 是否手动锁定了画质
    private var onQualityChange: ((Int, Int?) -> Void)? // (qualityId, streamIndex)

    struct QualityOption {
        let id: Int
        let name: String
        let description: String
        let bandwidth: Int // 该流的码率（bps）
        let codec: String // 编码格式（如 avc1, hev1）
        let streamIndex: Int? // 在 dash.video 数组中的索引（用于精确定位流）
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

        // 为每个视频流创建一个 QualityOption
        availableQualities = videoStreams.enumerated().map { index, stream in
            // 尝试从 support_formats 中找到该画质的描述信息
            let format = supportFormats.first { $0.quality == stream.id }
            let baseName = format?.new_description ?? "画质 \(stream.id)"

            // 提取编码类型（avc1 -> AVC, hev1 -> HEVC）
            let codecType: String
            if stream.codecs.starts(with: "avc") {
                codecType = "AVC"
            } else if stream.codecs.starts(with: "hev") || stream.codecs.starts(with: "hvc") {
                codecType = "HEVC"
            } else {
                codecType = String(stream.codecs.prefix(4))
            }

            // 构建完整的名称：画质名称 (编码, 码率)
            let mbps = Double(stream.bandwidth) / 1_000_000.0
            let fullName = String(format: "%@ (%@, %.1f Mbps)", baseName, codecType, mbps)

            return QualityOption(
                id: stream.id,
                name: fullName,
                description: format?.display_desc ?? "",
                bandwidth: stream.bandwidth,
                codec: stream.codecs,
                streamIndex: index
            )
        }

        // 按画质 ID 降序排序，同画质按码率降序排序
        availableQualities.sort {
            if $0.id != $1.id {
                return $0.id > $1.id
            } else {
                return $0.bandwidth > $1.bandwidth
            }
        }

        // 设置当前画质为实际返回的画质
        currentQualityId = playData.videoPlayURLInfo.quality
    }

    func addMenuItems(current: inout [UIMenuElement]) -> [UIMenuElement] {
        guard !availableQualities.isEmpty else { return [] }

        let qualityImage = UIImage(systemName: "video.fill")

        // 按画质 ID 分组
        let groupedQualities = Dictionary(grouping: availableQualities, by: { $0.id })

        // 获取所有唯一的画质 ID 并排序
        let sortedQualityIds = groupedQualities.keys.sorted(by: >)

        // 为每个画质创建子菜单
        let qualitySubmenus = sortedQualityIds.map { qualityId -> UIMenu in
            let streams = groupedQualities[qualityId]!

            // 获取画质的基础名称（去掉编码和码率信息）
            let baseName: String
            if let firstStream = streams.first {
                // 从完整名称中提取基础名称（如 "4K 超高清 (AVC, 27.2 Mbps)" -> "4K 超高清"）
                if let range = firstStream.name.range(of: " (") {
                    baseName = String(firstStream.name[..<range.lowerBound])
                } else {
                    baseName = firstStream.name
                }
            } else {
                baseName = "画质 \(qualityId)"
            }

            // 为该画质下的每个流创建菜单项
            let streamActions = streams.map { quality -> UIAction in
                // 检查是否是当前选中的流
                let isCurrentStream = quality.streamIndex == currentStreamIndex && isQualityLocked

                // 提取编码和码率信息（如 "AVC, 27.2 Mbps"）
                let streamInfo: String
                if let range = quality.name.range(of: " (") {
                    let infoWithParens = String(quality.name[range.lowerBound...])
                    streamInfo = infoWithParens.trimmingCharacters(in: CharacterSet(charactersIn: " ()"))
                } else {
                    let mbps = Double(quality.bandwidth) / 1_000_000.0
                    streamInfo = String(format: "%.1f Mbps", mbps)
                }

                return UIAction(
                    title: streamInfo,
                    state: isCurrentStream ? .on : .off
                ) { [weak self] _ in
                    self?.switchQuality(to: quality)
                }
            }

            // 如果只有一个流，显示完整信息
            let menuTitle: String
            if streams.count == 1, let stream = streams.first {
                let mbps = Double(stream.bandwidth) / 1_000_000.0
                menuTitle = String(format: "%@ (%.1f Mbps)", baseName, mbps)
            } else {
                menuTitle = baseName
            }

            return UIMenu(
                title: menuTitle,
                options: streams.count == 1 ? [] : [.displayInline],
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
        currentQualityId = quality.id
        currentStreamIndex = quality.streamIndex

        // 触发画质切换
        onQualityChange?(quality.id, quality.streamIndex)
    }
}
