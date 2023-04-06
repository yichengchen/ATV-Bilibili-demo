//
//  IinaPlusLivePlayerViewController.swift
//  BilibiliLive
//
//  Created by lowking on 2023-04-05.
//

import Alamofire
import AVKit
import Foundation
import SwiftyJSON
import TVVLCKit
import UIKit

class IinaPlusLivePlayerViewController: UIViewController, VLCMediaPlayerDelegate {
    enum LiveError: Error {
        case noLiving
        case noPlaybackUrl
        case fetchApiFail
    }

    var room: IinaPlusLive? {
        didSet {
            roomUrl = room?.url ?? ""
        }
    }

    private var vlcPlayer: VLCMediaPlayer?
    private var roomUrl: String = ""
    private var danMuProvider: LiveDanMuProvider?
    private var playInfo = [PlayInfo]()

    deinit {
        Logger.debug("deinit live player")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let loadingView = UIActivityIndicatorView()
        view.addSubview(loadingView)
        loadingView.color = .white
        loadingView.style = .large
        loadingView.startAnimating()
        loadingView.makeConstraintsBindToCenterOfSuperview()

        Task {
            do {
                try await refreshRoomsID()
//                initDataSource()
                try await initPlayer()
            } catch let err {
                endWithError(err: err)
            }
        }
//        danMuView.play()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillAppear(animated)
        vlcPlayer?.stop()
        danMuProvider?.stop()
    }

    func play() {
        if let url = playInfo.first?.url {
//            danMuProvider?.start()
//            danMuView.play()

            vlcPlayer?.media = VLCMedia(url: URL(string: url)!)
            vlcPlayer?.play()
        } else {
            showErrorAlertAndExit(title: "url is nil", message: "url: \(playInfo.first?.url.count ?? 0)")
        }
//        if Settings.danmuMask, Settings.vnMask {
//            maskProvider = VMaskProvider()
//            setupMask()
//        }
    }

    func showErrorAlertAndExit(title: String = "播放失败", message: String = "未知错误") {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let actionOk = UIAlertAction(title: "OK", style: .default) {
            [weak self] _ in
            self?.dismiss(animated: true, completion: nil)
        }
        alertController.addAction(actionOk)
        present(alertController, animated: true, completion: nil)
    }

    func endWithError(err: Error) {
        let alert = UIAlertController(title: "播放失败", message: "\(err)", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: {
            [weak self] _ in
            self?.dismiss(animated: true, completion: nil)
        }))
        present(alert, animated: true, completion: nil)
    }

    func refreshRoomsID() async throws {
        let url = "\(Settings.iinaPlusHost)/video?url=\(roomUrl)"
        let resp = await AF.request(url).serializingData().result
        switch resp {
        case let .success(object):
            let json = JSON(object)
        case let .failure(error):
            throw LiveError.noLiving
        }
    }

    struct PlayInfo {
        let formate: String?
        let url: String
        let current_qn: Int?
        let sourceUrl: String?
    }

    func initPlayer() async throws {
        let requestUrl = "\(Settings.iinaPlusHost)/video?url=\(roomUrl)"
        guard let data = try? await AF.request(requestUrl).serializingData().result.get() else {
            throw LiveError.fetchApiFail
        }
        var playInfos = [PlayInfo]()
        let json = JSON(data)

        var maxQuality = 0
        var maxQualityUrl = ""
        for (_, sjson): (String, JSON) in json["streams"].dictionaryValue {
            let currentQuality = sjson["quality"].intValue
            if currentQuality > maxQuality {
                maxQuality = currentQuality
                maxQualityUrl = sjson["url"].stringValue
                let src = sjson["src"].arrayValue
                if maxQualityUrl.isEmpty && src.count > 0 {
                    maxQualityUrl = src[0].stringValue
                    if src.count > 1 {
                        maxQualityUrl = src[1].stringValue
                    }
                }
            }
        }
        let pInfo = PlayInfo(formate: "flv", url: maxQualityUrl, current_qn: maxQuality, sourceUrl: roomUrl)
        playInfos.append(pInfo)
        if playInfos.count > 0 {
            vlcPlayer = VLCMediaPlayer()
            vlcPlayer?.delegate = self
            vlcPlayer?.drawable = view
            playInfo = playInfos
            play()
            return
        }

        throw LiveError.noPlaybackUrl
    }
}
