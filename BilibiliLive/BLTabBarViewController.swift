//
//  BLTabBarViewController.swift
//  BilibiliLive
//
//  Created by Etan Chen on 2021/4/5.
//

protocol BLTabBarContentVCProtocol {
    func reloadData()
}

class BLTabBarViewController: UITabBarController, UITabBarControllerDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        let loginVC = UIStoryboard(name: "Main", bundle: Bundle.main).instantiateViewController(identifier: "Login")
        let liveVC = HomeViewController()
        let feedVC = FeedViewController()
        let historyVC = HistoryViewController()
        let toViewVC = ToViewViewController()
        liveVC.tabBarItem.title = "Live"
        feedVC.tabBarItem.title = "Feeds"
        historyVC.tabBarItem.title = "History"
        toViewVC.tabBarItem.title = "ToView"
        setViewControllers([liveVC,feedVC,historyVC,toViewVC,loginVC], animated: false)
    }
    
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        if let vc = viewController as? BLTabBarContentVCProtocol {
            vc.reloadData()
        }
    }
}
