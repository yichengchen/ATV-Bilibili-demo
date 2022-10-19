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
        print("BLTabBarViewController deinit")
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
        
        let followVC = FollowsViewController()
        followVC.tabBarItem.title = "关注"
        vcs.append(followVC)
        
        let fav = FavoriteViewController.create()
        fav.tabBarItem.title = "收藏"
        vcs.append(fav)
        
        let historyVC = HistoryViewController()
        historyVC.tabBarItem.title = "历史"
        vcs.append(historyVC)
        
        let toViewVC = ToViewViewController()
        toViewVC.tabBarItem.title = "稍后再看"
        vcs.append(toViewVC)
        
        let persionVC = PersonalViewController.create()
        persionVC.extendedLayoutIncludesOpaqueBars = true
        persionVC.tabBarItem.title = "我的"
        vcs.append(persionVC)
        
        setViewControllers(vcs, animated: false)
        selectedIndex = UserDefaults.standard.integer(forKey: selectedIndexKey)
        
        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        super.pressesEnded(presses, with: event)
        guard let buttonPress = presses.first?.type else { return }
        if buttonPress == .playPause {
            if let reloadVC = topMostViewController() as? BLTabBarContentVCProtocol {
                print("send reload to \(reloadVC)")
                reloadVC.reloadData()
            }
        }
    }
    
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        UserDefaults.standard.set(tabBarController.selectedIndex, forKey: selectedIndexKey)
    }
    
    @objc func didBecomeActive() {
        (selectedViewController as? BLTabBarContentVCProtocol)?.reloadData()
    }
}
