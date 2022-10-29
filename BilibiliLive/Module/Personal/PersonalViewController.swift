//
//  PersonalMasterViewController.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/8/20.
//

import Alamofire
import Kingfisher
import SwiftyJSON
import UIKit

struct CellModel {
    let title: String
    var desp: String? = nil
    var contentVC: UIViewController? = nil
    var action: (() -> Void)? = nil
}

class PersonalViewController: UIViewController, BLTabBarContentVCProtocol {
    static func create() -> PersonalViewController {
        return UIStoryboard(name: "Main", bundle: Bundle.main).instantiateViewController(identifier: String(describing: self)) as! PersonalViewController
    }

    @IBOutlet var contentView: UIView!
    @IBOutlet var avatarImageView: UIImageView!
    @IBOutlet var usernameLabel: UILabel!
    @IBOutlet var leftCollectionView: UICollectionView!
    weak var currentViewController: UIViewController?

    var cellModels = [CellModel]()
    override func viewDidLoad() {
        super.viewDidLoad()
        setupData()
        leftCollectionView.reloadData()
        avatarImageView.layer.cornerRadius = avatarImageView.frame.size.width / 2
        leftCollectionView.register(BLSettingLineCollectionViewCell.self, forCellWithReuseIdentifier: "cell")
        leftCollectionView.selectItem(at: IndexPath(row: 0, section: 0), animated: false, scrollPosition: .top)
        collectionView(leftCollectionView, didSelectItemAt: IndexPath(row: 0, section: 0))
        WebRequest.requestLoginInfo { [weak self] response in
            switch response {
            case let .success(json):
                self?.avatarImageView.kf.setImage(with: URL(string: json["face"].stringValue))
                self?.usernameLabel.text = json["uname"].stringValue
            case .failure:
                break
            }
        }
    }

    func setupData() {
        let setting = CellModel(title: "设置", contentVC: SettingsViewController.create())
        cellModels.append(setting)
        cellModels.append(CellModel(title: "稍后在看", contentVC: ToViewViewController()))
        cellModels.append(CellModel(title: "历史记录", contentVC: HistoryViewController()))
        let logout = CellModel(title: "登出") {
            [weak self] in
            self?.actionLogout()
        }
        cellModels.append(logout)
    }

    func setViewController(vc: UIViewController) {
        currentViewController?.willMove(toParent: nil)
        currentViewController?.view.removeFromSuperview()
        currentViewController?.removeFromParent()

        currentViewController = vc
        addChild(vc)
        contentView.addSubview(vc.view)
        vc.view.makeConstraintsToBindToSuperview()
        vc.didMove(toParent: self)
    }

    func reloadData() {
        (currentViewController as? BLTabBarContentVCProtocol)?.reloadData()
    }

    func actionLogout() {
        let alert = UIAlertController(title: "确定登出？", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default) {
            _ in
            ApiRequest.logout {
                WebRequest.logout {
                    AppDelegate.shared.showLogin()
                }
            }
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }
}

extension PersonalViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! BLSettingLineCollectionViewCell
        cell.titleLabel.text = cellModels[indexPath.item].title
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return cellModels.count
    }
}

extension PersonalViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let model = cellModels[indexPath.item]
        if let vc = model.contentVC {
            setViewController(vc: vc)
        }
        model.action?()
    }
}

class EmptyViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let label = UILabel()
        label.text = "Nothing Here"
        view.addSubview(label)
        label.makeConstraintsBindToCenterOfSuperview()
    }
}
