//
//  FeedCollectionViewCell.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/10/20.
//

import UIKit
import TVUIKit
import MarqueeLabel
import Kingfisher

class FeedCollectionViewCell: UICollectionViewCell {
    var onLongPress: (()->Void)?=nil
    var styleOverride: FeedDisplayStyle? {didSet { updateStyle() }}
    
    private let titleLabel = MarqueeLabel()
    private let upLabel = MarqueeLabel()
    private let imageView = UIImageView()
    private let cardView = TVCardView()
    private let infoView = UIView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    func setup() {
        let longpress = UILongPressGestureRecognizer(target: self, action: #selector(actionLongPress(sender:)))
        addGestureRecognizer(longpress)
        
        contentView.addSubview(cardView)
        cardView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        cardView.contentView.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
            make.top.equalToSuperview()
            make.height.equalTo(imageView.snp.width).multipliedBy(9.0/16)
        }
        imageView.layer.cornerRadius = 12
        imageView.clipsToBounds = true
        
        cardView.contentView.addSubview(infoView)
        infoView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(imageView.snp.bottom).offset(8).priority(.high)
        }
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(upLabel)
        stackView.alignment = .leading
        titleLabel.holdScrolling = true
        upLabel.holdScrolling = true
        titleLabel.speed = .rate(100)
        infoView.accessibilityIdentifier = "info base view"
        infoView.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    func setup(data: any DisplayData) {
        titleLabel.text = data.title
        upLabel.text = data.owner
        imageView.kf.setImage(with:data.pic,options: [.processor(DownsamplingImageProcessor(size: CGSize(width: 360, height: 202)))])
        updateStyle()
    }
    
    func startScroll() {
        titleLabel.restartLabel()
        upLabel.restartLabel()
        titleLabel.holdScrolling = false
        upLabel.holdScrolling = false
    }
    
    func stopScroll() {
        titleLabel.shutdownLabel()
        upLabel.shutdownLabel()
        titleLabel.holdScrolling = true
        upLabel.holdScrolling = true
    }
    
    private func updateStyle() {
        if styleOverride ?? Settings.displayStyle == .normal {
            titleLabel.font = UIFont.systemFont(ofSize: 30,weight: .semibold)
            upLabel.font = UIFont.systemFont(ofSize: 20)
        } else {
            titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
            upLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        }
    }
    
    
    @objc private func actionLongPress(sender:UILongPressGestureRecognizer) {
        guard sender.state == .began else { return }
        onLongPress?()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        onLongPress = nil
        stopScroll()
    }
}
