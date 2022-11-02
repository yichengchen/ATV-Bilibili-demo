//
//  Animate1ViewController.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/10/29.
//

import Alamofire
import AVFoundation
import Fuzi
import RegexBuilder
import SwiftyJSON
import UIKit

class Anime1ViewController: UIViewController, BLTabBarContentVCProtocol {
    let collectionVC = FeedCollectionViewController()
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionVC.styleOverride = .normal
        collectionVC.show(in: self)
        collectionVC.didSelect = {
            [weak self] data in
            let record = data as! AnimateInfo
            let vc = Animate1DetailContentViewController(uid: record.uid)
            self?.present(vc, animated: true)
        }
        reloadData()
    }

    func reloadData() {
        Task {
            try? await loadData()
        }
    }

    func loadData() async throws {
        let task = AF.request("https://d1zquzjgwo9yb.cloudfront.net").serializingData()
        let data = try await task.value
        let json = JSON(data)
        let infos = json.arrayValue.map {
            AnimateInfo(title: $0[1].stringValue, uid: $0[0].intValue, ownerName: $0[2].stringValue, date: $0[3].stringValue + $0[4].stringValue)
        }
        collectionVC.displayDatas = infos
    }
}

struct AnimateInfo: DisplayData {
    let title: String
    let uid: Int
    let ownerName: String
    let date: String?
    var pic: URL? { URL(string: "https://sta.anicdn.com/playerImg/8.jpg") }
}

class Animate1DetailContentViewController: UIViewController {
    let uid: Int
    let collectionVC = FeedCollectionViewController()
    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        return [collectionVC.collectionView]
    }

    init(uid: Int) {
        self.uid = uid
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        collectionVC.styleOverride = .normal
        collectionVC.show(in: self)
        collectionVC.didSelect = {
            [weak self] data in
            let record = data as! Info
            let vc = Animate1PlayerViewController()
            vc.dataString = record.data
            self?.present(vc, animated: true)
        }
        Task {
            do {
                try await fetchData()
            } catch let err {
                print(err)
                dismiss(animated: true)
            }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    struct Info: DisplayData {
        var title: String
        var data: String
        var ownerName: String { "" }
        var pic: URL? { URL(string: "https://sta.anicdn.com/playerImg/8.jpg") }
    }

    func fetchData() async throws {
        let html = try await AF.request("https://anime1.me/", parameters: ["cat": uid]).serializingString().value
        let doc = try HTMLDocument(string: html)
        var infos = [Info]()
        for article in doc.xpath("//html/body/div/div[2]/div/main/article") {
            let title = article.children(staticTag: "header").first?.children(tag: "h2").first?.stringValue
            let data = article.children(tag: "div").last?.children(tag: "div").first?.firstChild(tag: "video")?.attributes["data-apireq"]
            guard let title, let data = data?.removingPercentEncoding else { continue }
            infos.append(Info(title: title, data: data))
        }
        collectionVC.displayDatas = infos
        updateFocusIfNeeded()
    }
}

class Animate1PlayerViewController: CommonPlayerViewController {
    enum Animate1Error: Error {
        case getJsonFail
    }

    var dataString = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        Task {
            do {
                try await self.request()
            } catch let err {
                showErrorAlertAndExit(message: err.localizedDescription)
            }
        }
    }

    func request() async throws {
        let data = try await AF.request("https://v.anime1.me/api", method: .post,
                                        parameters: ["d": dataString])
            .serializingData().value
        let json = JSON(data)
        guard var video = json["s"].arrayValue.first?["src"].string else { throw Animate1Error.getJsonFail }
        let asset = AVURLAsset(url: URL(string: "https:" + video)!)
        playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)
    }
}
