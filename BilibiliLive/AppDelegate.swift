//
//  AppDelegate.swift
//  BilibiliLive
//
//  Created by Etan on 2021/3/27.
//

import Alamofire
import AVFoundation
import CocoaLumberjackSwift
import UIKit
@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let fmp4Path = Bundle.main.path(forResource: "2", ofType: "mp4")!

        let fmp4 = try! Data(contentsOf: URL(fileURLWithPath: fmp4Path, isDirectory: false))
        Task {
            if let res = try? await AF.request("http://127.0.0.1:8080/2.mp4",
                                               headers: ["Range": "bytes=0-1023",
                                                         "Referer": "https://www.bilibili.com/"])
                .serializingData().result.get()
            {
                let x = await MoovParseUtil.processData(initialData: res) { offset, length in
                    let more = try! await AF.request("http://127.0.0.1:8080/2.mp4",
                                                     headers: ["Range": "bytes=\(offset)-\(offset + length - 1)",
                                                               "Referer": "https://www.bilibili.com/"]).serializingData().result.get()
                    return more
                }
                let y = MoovParseUtil.getIframeList(from: x!)
                MoovParseUtil.generateIframePlayList(iframes: y!)
            }
        }

        Logger.setup()
        AVInfoPanelCollectionViewThumbnailCellHook.start()
        CookieHandler.shared.restoreCookies()
        BiliBiliUpnpDMR.shared.start()
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
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
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
