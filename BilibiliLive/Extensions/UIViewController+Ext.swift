//
//  UIViewController+Ext.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/8/20.
//

import UIKit

extension UIViewController {
    func topMostViewController() -> UIViewController {
        if let presented = presentedViewController {
            return presented.topMostViewController()
        }

        if let navigation = self as? UINavigationController {
            return navigation.visibleViewController?.topMostViewController() ?? navigation
        }

        if let tab = self as? UITabBarController {
            return tab.selectedViewController?.topMostViewController() ?? tab
        }

        return self
    }

    static func topMostViewController() -> UIViewController {
        return AppDelegate.shared.window!.rootViewController!.topMostViewController()
    }
}
