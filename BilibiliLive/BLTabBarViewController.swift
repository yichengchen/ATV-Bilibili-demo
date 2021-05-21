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
        liveVC.tabBarItem.title = "Live"
        feedVC.tabBarItem.title = "Feed"
        followVC.tabBarItem.title = "Follow"
        historyVC.tabBarItem.title = "History"
        toViewVC.tabBarItem.title = "ToView"
        setViewControllers([liveVC,feedVC,followVC,historyVC,toViewVC,loginVC], animated: false)
        selectedIndex = UserDefaults.standard.integer(forKey: selectedIndexKey)
        
        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        if let vc = viewController as? BLTabBarContentVCProtocol {
            vc.reloadData()
        }
        UserDefaults.standard.set(tabBarController.selectedIndex, forKey: selectedIndexKey)
    }
    
    @objc func didBecomeActive() {
        (selectedViewController as? BLTabBarContentVCProtocol)?.reloadData()
    }
}
