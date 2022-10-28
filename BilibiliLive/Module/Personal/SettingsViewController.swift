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

        let dmStyle = CellModel(title: "弹幕显示区域", desp: Settings.dmStyleEnum.dmStyle) { [weak self] in
            let alert = UIAlertController(title: "弹幕显示区域", message: "设置弹幕显示区域", preferredStyle: .actionSheet)
            for style in dmStyleEnum.allCases {
                let action = UIAlertAction(title: style.dmStyle, style: .default) { _ in
                    Settings.dmStyleEnum = style
                    self?.setupData()
                    var dmarea = 0
                    switch style {
                    case .style_25:
                        dmarea = 25
                    case .style_50:
                        dmarea = 50
                    case .style_75:
                        dmarea = 75
                    case .style_100:
                        dmarea = 100
                    default:
                        break
                    }
                    WebRequest.requestDMSetting(dmarea: dmarea, complete: nil)
                }
                alert.addAction(action)
            }
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
            self?.present(alert, animated: true)
        }
        cellModels.append(style)
        let liveHack = CellModel(title: "直播播放黑屏修复", desp: Settings.livePlayerHack ? "开" : "关") {
            [weak self] in
            Settings.livePlayerHack.toggle()
            self?.setupData()
        }
        cellModels.append(liveHack)

        let quality = CellModel(title: "最高画质", desp: Settings.mediaQuality.desp) { [weak self] in
            let alert = UIAlertController(title: "最高画质", message: "4k以上需要大会员", preferredStyle: .actionSheet)
            for quality in MediaQualityEnum.allCases {
                let action = UIAlertAction(title: quality.desp, style: .default) { _ in
                    Settings.mediaQuality = quality
                    self?.setupData()
                }
                alert.addAction(action)
            }
            self?.present(alert, animated: true)
        }
        cellModels.append(quality)
        let losslessAudio = CellModel(title: "无损音频和杜比全景声", desp: Settings.losslessAudio ? "开" : "关") {
            [weak self] in
            Settings.losslessAudio.toggle()
            self?.setupData()
        }
        cellModels.append(losslessAudio)

        collectionView.reloadData()
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
