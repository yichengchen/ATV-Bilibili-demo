//
//  MenusViewController.swift
//  BilibiliLive
//
//  Created by ManTie on 2024/7/4.
//

import Alamofire
import Kingfisher
import SwiftyJSON
import UIKit

class MenusViewController: UIViewController, BLTabBarContentVCProtocol {
    static func create() -> MenusViewController {
        return UIStoryboard(name: "Main", bundle: Bundle.main).instantiateViewController(identifier: String(describing: self)) as! MenusViewController
    }

    @IBOutlet var contentView: UIView!
    @IBOutlet var avatarImageView: UIImageView!
    @IBOutlet var usernameLabel: UILabel! {
        didSet {
            usernameLabel.text = "主页"
        }
    }

    @IBOutlet var leftCollectionView: BSCollectionVIew!
    weak var currentViewController: UIViewController?
    private var menuIsShowing = false
    var menuRecognizer: UITapGestureRecognizer?
    private var selectMenuItem: CellModel?

    @IBOutlet var menusView: UIView! {
        didSet {
            if #available(tvOS 26.0, *) {
                menusView.setAutoGlassEffectView(cornerRadius: lessBigSornerRadius)

            } else {
                menusView.setBlurEffectView(cornerRadius: lessBigSornerRadius)
                menusView.setCornerRadius(cornerRadius: lessBigSornerRadius, borderColor: .lightGray, borderWidth: 0.5)
            }
        }
    }

    @IBOutlet var homeIcon: UIImageView! {
        didSet {
            homeIcon.setImageColor(color: UIColor(named: "upTitleColor"))
        }
    }

    @IBOutlet var menusLeft: NSLayoutConstraint!
    @IBOutlet var menusViewHeight: NSLayoutConstraint!

    @IBOutlet var vcLeft: NSLayoutConstraint!
    @IBOutlet var collectionTop: NSLayoutConstraint!
    @IBOutlet var headViewLeading: NSLayoutConstraint!
    @IBOutlet var headingViewTop: NSLayoutConstraint!

    @IBOutlet var menuViewWidth: NSLayoutConstraint!

    var focusableView = true

    var userName = ""

    var cellModels = [CellModel]()
    override func viewDidLoad() {
        super.viewDidLoad()
        setupData()
        leftCollectionView.reloadData()
        avatarImageView.layer.cornerRadius = avatarImageView.frame.size.width / 2
        leftCollectionView.register(BLMenuLineCollectionViewCell.self, forCellWithReuseIdentifier: "cell")
        leftCollectionView.selectItem(at: IndexPath(row: 0, section: 0), animated: false, scrollPosition: .top)
        collectionView(leftCollectionView, didSelectItemAt: IndexPath(row: 0, section: 0))
        WebRequest.requestLoginInfo { [weak self] response in
            switch response {
            case let .success(json):
                self?.avatarImageView.kf.setImage(with: URL(string: json["face"].stringValue))
                self?.userName = json["uname"].stringValue
            case .failure:
                break
            }
        }
        menusLeft.constant = 40

        view.backgroundColor = UIColor(named: "mainBgColor")

        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.addObserver(forName: EVENT_COLLECTION_TO_SHOW_MENU, object: nil, queue: .main) { [weak self] _ in
            self?.showMenus()
        }

        menuRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleMenuPress))
        menuRecognizer?.allowedPressTypes = [NSNumber(value: UIPress.PressType.menu.rawValue)]
        view.addGestureRecognizer(menuRecognizer!)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    @objc func handleMenuPress() {
        NotificationCenter.default.post(name: EVENT_COLLECTION_TO_TOP, object: nil)
    }

    @objc func handleRightPress() {
        hiddenMensu()
    }

    func showMenus() {
        BLAfter(afterTime: 0.3) {
            // Request a focus update
            self.view.setNeedsFocusUpdate()

            BLAnimate(withDuration: 0.3) {
                if self.menuRecognizer != nil {
                    self.view.removeGestureRecognizer(self.menuRecognizer!)
                }

                self.leftCollectionView.alpha = 1
                self.homeIcon.alpha = 0
                self.collectionTop.constant = 40
                self.menusViewHeight.constant = 1020
                //            self.vcLeft.constant = 340
                self.headViewLeading.constant = 20
                self.headingViewTop.constant = 20
                self.menusView.setCornerRadius(cornerRadius: bigSornerRadius)
                self.usernameLabel.text = self.userName
                self.menuViewWidth.constant = 320
                self.view.layoutIfNeeded()
            } completion: { _ in
                self.menuIsShowing = true
                self.leftCollectionView.setNeedsLayout()
                self.leftCollectionView.layoutIfNeeded()
            }
        }
    }

    func hiddenMensu() {
        BLAnimate(withDuration: 0.3) {
            self.leftCollectionView.alpha = 0
            self.homeIcon.alpha = 1
            self.collectionTop.constant = 0
            self.menusViewHeight.constant = 60
//            self.vcLeft.constant = 0
            self.headViewLeading.constant = 7
            self.headingViewTop.constant = 0
            self.menusView.setCornerRadius(cornerRadius: 30)
            self.menuViewWidth.constant = 160

            self.view.layoutIfNeeded()
        } completion: { _ in
            self.menuIsShowing = false
            self.usernameLabel.text = self.selectMenuItem?.title
        }

        if menuRecognizer != nil {
            view.addGestureRecognizer(menuRecognizer!)
        }
    }

    override var preferredFocusedView: UIView? {
        return leftCollectionView
    }

    func setupData() {
        let lastLeft: () -> Void = { [weak self] in
            self?.showMenus()
        }
        let followsViewController = FollowsViewController()
        followsViewController.didSelectToLastLeft = lastLeft
        followsViewController.isShowTopCover = {
            return true
        }
        cellModels.append(CellModel(iconImage: UIImage(systemName: "person.crop.circle.badge.checkmark"), title: "关注", contentVC: followsViewController))

        let FeedViewController = FeedViewController()
        FeedViewController.didSelectToLastLeft = lastLeft
        cellModels.append(CellModel(iconImage: UIImage(systemName: "timelapse"), title: "推荐", contentVC: FeedViewController))

        let HotViewController = HotViewController()
        HotViewController.didSelectToLastLeft = lastLeft
        cellModels.append(CellModel(iconImage: UIImage(systemName: "livephoto.play"), title: "热门", contentVC: HotViewController))

        cellModels.append(CellModel(iconImage: UIImage(systemName: "theatermasks.circle"), title: "排行榜", contentVC: RankingViewController()))
        cellModels.append(CellModel(iconImage: UIImage(systemName: "infinity.circle"), title: "直播", contentVC: LiveViewController()))

        cellModels.append(CellModel(iconImage: UIImage(systemName: "star.circle"), title: "收藏", contentVC: FavoriteViewController()))

        let logout = CellModel(iconImage: UIImage(systemName: "magnifyingglass.circle"), title: "搜索", autoSelect: false) {
            [weak self] in
//            self?.actionLogout()
            let resultVC = SearchResultViewController()
            let searchVC = UISearchController(searchResultsController: resultVC)
            searchVC.searchResultsUpdater = resultVC
            self?.present(UISearchContainerViewController(searchController: searchVC), animated: true)
        }
        cellModels.append(logout)
        cellModels.append(CellModel(iconImage: UIImage(systemName: "gear"), title: "设置", contentVC: PersonalViewController.create()))
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

        BLAfter(afterTime: 0.3) {
            self.hiddenMensu()
        }
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

extension MenusViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! BLMenuLineCollectionViewCell
        cell.titleLabel.text = cellModels[indexPath.item].title
        if let icon = cellModels[indexPath.item].iconImage {
            cell.iconImageView.image = icon
            cell.iconImageView.setImageColor(color: UIColor(named: "upTitleColor"))
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return cellModels.count
    }
}

extension MenusViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let model = cellModels[indexPath.item]
        if let vc = model.contentVC {
            setViewController(vc: vc)
        }
        selectMenuItem = model
        model.action?()
    }

    func collectionView(_ collectionView: UICollectionView, didUpdateFocusIn context: UICollectionViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        // 检查新的焦点是否是UICollectionViewCell，失去焦点后隐藏菜单
        guard context.nextFocusedIndexPath != nil else {
            hiddenMensu()
            return
        }
    }
}
