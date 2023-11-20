//
//  BLContentProposalViewController.swift
//  BilibiliLive
//
//  Created by yicheng on 2023/11/20.
//

import AVKit
import UIKit

class BLContentProposalViewController: AVContentProposalViewController {
    let nextButton = BLCustomTextButton()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(nextButton)
        view.backgroundColor = UIColor.clear
        nextButton.addTarget(self, action: #selector(actionAccept), for: .primaryActionTriggered)
        nextButton.title = "下一个:" + (contentProposal?.title ?? "")
        nextButton.titleFont = UIFont.systemFont(ofSize: 30)
        nextButton.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-50)
            make.height.equalTo(60)
            make.width.greaterThanOrEqualTo(200)
            make.width.lessThanOrEqualTo(500)
            make.bottom.equalToSuperview().multipliedBy(0.75)
        }
    }

    @objc func actionAccept() {
        dismissContentProposal(for: .accept, animated: true)
    }
}
