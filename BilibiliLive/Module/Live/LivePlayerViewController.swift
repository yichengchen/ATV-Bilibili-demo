//
//  LivePlayerViewController.swift
//  BilibiliLive
//
//  Created by Etan on 2021/3/27.
//

import Alamofire
import AVKit
import Foundation
import SwiftyJSON
import UIKit

class LivePlayerViewController: CommonPlayerViewController {
    var room: LiveRoom?

    private var viewModel: LivePlayerViewModel?
    deinit {
        Logger.debug("deinit live player")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let room = room else {
            Logger.warn("LivePlayerViewController: room is nil")
            showErrorAlertAndExit(message: "直播间信息缺失")
            return
        }
        viewModel = LivePlayerViewModel(room: room)
        viewModel?.onPluginReady = { [weak self] plugins in
            DispatchQueue.main.async {
                plugins.forEach { self?.addPlugin(plugin: $0) }
            }
        }

        viewModel?.onError = { [weak self] in
            self?.showErrorAlertAndExit(message: $0)
        }

        viewModel?.start()
    }
}
