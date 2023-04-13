//
//  SettingsViewController.swift
//  BilibiliLive
//
//  Created by whw on 2022/10/19.
//

import UIKit

extension FeedDisplayStyle {
    var desp: String {
        switch self {
        case .large:
            return "3行"
        case .normal:
            return "4行"
        case .sideBar:
            return "-"
        }
    }
}

class SettingsViewController: UIViewController {
    @IBOutlet var collectionView: UICollectionView!
    var cellModels = [CellModel]()

    static func create() -> SettingsViewController {
        return UIStoryboard(name: "Main", bundle: Bundle.main).instantiateViewController(identifier: String(describing: self)) as! SettingsViewController
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupData()
    }

    func setupData() {
        cellModels.removeAll()
        let directlyVideo = CellModel(title: "直接进入视频", desp: Settings.direatlyEnterVideo ? "开" : "关") {
            [weak self] in
            Settings.direatlyEnterVideo.toggle()
            self?.setupData()
        }
        cellModels.append(directlyVideo)
        let cancelAction = UIAlertAction(title: nil, style: .cancel)
        let dmStyle = CellModel(title: "弹幕显示区域", desp: Settings.danmuArea.title) { [weak self] in
            let alert = UIAlertController(title: "弹幕显示区域", message: "设置弹幕显示区域", preferredStyle: .actionSheet)
            for style in DanmuArea.allCases {
                let action = UIAlertAction(title: style.title, style: .default) { _ in
                    Settings.danmuArea = style
                    self?.setupData()
                }
                alert.addAction(action)
            }
            alert.addAction(cancelAction)
            self?.present(alert, animated: true)
        }
        cellModels.append(dmStyle)

        let style = CellModel(title: "时间线显示模式", desp: Settings.displayStyle.desp) { [weak self] in
            let alert = UIAlertController(title: "显示模式", message: "重启app生效", preferredStyle: .actionSheet)
            for style in FeedDisplayStyle.allCases.filter({ !$0.hideInSetting }) {
                let action = UIAlertAction(title: style.desp, style: .default) { _ in
                    Settings.displayStyle = style
                    self?.setupData()
                }
                alert.addAction(action)
            }
            alert.addAction(cancelAction)
            self?.present(alert, animated: true)
        }
        cellModels.append(style)

        let relatedVideoLoadMode = CellModel(title: "视频详情相关推荐加载模式", desp: Settings.showRelatedVideoInCurrentVC ? "页面刷新" : "新页面中打开") { [weak self] in
            let alert = UIAlertController(title: "视频详情相关推荐加载模式", message: "", preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "页面刷新", style: .default) { _ in
                Settings.showRelatedVideoInCurrentVC = true
                self?.setupData()
            })
            alert.addAction(UIAlertAction(title: "新页面中打开", style: .default) { _ in
                Settings.showRelatedVideoInCurrentVC = false
                self?.setupData()
            })
            alert.addAction(cancelAction)
            self?.present(alert, animated: true)
        }
        cellModels.append(relatedVideoLoadMode)

        let hotWithoutCookie = CellModel(title: "热门匿名模式", desp: Settings.requestHotWithoutCookie ? "开" : "关") {
            [weak self] in
            Settings.requestHotWithoutCookie.toggle()
            self?.setupData()
        }
        cellModels.append(hotWithoutCookie)

        let continuePlay = CellModel(title: "继续播放", desp: Settings.continuePlay ? "开" : "关") {
            [weak self] in
            Settings.continuePlay.toggle()
            self?.setupData()
        }
        cellModels.append(continuePlay)

        let autoSkip = CellModel(title: "自动跳过片头片尾", desp: Settings.autoSkip ? "开" : "关") {
            [weak self] in
            Settings.autoSkip.toggle()
            self?.setupData()
        }
        cellModels.append(autoSkip)

        let quality = CellModel(title: "最高画质", desp: Settings.mediaQuality.desp) { [weak self] in
            let alert = UIAlertController(title: "最高画质", message: "4k以上需要大会员", preferredStyle: .actionSheet)
            for quality in MediaQualityEnum.allCases {
                let action = UIAlertAction(title: quality.desp, style: .default) { _ in
                    Settings.mediaQuality = quality
                    self?.setupData()
                }
                alert.addAction(action)
            }
            alert.addAction(cancelAction)
            self?.present(alert, animated: true)
        }
        cellModels.append(quality)
        let losslessAudio = CellModel(title: "无损音频和杜比全景声", desp: Settings.losslessAudio ? "开" : "关") {
            [weak self] in
            Settings.losslessAudio.toggle()
            self?.setupData()
        }
        cellModels.append(losslessAudio)

        let hevc = CellModel(title: "Hevc优先", desp: Settings.preferHevc ? "开" : "关") {
            [weak self] in
            Settings.preferHevc.toggle()
            self?.setupData()
        }
        cellModels.append(hevc)

        let continouslyPlay = CellModel(title: "连续播放", desp: Settings.continouslyPlay ? "开" : "关") {
            [weak self] in
            Settings.continouslyPlay.toggle()
            self?.setupData()
        }
        cellModels.append(continouslyPlay)

        let fontSize = cellModelWithActions(title: "弹幕大小", message: "默认为36", current: Settings.danmuSize.title, options: DanmuSize.allCases, optionString: DanmuSize.allCases.map({ $0.title })) {
            Settings.danmuSize = $0
        }
        cellModels.append(fontSize)

        let mask = CellModel(title: "智能防档弹幕", desp: Settings.danmuMask ? "开" : "关") {
            [weak self] in
            Settings.danmuMask.toggle()
            self?.setupData()
        }
        cellModels.append(mask)

        let localMask = CellModel(title: "按需本地运算智能防档弹幕(Exp)", desp: Settings.vnMask ? "开" : "关") {
            [weak self] in
            Settings.vnMask.toggle()
            self?.setupData()
        }
        cellModels.append(localMask)

        let match = CellModel(title: "匹配视频内容", desp: Settings.contentMatch ? "开" : "关") {
            [weak self] in
            Settings.contentMatch.toggle()
            self?.setupData()
        }
        cellModels.append(match)

        collectionView.reloadData()
    }

    func cellModelWithActions<T>(title: String,
                                 message: String?,
                                 current: String,
                                 options: [T],
                                 optionString: [String],
                                 onSelect: ((T) -> Void)? = nil) -> CellModel
    {
        return CellModel(title: title, desp: current) { [weak self] in
            let alert = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)

            for (idx, string) in optionString.enumerated() {
                let action = UIAlertAction(title: string, style: .default) { _ in
                    onSelect?(options[idx])
                    self?.setupData()
                }
                alert.addAction(action)
            }
            let cancelAction = UIAlertAction(title: nil, style: .cancel)
            alert.addAction(cancelAction)
            self?.present(alert, animated: true)
        }
    }
}

extension SettingsViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        cellModels[indexPath.row].action?()
    }
}

extension SettingsViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return cellModels.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: SettingsSwitchCell.self), for: indexPath) as! SettingsSwitchCell
        let data = cellModels[indexPath.row]
        cell.titleLabel.text = data.title
        cell.descLabel.text = data.desp
        return cell
    }
}

class SettingsSwitchCell: UICollectionViewCell {
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var descLabel: UILabel!
}
