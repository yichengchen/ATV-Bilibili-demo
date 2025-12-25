//
//  BLTabBarViewController.swift
//  BilibiliLive
//
//  Created by Etan Chen on 2021/4/5.
//

import UIKit

protocol BLTabBarContentVCProtocol {
    func reloadData()
}

let selectedIndexKey = "BLTabBarViewController.selectedIndex"

class BLTabBarViewController: UITabBarController, UITabBarControllerDelegate {
    static func clearSelected() {
        UserDefaults.standard.removeObject(forKey: selectedIndexKey)
    }

    deinit {
        Logger.debug("BLTabBarViewController deinit")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        var vcs = [UIViewController]()

        let liveVC = LiveViewController()
        liveVC.tabBarItem.title = "直播"
        vcs.append(liveVC)

        let feedVC = FeedViewController()
        feedVC.tabBarItem.title = "推荐"
        vcs.append(feedVC)

        let hotVC = HotViewController()
        hotVC.tabBarItem.title = "热门"
        vcs.append(hotVC)

        let rank = RankingViewController()
        rank.tabBarItem.title = "排行榜"
        vcs.append(rank)

        let historyVC = HistoryViewController()
        historyVC.tabBarItem.title = "历史"
        vcs.append(historyVC)

        let followVC = FollowsViewController()
        followVC.tabBarItem.title = "关注"
        vcs.append(followVC)

        let fav = FavoriteViewController()
        fav.tabBarItem.title = "收藏"
        vcs.append(fav)

        let uploads = MyUploadsViewController()
        uploads.tabBarItem.title = "投稿"
        vcs.append(uploads)

        // 搜索Tab
        let searchResultVC = SearchResultViewController()
        let searchController = UISearchController(searchResultsController: searchResultVC)
        searchController.searchResultsUpdater = searchResultVC
        let searchContainerVC = UISearchContainerViewController(searchController: searchController)
        searchContainerVC.tabBarItem.title = "搜索"
        vcs.append(searchContainerVC)

        let persionVC = PersonalViewController.create()
        persionVC.extendedLayoutIncludesOpaqueBars = true
        persionVC.tabBarItem.title = "我的"
        vcs.append(persionVC)

        setViewControllers(vcs, animated: false)
        selectedIndex = UserDefaults.standard.integer(forKey: selectedIndexKey)
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        super.pressesEnded(presses, with: event)
        guard let buttonPress = presses.first?.type else { return }
        if buttonPress == .playPause {
            if let reloadVC = topMostViewController() as? BLTabBarContentVCProtocol {
                Logger.debug("send reload to \(reloadVC)")
                reloadVC.reloadData()
            }
        }
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        UserDefaults.standard.set(tabBarController.selectedIndex, forKey: selectedIndexKey)
    }
}
