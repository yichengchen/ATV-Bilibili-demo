//
//  FeedCollectionViewCell.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/10/20.
//

import Kingfisher
import MarqueeLabel
import TVUIKit
import UIKit

class FeedCollectionViewCell: BLMotionCollectionViewCell {
    var onLongPress: (() -> Void)?
    var styleOverride: FeedDisplayStyle? { didSet { if oldValue != styleOverride { updateStyle() } }}

    private let titleLabel = UILabel()
    private let upLabel = UILabel()
    private let sortLabel = UILabel()
    private let imageView = UIImageView()
    let infoView = UIView()
    private let avatarView = UIImageView()

    override func setup() {
        super.setup()
        let longpress = UILongPressGestureRecognizer(target: self, action: #selector(actionLongPress(sender:)))
        addGestureRecognizer(longpress)

        contentView.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
            make.top.equalToSuperview()
            make.height.equalTo(imageView.snp.width).multipliedBy(9.0 / 16)
        }

        imageView.layer.cornerRadius = moreLittleSornerRadius
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill

        imageView.addSubview(avatarView)

//        sortLabel.alpha = 0.7

        infoView.alpha = 0.8
        contentView.addSubview(infoView)
        infoView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(imageView.snp.bottom).offset(8)
        }

        let hStackView = UIStackView()
        let stackView = UIStackView()
        infoView.addSubview(hStackView)

//        hStackView.addArrangedSubview(avatarView)
        hStackView.addArrangedSubview(sortLabel)
//        sortLabel.snp.makeConstraints { make in
//            make.width.height.equalTo(70)
//        }
        sortLabel.textColor = .white

        hStackView.addArrangedSubview(stackView)
        hStackView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().priority(.high)
            make.height.equalTo(stackView.snp.height)
        }

        hStackView.alignment = .top
        hStackView.spacing = 10
        avatarView.backgroundColor = .clear
        let style = styleOverride ?? Settings.displayStyle
        let aHeight: CGFloat = style == .large ? 44 : 33
        avatarView.snp.makeConstraints { make in
            make.bottom.right.equalToSuperview().offset(-4)
            make.width.equalTo(avatarView.snp.height)
            make.height.equalTo(aHeight)
        }
        stackView.setContentHuggingPriority(.required, for: .vertical)
        avatarView.setContentHuggingPriority(.defaultLow, for: .vertical)
        avatarView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        avatarView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        avatarView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        stackView.axis = .vertical
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(upLabel)
        stackView.alignment = .leading
        stackView.spacing = 6
        stackView.setContentHuggingPriority(.required, for: .vertical)
//        titleLabel.holdScrolling = true
        titleLabel.numberOfLines = 2
        titleLabel.setContentHuggingPriority(.required, for: .vertical)
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        titleLabel.textColor = UIColor(named: "titleColor")

//        titleLabel.fadeLength = 60

        upLabel.setContentHuggingPriority(.required, for: .vertical)
        upLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        upLabel.textColor = UIColor(named: "upTitleColor")
        upLabel.adjustsFontSizeToFitWidth = true
        upLabel.minimumScaleFactor = 0.1
    }

    func setup(data: any DisplayData, indexPath: IndexPath? = nil) {
        titleLabel.text = data.title
        if let index = indexPath, index.row <= 98 {
            sortLabel.isHidden = false
            sortLabel.text = String(index.row + 1)
            sortLabel.sizeToFit()
        } else {
            sortLabel.text = "0"
            sortLabel.isHidden = true
        }
        upLabel.text = [data.ownerName, data.date].compactMap({ $0 }).joined(separator: " · ")
        if var pic = data.pic {
            if pic.scheme == nil {
                pic = URL(string: "http:\(pic.absoluteString)")!
            }
            imageView.kf.setImage(with: pic, options: [.processor(DownsamplingImageProcessor(size: CGSize(width: 720, height: 404))), .cacheOriginalImage])
        }
        if let avatar = data.avatar {
            avatarView.isHidden = false
            avatarView.kf.setImage(with: avatar, options: [.processor(DownsamplingImageProcessor(size: CGSize(width: 80, height: 80))), .processor(RoundCornerImageProcessor(radius: .widthFraction(0.5))), .cacheSerializer(FormatIndicatedCacheSerializer.png)])
        } else {
            avatarView.isHidden = true
        }
        updateStyle()
    }

//    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
//        super.didUpdateFocus(in: context, with: coordinator)
//        if isFocused {
//            startScroll()
//        } else {
//            stopScroll()
//        }
//    }
//
//    private func startScroll() {
    ////        titleLabel.restartLabel()
    ////        titleLabel.holdScrolling = false
//    }
//
//    private func stopScroll() {
    ////        titleLabel.shutdownLabel()
    ////        titleLabel.holdScrolling = true
//    }

    private func updateStyle() {
        let style = styleOverride ?? Settings.displayStyle
        titleLabel.font = style.titleFont
        upLabel.font = style.upFont
        sortLabel.font = style.sortFont
    }

    @objc private func actionLongPress(sender: UILongPressGestureRecognizer) {
        guard sender.state == .began else { return }
        onLongPress?()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onLongPress = nil
        avatarView.image = nil
//        stopScroll()
    }
}

extension FeedDisplayStyle {
    var fractionalWidth: CGFloat {
        switch self {
        case .big:
            return 1.0 / CGFloat(bigItmeCount)
        case .large:
            return 1.0 / CGFloat(largeItmeCount)
        case .normal:
            return 1.0 / CGFloat(normalItmeCount)
        case .sideBar:
            return 1.0 / CGFloat(largeItmeCount)
        }
    }

    var fractionalHeight: CGFloat {
        switch self {
        case .large, .big:
            return fractionalWidth / 1.5
        case .normal:
            return fractionalWidth / 1.5
        case .sideBar:
            return fractionalWidth / 1.15
        }
    }

    var groupFractionalHeight: CGFloat {
        switch self {
        case .big:
            return 2 / 5
        case .large, .normal, .sideBar:
            return 1 / 3
        }
    }

    var hSpacing: CGFloat {
        switch self {
        case .big:
            return 30
        case .large, .normal, .sideBar:
            return 20
        }
    }

    var heightEstimated: CGFloat {
        switch self {
        case .big:
            return 516
        case .large:
            return 516
        case .normal, .sideBar:
            return 380
        }
    }

    var titleFont: UIFont {
        switch self {
        case .large, .big:
            return UIFont.systemFont(ofSize: 26, weight: .semibold)
        case .normal:
            return UIFont.systemFont(ofSize: 26, weight: .semibold)
        case .sideBar:
            return UIFont.systemFont(ofSize: 24, weight: .semibold)
        }
    }

    var upFont: UIFont {
        switch self {
        case .large, .big:
            return UIFont.systemFont(ofSize: 20)
        case .normal:
            return UIFont.systemFont(ofSize: 20)
        case .sideBar:
            return UIFont.systemFont(ofSize: 18, weight: .semibold)
        }
    }

    var sortFont: UIFont {
        switch self {
        case .large, .big:
            return UIFont.systemFont(ofSize: 60, weight: .bold)
        case .normal:
            return UIFont.systemFont(ofSize: 50, weight: .bold)
        case .sideBar:
            return UIFont.systemFont(ofSize: 50, weight: .bold)
        }
    }
}
