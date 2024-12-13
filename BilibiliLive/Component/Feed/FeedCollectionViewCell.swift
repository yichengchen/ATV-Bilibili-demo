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

    private let titleLabel = MarqueeLabel()
    private let upLabel = UILabel()
    private let imageView = UIImageView()
    private let infoView = UIView()
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
        imageView.layer.cornerRadius = 12
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill

        contentView.addSubview(infoView)
        infoView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(imageView.snp.bottom).offset(8)
        }

        let hStackView = UIStackView()
        let stackView = UIStackView()
        infoView.addSubview(hStackView)
        hStackView.addArrangedSubview(avatarView)
        hStackView.addArrangedSubview(stackView)
        hStackView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().priority(.high)
            make.height.equalTo(stackView.snp.height)
        }

        hStackView.alignment = .top
        hStackView.spacing = 10
        avatarView.backgroundColor = .clear
        avatarView.snp.makeConstraints { make in
            make.width.equalTo(avatarView.snp.height)
            make.height.equalTo(stackView.snp.height).multipliedBy(0.7)
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
        titleLabel.holdScrolling = true
        titleLabel.setContentHuggingPriority(.required, for: .vertical)
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        upLabel.setContentHuggingPriority(.required, for: .vertical)
        upLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        upLabel.textColor = UIColor(named: "titleColor")
        upLabel.adjustsFontSizeToFitWidth = true
        upLabel.minimumScaleFactor = 0.1
    }

    func setup(data: any DisplayData) {
        titleLabel.text = data.title
        upLabel.text = [data.ownerName, data.date].compactMap({ $0 }).joined(separator: " · ")
        if var pic = data.pic {
            if pic.scheme == nil {
                pic = URL(string: "http:\(pic.absoluteString)")!
            }
            imageView.kf.setImage(with: pic, options: [.processor(DownsamplingImageProcessor(size: CGSize(width: 360, height: 202))), .cacheOriginalImage])
        }
        if let avatar = data.avatar {
            avatarView.isHidden = false
            avatarView.kf.setImage(with: avatar, options: [.processor(DownsamplingImageProcessor(size: CGSize(width: 80, height: 80))), .processor(RoundCornerImageProcessor(radius: .widthFraction(0.5))), .cacheSerializer(FormatIndicatedCacheSerializer.png)])
        } else {
            avatarView.isHidden = true
        }
        updateStyle()
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        if isFocused {
            startScroll()
        } else {
            stopScroll()
        }
    }

    private func startScroll() {
        titleLabel.restartLabel()
        titleLabel.holdScrolling = false
    }

    private func stopScroll() {
        titleLabel.shutdownLabel()
        titleLabel.holdScrolling = true
    }

    private func updateStyle() {
        let style = styleOverride ?? Settings.displayStyle
        titleLabel.font = style.titleFont
        upLabel.font = style.upFont
    }

    @objc private func actionLongPress(sender: UILongPressGestureRecognizer) {
        guard sender.state == .began else { return }
        onLongPress?()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onLongPress = nil
        avatarView.image = nil
        stopScroll()
    }
}

extension FeedDisplayStyle {
    var fractionalWidth: CGFloat {
        switch self {
        case .large, .sideBar:
            return 0.33
        case .normal:
            return 0.25
        }
    }

    var fractionalHeight: CGFloat {
        switch self {
        case .large:
            return fractionalWidth / 1.5
        case .normal:
            return fractionalWidth / 1.5
        case .sideBar:
            return fractionalWidth / 1.15
        }
    }

    var heightEstimated: CGFloat {
        switch self {
        case .large:
            return 516
        case .normal, .sideBar:
            return 380
        }
    }

    var titleFont: UIFont {
        switch self {
        case .large:
            return UIFont.preferredFont(forTextStyle: .headline)
        case .normal:
            return UIFont.systemFont(ofSize: 30, weight: .semibold)
        case .sideBar:
            return UIFont.systemFont(ofSize: 26, weight: .semibold)
        }
    }

    var upFont: UIFont {
        switch self {
        case .large:
            return UIFont.preferredFont(forTextStyle: .footnote)
        case .normal:
            return UIFont.systemFont(ofSize: 24)
        case .sideBar:
            return UIFont.systemFont(ofSize: 20, weight: .semibold)
        }
    }
}
