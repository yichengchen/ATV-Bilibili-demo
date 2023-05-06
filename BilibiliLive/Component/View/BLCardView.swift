//
//  BLCardView.swift
//  BilibiliLive
//
//  Created by whw on 2023/4/26.
//

import UIKit

class BLCardView: BLMotionCollectionViewCell {
    let titleLabel = UILabel()
    let descLabel = UILabel()
    let selectedWhiteView = UIView()

    override func setup() {
        super.setup()

        selectedWhiteView.backgroundColor = UIColor.white
        selectedWhiteView.layer.cornerRadius = 10
        contentView.addSubview(selectedWhiteView)
        selectedWhiteView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalToSuperview().offset(20)
        }

        descLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        contentView.addSubview(descLabel)
        descLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.right.equalToSuperview().offset(-20)
        }

        updateView(focused: false)

        #if os(iOS)
            let pointerInteraction = UIPointerInteraction(delegate: self)
            addInteraction(pointerInteraction)
        #endif
    }

    func updateView(focused: Bool) {
        selectedWhiteView.isHidden = !focused
        if focused {
            titleLabel.textColor = UIColor.black
            descLabel.textColor = UIColor.black
        } else {
            titleLabel.textColor = UIColor.label
            descLabel.textColor = UIColor.secondaryLabel
        }
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        updateView(focused: isFocused)
    }
}

#if os(iOS)
    extension BLCardView: UIPointerInteractionDelegate {
        func pointerInteraction(_ interaction: UIPointerInteraction, styleFor region: UIPointerRegion) -> UIPointerStyle? {
            return .system()
        }

        func pointerInteraction(_ interaction: UIPointerInteraction, willEnter region: UIPointerRegion, animator: UIPointerInteractionAnimating) {
            updateView(focused: true)
        }

        func pointerInteraction(_ interaction: UIPointerInteraction, willExit region: UIPointerRegion, animator: UIPointerInteractionAnimating) {
            updateView(focused: false)
        }
    }
#endif
