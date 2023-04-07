//
//  DouyuLivePlayerViewController.swift
//  BilibiliLive
//
//  Created by yicheng on 2023/4/7.
//

import Foundation
class DouyuLivePlayerViewController: VLCLivePlayerViewController {
    let rid: Int
    init(id: Int) {
        rid = id
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        Task {
            let url = try! await DouLiveUrlParser.liveURL(self.rid)
            self.play(url: URL(string: url)!)
        }
    }
}
