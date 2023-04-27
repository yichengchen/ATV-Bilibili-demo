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
        selectedWhiteView.isHidden = !isFocused
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

        descLabel.textColor = UIColor.secondaryLabel
        descLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        contentView.addSubview(descLabel)
        descLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.right.equalToSuperview().offset(-20)
        }
    }

    func updateView() {
        selectedWhiteView.isHidden = !(isFocused || isSelected)
        if !selectedWhiteView.isHidden {
            titleLabel.textColor = UIColor.black
            descLabel.textColor = UIColor.black
        } else {
            titleLabel.textColor = UIColor.white
            descLabel.textColor = UIColor.secondaryLabel
        }
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        updateView()
    }

    override var isSelected: Bool {
        didSet {
            print(description + isSelected.description)
            updateView()
        }
    }
}
