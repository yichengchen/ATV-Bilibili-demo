//
//  UpSpaceTitleSupplementaryView.swift
//  BilibiliLive
//
//  Created by bitxeno on 2025/11/27.
//

import SnapKit
import UIKit

class UpSpaceTitleSupplementaryView: UICollectionReusableView {
    let imageView = UIImageView()
    let nameLabel = UILabel()
    let despLabel = UILabel()
    let followButton = BLCustomButton()
    let blockButton = BLCustomButton()
    private let focusGuide = UIFocusGuide()

    var onFollowTapped: ((Bool) -> Void)?
    var onBlockTapped: ((Bool) -> Void)?
    var mid: Int?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    private func setupUI() {
        addSubview(imageView)
        addSubview(nameLabel)
        addSubview(despLabel)
        addSubview(followButton)
        addSubview(blockButton)
        addLayoutGuide(focusGuide)

        imageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(30)
            make.top.equalToSuperview()
            make.bottom.equalToSuperview().offset(-30)
            make.width.equalTo(imageView.snp.height)
            make.width.equalTo(110)
        }

        nameLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(5)
            make.leading.equalTo(imageView.snp.trailing).offset(20)
        }

        despLabel.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel.snp.leading)
            make.top.equalTo(nameLabel.snp.bottom).offset(20)
            make.trailing.lessThanOrEqualTo(followButton.snp.leading).offset(-40)
        }

        blockButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-30)
            make.centerY.equalToSuperview()
            make.width.equalTo(blockButton.snp.height).multipliedBy(20.5 / 18.0)
            make.height.equalTo(80)
        }

        followButton.snp.makeConstraints { make in
            make.trailing.equalTo(blockButton.snp.leading).offset(-20)
            make.centerY.equalToSuperview()
            make.width.equalTo(followButton.snp.height).multipliedBy(20.5 / 18.0)
            make.height.equalTo(80)
        }

        nameLabel.font = UIFont.systemFont(ofSize: 30, weight: .semibold)
        despLabel.font = UIFont.systemFont(ofSize: 23, weight: .regular)
        despLabel.textColor = UIColor(named: "titleColor")
        despLabel.numberOfLines = 2

        followButton.image = UIImage(systemName: "heart")
        followButton.onImage = UIImage(systemName: "heart.fill")
        followButton.onPrimaryAction = { [weak self] _ in
            self?.followButtonTapped()
        }

        blockButton.image = UIImage(systemName: "slash.circle")
        blockButton.onImage = UIImage(systemName: "person.crop.circle.badge.minus")
        blockButton.onPrimaryAction = { [weak self] _ in
            self?.blockButtonTapped()
        }

        focusGuide.preferredFocusEnvironments = [followButton, blockButton]
        focusGuide.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.top.bottom.equalTo(followButton)
            make.trailing.equalTo(followButton.snp.leading)
        }
    }

    @objc private func followButtonTapped() {
        followButton.isOn.toggle()
        onFollowTapped?(followButton.isOn)

        if let mid = mid {
            WebRequest.follow(mid: mid, follow: followButton.isOn)
        }
    }

    @objc private func blockButtonTapped() {
        blockButton.isOn.toggle()

        if let mid = mid {
            WebRequest.block(mid: mid, block: blockButton.isOn) { [weak self] _ in
                guard let self else { return }
                self.onBlockTapped?(self.blockButton.isOn)
            }
        }
    }
}
