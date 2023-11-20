//
//  CommonPlayerOverlayView.swift
//  BilibiliLive
//
//  Created by yicheng on 2023/11/20.
//

import UIKit

class CommonPlayerOverlayView: UIView {
    let danMuView = DanmakuView(frame: UIScreen.main.bounds)
    private var debugView: UILabel?

    // MARK: LifeCycle

    init() {
        super.init(frame: .zero)
        initDanmuView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        danMuView.recaculateTracks()
    }

    private func initDanmuView() {
        addSubview(danMuView)
        danMuView.paddingTop = 5
        danMuView.trackHeight = 50
        danMuView.displayArea = Settings.danmuArea.percent
        danMuView.accessibilityLabel = "danmuView"
        danMuView.makeConstraintsToBindToSuperview()
        danMuView.isHidden = !Settings.defaultDanmuStatus
    }

    // MARK: Public

    func showDebugView() {
        if debugView == nil {
            debugView = UILabel()
            debugView?.backgroundColor = UIColor.black.withAlphaComponent(0.8)
            debugView?.textColor = UIColor.white
            addSubview(debugView!)
            debugView?.numberOfLines = 0
            debugView?.font = UIFont.systemFont(ofSize: 26)
            debugView?.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(12)
                make.right.equalToSuperview().offset(-12)
                make.width.equalTo(800)
            }
        }
        debugView?.isHidden = false
    }

    func hideDebugView() {
        debugView?.isHidden = true
    }

    func setDebug(text: String) {
        debugView?.text = text
    }

    func ensureDanmuViewFront() {
        bringSubviewToFront(danMuView)
        danMuView.play()
    }
}
