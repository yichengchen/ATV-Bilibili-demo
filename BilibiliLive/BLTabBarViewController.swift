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
        let liveVC = LiveViewController()
        let feedVC = FeedViewController()
        let followVC = FollowsViewController()
        let historyVC = HistoryViewController()
        let toViewVC = ToViewViewController()
        let persionVC = PersonalViewController.create()
        persionVC.extendedLayoutIncludesOpaqueBars = true
        liveVC.tabBarItem.title = "直播"
        feedVC.tabBarItem.title = "推荐"
        followVC.tabBarItem.title = "关注"
        historyVC.tabBarItem.title = "历史"
        toViewVC.tabBarItem.title = "稍后再看"
        persionVC.tabBarItem.title = "我的"
        setViewControllers([liveVC,feedVC,followVC,historyVC,toViewVC,persionVC], animated: false)
        selectedIndex = UserDefaults.standard.integer(forKey: selectedIndexKey)
        
        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
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
