//
//  DouyuLivePlayerViewController.swift
//  BilibiliLive
//
//  Created by yicheng on 2023/4/7.
//

import Foundation
class DouyuLivePlayerViewController: VLCLivePlayerViewController {
    let rid: Int
    let danmuProvider: DouLiveDanMuProvider
    init(id: Int) {
        rid = id
        danmuProvider = DouLiveDanMuProvider(roomID: id)
        super.init(nibName: nil, bundle: nil)
        danmuProvider.onDanmu = { [weak self] in
            self?.danMuView.shoot(danmaku: DanmakuTextCellModel(str: $0))
        }
        danmuProvider.start()
    }

    deinit {
        print("DouyuLivePlayerViewController deinit")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        Task {
            do {
                let url = try await DouLiveUrlParser.liveURL(self.rid)
                self.play(url: URL(string: url)!)
            } catch let err {
                showErrorAlertAndExit(title: "获取播放地址失败", message: err.localizedDescription)
            }
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        danmuProvider.stop()
        player.stop()
    }
}
