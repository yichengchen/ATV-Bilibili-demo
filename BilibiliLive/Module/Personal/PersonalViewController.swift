//
//  PersonalViewController.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/8/20.
//

import Alamofire
import Kingfisher
import SwiftyJSON
import UIKit

struct CellModel {
    var iconImage: UIImage? = nil
    let title: String
    var desp: String? = nil
    var autoSelect: Bool? = true
    var contentVC: UIViewController? = nil
    var action: (() -> Void)? = nil
}

class PersonalViewController: UIViewController, BLTabBarContentVCProtocol {
    struct CellModel {
        let title: String
        var autoSelect: Bool? = true
        var contentVC: UIViewController? = nil
        var action: (() -> Void)? = nil
    }

    static func create() -> PersonalViewController {
        return UIStoryboard(name: "Main", bundle: Bundle.main).instantiateViewController(identifier: String(describing: self)) as! PersonalViewController
    }

    @IBOutlet var contentView: UIView!
    @IBOutlet var avatarImageView: UIImageView!
    @IBOutlet var usernameLabel: UILabel!
    @IBOutlet var leftCollectionView: UICollectionView!
    weak var currentViewController: UIViewController?

    @IBOutlet var menusView: UIView!

    @IBOutlet var menusLeft: NSLayoutConstraint!

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
        menusLeft.constant = 40
    }

//    override func viewWillAppear(_ animated: Bool) {
//        super.viewWillAppear(animated)
//
//        BLAnimate(withDuration: 0.3) {
//            self.menusLeft.constant = 40
//            self.view.layoutIfNeeded()
//        }
//    }
//
//    override func viewWillDisappear(_ animated: Bool) {
//        super.viewWillDisappear(animated)
//        BLAnimate(withDuration: 0.3) {
//            self.menusLeft.constant = -300
//            self.view.layoutIfNeeded()
//        }
//    }

    func setupData() {
        let setting = CellModel(title: "设置", contentVC: SettingsViewController())
        cellModels.append(setting)
        cellModels.append(CellModel(title: "搜索", autoSelect: false, action: {
            [weak self] in
            let resultVC = SearchResultViewController()
            let searchVC = UISearchController(searchResultsController: resultVC)
            searchVC.searchResultsUpdater = resultVC
            self?.present(UISearchContainerViewController(searchController: searchVC), animated: true)
        }))
        cellModels.append(CellModel(title: "关注UP", contentVC: FollowUpsViewController()))
        cellModels.append(CellModel(title: "稍后再看", contentVC: ToViewViewController()))
        cellModels.append(CellModel(title: "历史记录", contentVC: HistoryViewController()))
        cellModels.append(CellModel(title: "每周必看", contentVC: WeeklyWatchViewController()))

        let logout = CellModel(title: "登出", autoSelect: false) {
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

    func collectionView(_ collectionView: UICollectionView, didUpdateFocusIn context: UICollectionViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        if Settings.sideMenuAutoSelectChange == false {
            return
        }
        // 检查新的焦点是否是UICollectionViewCell
        guard let nextFocusedIndexPath = context.nextFocusedIndexPath else {
            return
        }
        let model = cellModels[nextFocusedIndexPath.item]
        if model.autoSelect == false {
            // 不自动选中
            return
        }
        collectionView.selectItem(at: nextFocusedIndexPath, animated: true, scrollPosition: .centeredHorizontally)
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
