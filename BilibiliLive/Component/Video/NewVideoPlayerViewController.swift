//
//  NewVideoPlayerViewController.swift
//  BilibiliLive
//
//  Created by yicheng on 2024/5/23.
//

import AVKit
import Combine
import UIKit

class NewVideoPlayerViewController: NewCommonPlayerViewController {
    var data: VideoDetail?
    var nextProvider: VideoNextProvider?

    init(playInfo: PlayInfo) {
        viewModel = NewVideoPlayerViewModel(playInfo: playInfo)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private let viewModel: NewVideoPlayerViewModel
    private var cancelable = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()
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

        Task {
            await viewModel.load()
        }
    }
}
