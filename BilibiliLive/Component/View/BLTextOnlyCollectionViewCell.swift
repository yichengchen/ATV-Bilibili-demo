//
//  BLTextOnlyCollectionViewCell.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/10/24.
//

import Foundation
import UIKit

class BLTextOnlyCollectionViewCell: BLMotionCollectionViewCell {
    private let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    private let selectedWhiteView = UIView()
    let titleLabel = UILabel()
    var didSelect: ((_ isFocused: Bool) -> Void)?

    override func setup() {
        super.setup()
        scaleFactor = 1.15
        contentView.addSubview(effectView)
        effectView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        effectView.contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerX.centerY.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(20)
            make.top.bottom.lessThanOrEqualToSuperview().inset(8)
        }
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2
        titleLabel.font = UIFont.systemFont(ofSize: 22, weight: .medium)
        effectView.layer.cornerRadius = normailSornerRadius
        effectView.clipsToBounds = true
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        didSelect?(isFocused)
        selectedWhiteView.isHidden = !isFocused
    }
}
