//
//  QualitySelectionPlugin.swift
//  BilibiliLive
//
//  Created by Claude on 2024/11/28.
//

import AVKit

/// 视频清晰度选择插件
/// 在播放器菜单中添加清晰度切换选项
class QualitySelectionPlugin: NSObject, CommonPlayerPlugin {
    /// 当前视频可用的清晰度列表
    private var availableQualities: [VideoQualityOption] = []

    /// 当前选择的清晰度
    private var currentQuality: Int = 0

    /// 清晰度切换回调
    var onQualityChange: ((Int) -> Void)?

    /// 视频清晰度选项
    struct VideoQualityOption {
        let qn: Int // 清晰度 qn 值
        let description: String // 显示名称
        let needVIP: Bool // 是否需要大会员
    }

    init(playURLInfo: VideoPlayURLInfo) {
        super.init()
        parseAvailableQualities(from: playURLInfo)
        currentQuality = playURLInfo.quality
    }

    /// 从 VideoPlayURLInfo 解析可用清晰度
    private func parseAvailableQualities(from info: VideoPlayURLInfo) {
        // 使用 support_formats 获取清晰度列表
        availableQualities = info.support_formats.map { format in
            VideoQualityOption(
                qn: format.quality,
                description: format.new_description,
                needVIP: MediaQualityEnum.from(qn: format.quality)?.requiresVIP ?? false
            )
        }.sorted { $0.qn > $1.qn } // 按清晰度从高到低排序

        // 确保当前清晰度在可用列表中，否则使用最高可用清晰度
        if !availableQualities.isEmpty && !availableQualities.contains(where: { $0.qn == info.quality }) {
            Logger.warn("[QualityPlugin] Current quality \(info.quality) not in available list, using highest available")
            currentQuality = availableQualities.first?.qn ?? info.quality
        }

        Logger.debug("[QualityPlugin] Available qualities: \(availableQualities.map { "\($0.description)(\($0.qn))" }.joined(separator: ", "))")
        Logger.debug("[QualityPlugin] Current quality: \(currentQuality)")
    }

    func addMenuItems(current: inout [UIMenuElement]) -> [UIMenuElement] {
        guard !availableQualities.isEmpty else { return [] }

        let qualityActions = availableQualities.map { option in
            let title = option.needVIP ? "\(option.description) (大会员)" : option.description
            let state: UIMenuElement.State = option.qn == currentQuality ? .on : .off

            return UIAction(title: title, state: state) { [weak self] _ in
                guard let self = self else { return }
                if option.qn != self.currentQuality {
                    Logger.info("[QualityPlugin] Quality changed: \(self.currentQuality) -> \(option.qn)")
                    self.currentQuality = option.qn
                    // 保存用户选择的清晰度到设置
                    if let quality = MediaQualityEnum.from(qn: option.qn) {
                        Settings.mediaQuality = quality
                        Logger.info("[QualityPlugin] Saved preferred quality: \(quality)")
                    }
                    self.onQualityChange?(option.qn)
                }
            }
        }

        let qualityMenu = UIMenu(
            title: "清晰度",
            image: UIImage(systemName: "slider.horizontal.3"),
            options: [.displayInline, .singleSelection],
            children: qualityActions
        )

        // 找到播放设置菜单并添加清晰度子菜单
        if let settingsIndex = current.firstIndex(where: { ($0 as? UIMenu)?.identifier.rawValue == "setting" }),
           let settingsMenu = current[settingsIndex] as? UIMenu
        {
            // 将清晰度菜单添加到播放设置菜单中
            var children = settingsMenu.children
            children.insert(qualityMenu, at: 0)
            let newSettingsMenu = settingsMenu.replacingChildren(children)
            current[settingsIndex] = newSettingsMenu
            return []
        }

        // 如果没有找到播放设置菜单，创建一个新的
        let menu = UIMenu(
            title: "画质设置",
            image: UIImage(systemName: "tv"),
            identifier: UIMenu.Identifier(rawValue: "quality_setting"),
            children: [qualityMenu]
        )
        return [menu]
    }

    /// 更新当前清晰度（用于外部同步状态）
    func updateCurrentQuality(_ qn: Int) {
        currentQuality = qn
    }
}
