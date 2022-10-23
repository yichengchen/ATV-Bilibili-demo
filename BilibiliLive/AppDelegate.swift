//
//  AppDelegate.swift
//  BilibiliLive
//
//  Created by Etan on 2021/3/27.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        CookieHandler.shared.restoreCookies()
        URLSession.shared.configuration.headers.add(.userAgent("BiLiBiLi AppleTV Client/1.0.0 (github/yichengchen/ATV-Bilibili-live-demo)"))
        window = UIWindow()
        if ApiRequest.isLogin() {
            if let expireDate = ApiRequest.getToken()?.expireDate {
                let now = Date()
                if expireDate.timeIntervalSince(now) < 60 * 60 * 30 {
                    ApiRequest.refreshToken()
                }
            } else {
                ApiRequest.refreshToken()
            }
            window?.rootViewController = BLTabBarViewController()
        } else {
            window?.rootViewController = LoginViewController.create()
        }
        window?.makeKeyAndVisible()
        return true
    }

    func showLogin() {
        window?.rootViewController = LoginViewController.create()
    }

    func showTabBar() {
        window?.rootViewController = BLTabBarViewController()
    }

    static var shared: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }
}
