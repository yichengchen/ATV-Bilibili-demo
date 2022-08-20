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
    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        let loginVC = UIStoryboard(name: "Main", bundle: Bundle.main).instantiateViewController(identifier: "Login")
        let liveVC = LiveViewController()
        let feedVC = FeedViewController()
        let followVC = FollowsViewController()
        let historyVC = HistoryViewController()
        let toViewVC = ToViewViewController()
        liveVC.tabBarItem.title = "直播"
        feedVC.tabBarItem.title = "推荐"
        followVC.tabBarItem.title = "关注"
        historyVC.tabBarItem.title = "历史"
        toViewVC.tabBarItem.title = "稍后再看"
        loginVC.tabBarItem.title = "登录"
        setViewControllers([liveVC,feedVC,followVC,historyVC,toViewVC,loginVC], animated: false)
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
