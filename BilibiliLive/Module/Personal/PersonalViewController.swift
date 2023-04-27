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
    var action: ((UICollectionViewCell?) -> Void)? = nil
}

class PersonalViewController: UIViewController, BLTabBarContentVCProtocol {
    var contentView: UIView!
    var avatarImageView: UIImageView!
    var usernameLabel: UILabel!
    var leftCollectionView: UICollectionView!
    weak var currentViewController: UIViewController?

    var cellModels = [CellModel]()
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupData()
        leftCollectionView.reloadData()
        avatarImageView.layer.cornerRadius = avatarImageView.frame.size.width / 2
        leftCollectionView.register(BLSettingLineCollectionViewCell.self, forCellWithReuseIdentifier: "cell")
        leftCollectionView.selectItem(at: IndexPath(row: 0, section: 0), animated: false, scrollPosition: .top)
        collectionView(leftCollectionView, didSelectItemAt: IndexPath(row: 0, section: 0))
        WebRequest.requestLoginInfo { [weak self] response in
            guard let self else { return }
            switch response {
            case let .success(json):
                avatarImageView.kf.setImage(with: URL(string: json["face"].stringValue), options: [.processor(DownsamplingImageProcessor(size: CGSize(width: 100, height: 100))), .processor(RoundCornerImageProcessor(radius: .widthFraction(0.5))), .cacheSerializer(FormatIndicatedCacheSerializer.png)])
                usernameLabel.text = json["uname"].stringValue
            case .failure:
                break
            }
        }
    }

    func setupView() {
        let leftPanel = UIView()
        view.addSubview(leftPanel)
        leftPanel.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.left.equalTo(view.safeAreaLayoutGuide.snp.left)
            make.width.equalTo(isTvOS() ? 500 : 300)
        }

        contentView = UIView()
        view.addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.left.equalTo(leftPanel.snp.right)
            make.top.right.bottom.equalToSuperview()
        }

        avatarImageView = UIImageView()
        leftPanel.addSubview(avatarImageView)
        avatarImageView.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.top.equalTo(leftPanel.safeAreaLayoutGuide.snp.top)
            make.width.height.equalTo(100)
        }

        usernameLabel = UILabel()
        usernameLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        leftPanel.addSubview(usernameLabel)
        usernameLabel.snp.makeConstraints { make in
            make.centerY.equalTo(avatarImageView)
            make.left.equalTo(avatarImageView.snp.right).offset(20)
            make.right.equalToSuperview().offset(-20)
        }

        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                              heightDimension: .fractionalHeight(1.0))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(60))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsetsReference = .none
        section.interGroupSpacing = 16
        let layout = UICollectionViewCompositionalLayout(section: section)
        leftCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        leftCollectionView.contentInset = .zero
        leftCollectionView.delegate = self
        leftCollectionView.dataSource = self
        leftCollectionView.layer.masksToBounds = false
        leftCollectionView.backgroundColor = .clear
        leftPanel.addSubview(leftCollectionView)
        leftCollectionView.snp.makeConstraints { make in
            make.left.bottom.equalToSuperview()
            make.top.equalTo(avatarImageView.snp.bottom).offset(40)
            make.right.equalTo(-20)
        }
    }

    func setupData() {
        let setting = CellModel(title: "设置", contentVC: SettingsViewController())
        cellModels.append(setting)
        cellModels.append(CellModel(title: "搜索", action: {
            [weak self] cell in
            let resultVC = SearchResultViewController()
            let searchVC = UISearchController(searchResultsController: resultVC)
            searchVC.searchResultsUpdater = resultVC
            searchVC.delegate = resultVC
            self?.present(UISearchContainerViewController(searchController: searchVC), animated: true)
        }))
        cellModels.append(CellModel(title: "关注UP", contentVC: FollowUpsViewController()))
        cellModels.append(CellModel(title: "稍后再看", contentVC: ToViewViewController()))
        cellModels.append(CellModel(title: "历史记录", contentVC: HistoryViewController()))
        cellModels.append(CellModel(title: "每周必看", contentVC: WeeklyWatchViewController()))
        cellModels.append(CellModel(title: "Anime1", contentVC: Anime1ViewController()))

        let logout = CellModel(title: "登出") {
            [weak self] cell in
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
        let cell = collectionView.cellForItem(at: indexPath)
        model.action?(cell)
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
