//
//  VideoPlayerViewController.swift
//  BilibiliLive
//
//  Created by yicheng on 2024/5/23.
//

import AVKit
import Combine
import UIKit

struct PlayInfo {
    let aid: Int
    var cid: Int? = 0
    var epid: Int? = 0 // 港澳台解锁需要
    var isBangumi: Bool = false
    var ctime: Int? = 0

    var isCidVaild: Bool {
        return cid ?? 0 > 0
    }
}

class VideoNextProvider {
    init(seq: [PlayInfo]) {
        playSeq = seq
    }

    private var index = 0
    private let playSeq: [PlayInfo]
    func reset() {
        index = 0
    }

    func getNext() -> PlayInfo? {
        index += 1
        if index < playSeq.count {
            return playSeq[index]
        }
        return nil
    }
}

class VideoPlayerViewController: CommonPlayerViewController {
    var data: VideoDetail?
    var nextProvider: VideoNextProvider?

    init(playInfo: PlayInfo) {
        viewModel = VideoPlayerViewModel(playInfo: playInfo)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private let viewModel: VideoPlayerViewModel
    private var cancelable = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.nextProvider = nextProvider
        viewModel.onPluginReady.receive(on: DispatchQueue.main).sink { [weak self] completion in
            switch completion {
            case let .failure(err):
                self?.showErrorAlertAndExit(message: err)
            default:
                break
            }
        } receiveValue: { [weak self] plugins in
            plugins.forEach { self?.addPlugin(plugin: $0) }
        }.store(in: &cancelable)
        viewModel.onPluginRemove.sink { [weak self] in
            self?.removePlugin(plugin: $0)
        }.store(in: &cancelable)
        viewModel.onExit = { [weak self] in
            self?.dismiss(animated: true)
        }
        Task {
            await viewModel.load()
        }
    }
}
