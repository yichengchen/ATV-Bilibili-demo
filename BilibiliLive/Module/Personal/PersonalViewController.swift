//
//  PersonalViewController.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/8/20.
//

import Alamofire
import Kingfisher
import SnapKit
import SwiftyJSON
import UIKit

class PersonalViewController: UIViewController, BLTabBarContentVCProtocol {
    struct CellModel {
        let title: String
        var autoSelect: Bool? = true
        var contentVC: UIViewController? = nil
        var action: (() -> Void)? = nil
    }

    static func create() -> PersonalViewController {
        return PersonalViewController()
    }

    private let leftContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let profileContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let usernameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let leftCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 16
        layout.minimumInteritemSpacing = 4
        layout.itemSize = CGSize(width: 460, height: 60)
        layout.sectionInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 0)
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        return collectionView
    }()

    weak var currentViewController: UIViewController?

    var cellModels = [CellModel]()
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupData()
        leftCollectionView.reloadData()
        avatarImageView.layer.cornerRadius = 50
        leftCollectionView.register(BLSettingLineCollectionViewCell.self, forCellWithReuseIdentifier: "cell")
        leftCollectionView.selectItem(at: IndexPath(row: 0, section: 0), animated: false, scrollPosition: .top)
        collectionView(leftCollectionView, didSelectItemAt: IndexPath(row: 0, section: 0))
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleAccountUpdate),
                                               name: AccountManager.didUpdateNotification,
                                               object: nil)
        updateAccountInfo()
        AccountManager.shared.refreshActiveAccountProfile()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func setupData() {
        let setting = CellModel(title: "设置", contentVC: SettingsViewController())
        cellModels.append(setting)
        cellModels.append(CellModel(title: "账号切换", autoSelect: false, action: { [weak self] in
            let controller = AccountSwitcherViewController()
            controller.modalPresentationStyle = .overFullScreen
            self?.present(controller, animated: true)
        }))

        cellModels.append(CellModel(title: "追番追剧", autoSelect: false, action: { [weak self] in
            let controller = FollowBangumiViewController()
            self?.present(controller, animated: true)
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
            WebRequest.logout {
                ApiRequest.logout { hasRemainingAccount in
                    if hasRemainingAccount {
                        AccountManager.shared.refreshActiveAccountProfile()
                    } else {
                        AppDelegate.shared.showLogin()
                    }
                }
            }
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    @objc private func handleAccountUpdate() {
        updateAccountInfo()
    }

    private func updateAccountInfo() {
        guard let account = AccountManager.shared.activeAccount else {
            usernameLabel.text = "未登录"
            avatarImageView.image = nil
            return
        }
        usernameLabel.text = account.profile.username
        if let url = URL(string: account.profile.avatar), !account.profile.avatar.isEmpty {
            avatarImageView.kf.setImage(with: url)
        } else {
            avatarImageView.image = UIImage(systemName: "person.crop.circle.fill")
        }
    }

    private func setupUI() {
        view.addSubview(leftContainerView)
        view.addSubview(contentView)

        leftContainerView.addSubview(profileContainerView)
        leftContainerView.addSubview(leftCollectionView)

        profileContainerView.addSubview(avatarImageView)
        profileContainerView.addSubview(usernameLabel)

        leftCollectionView.delegate = self
        leftCollectionView.dataSource = self

        leftContainerView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.bottom.equalToSuperview()
            make.width.equalTo(500)
        }

        contentView.snp.makeConstraints { make in
            make.leading.equalTo(leftContainerView.snp.trailing).offset(8)
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.trailing.bottom.equalToSuperview()
        }

        profileContainerView.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
            make.height.equalTo(100)
        }

        avatarImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.top.bottom.equalToSuperview()
            make.width.equalTo(avatarImageView.snp.height)
        }

        usernameLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarImageView.snp.trailing).offset(20)
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalTo(avatarImageView.snp.centerY)
        }

        leftCollectionView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(profileContainerView.snp.bottom).offset(40)
        }
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
