//
//  BLMenuLineCollectionViewCell.swift
//  BilibiliLive
//
//  Created by ManTie on 2024/7/4.
//

import UIKit

class BLMenuLineCollectionViewCell: BLSettingLineCollectionViewCell {
    var iconImageView = UIImageView()
    var iconBgView = UIView()
    override func addsubViews() {
//        selectedWhiteView.setAutoGlassEffectView(cornerRadius: selectedWhiteView.height / 2)
        selectedWhiteView.setCornerRadius(cornerRadius: height / 2)
        selectedWhiteView.backgroundColor = UIColor(named: "menuCellColor")
        selectedWhiteView.isHidden = !isFocused
        addSubview(selectedWhiteView)
        selectedWhiteView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        selectedWhiteView.alpha = 0.7
        addSubview(iconBgView)
        addSubview(iconImageView)
        let imageViewHeight = 32.0
        iconImageView.setCornerRadius(cornerRadius: imageViewHeight / 2.0)
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.snp.makeConstraints { make in
            make.width.height.equalTo(imageViewHeight)
            make.left.equalTo(16)
            make.centerY.equalToSuperview()
        }
        iconBgView.snp.makeConstraints { make in
            make.top.left.equalTo(iconImageView).offset(-4)
            make.right.bottom.equalTo(iconImageView).offset(4)
        }
//        iconBgView.setAutoGlassEffectView()
        iconBgView.setCornerRadius(cornerRadius: (imageViewHeight + 8) / 2.0)

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.left.equalTo(iconImageView.snp.right).offset(12)
            make.trailing.equalToSuperview().offset(8)
            make.centerY.equalTo(iconImageView)
        }
        titleLabel.textAlignment = .left
        titleLabel.font = UIFont.systemFont(ofSize: 26, weight: .medium)
        titleLabel.textColor = UIColor(named: "titleColor")
    }
}
