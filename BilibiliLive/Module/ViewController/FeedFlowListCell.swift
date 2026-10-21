//
//  FeedFlowListCell.swift
//  BilibiliLive
//

import Kingfisher
import SnapKit
import UIKit

final class FeedFlowListCell: BLMotionCollectionViewCell {
    static let reuseID = String(describing: FeedFlowListCell.self)

    var onLongPress: (() -> Void)?

    private let blurBackgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    private let imageView = UIImageView()
    private let titleLabel = UILabel()
    private let metaLabel = UILabel()
    private let overlayView = BLOverlayView()
    private var isCurrent = false

    override func setup() {
        super.setup()
        scaleFactor = 1.06
        let longpress = UILongPressGestureRecognizer(target: self, action: #selector(actionLongPress(sender:)))
        addGestureRecognizer(longpress)

        contentView.addSubview(blurBackgroundView)
        blurBackgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        blurBackgroundView.layer.cornerRadius = 20
        blurBackgroundView.layer.cornerCurve = .continuous
        blurBackgroundView.clipsToBounds = true

        blurBackgroundView.contentView.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview().inset(14)
            make.width.equalTo(170)
        }
        imageView.layer.cornerRadius = 14
        imageView.layer.cornerCurve = .continuous
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill

        imageView.addSubview(overlayView)
        overlayView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        overlayView.fontSize = 14

        blurBackgroundView.contentView.addSubview(titleLabel)
        blurBackgroundView.contentView.addSubview(metaLabel)

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(18)
            make.leading.equalTo(imageView.snp.trailing).offset(18)
            make.trailing.equalToSuperview().offset(-18)
        }
        titleLabel.font = .systemFont(ofSize: 28, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2

        metaLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.trailing.equalTo(titleLabel)
            make.bottom.equalToSuperview().offset(-18)
        }
        metaLabel.font = .systemFont(ofSize: 22, weight: .medium)
        metaLabel.textColor = UIColor.white.withAlphaComponent(0.78)
        metaLabel.numberOfLines = 1
    }

    func configure(with item: FeedFlowItem, isCurrent: Bool) {
        titleLabel.text = item.title
        metaLabel.text = item.listMetaText
        self.isCurrent = isCurrent

        if let coverURL = item.coverURL {
            imageView.kf.setImage(with: coverURL)
        } else {
            imageView.image = nil
        }

        var leftItems = [DisplayOverlay.DisplayOverlayItem]()
        var rightItems = [DisplayOverlay.DisplayOverlayItem]()
        if !item.viewCountText.isEmpty && !item.viewCountText.contains(":") {
            leftItems.append(DisplayOverlay.DisplayOverlayItem(icon: "play.rectangle",
                                                               text: item.viewCountText.replacingOccurrences(of: "观看", with: "")))
        } else if !item.danmakuCountText.isEmpty && !item.danmakuCountText.contains(":") {
            leftItems.append(DisplayOverlay.DisplayOverlayItem(icon: "play.rectangle",
                                                               text: item.danmakuCountText.replacingOccurrences(of: "观看", with: "")))
        }
        if !item.durationText.isEmpty {
            rightItems.append(DisplayOverlay.DisplayOverlayItem(icon: nil, text: item.durationText))
        }

        overlayView.configure(DisplayOverlay(leftItems: leftItems, rightItems: rightItems))
        overlayView.isHidden = leftItems.isEmpty && rightItems.isEmpty
        updateAppearance()
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        coordinator.addCoordinatedAnimations {
            self.updateAppearance()
        }
    }

    @objc private func actionLongPress(sender: UILongPressGestureRecognizer) {
        guard sender.state == .began else { return }
        onLongPress?()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onLongPress = nil
    }

    private func updateAppearance() {
        blurBackgroundView.effect = UIBlurEffect(style: isFocused || isCurrent ? .light : .dark)
        titleLabel.textColor = isFocused || isCurrent ? .black : .white
        metaLabel.textColor = isFocused || isCurrent ? UIColor.black.withAlphaComponent(0.75) : UIColor.white.withAlphaComponent(0.78)
    }
}
