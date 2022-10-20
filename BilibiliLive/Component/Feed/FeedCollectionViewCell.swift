//
//  FeedCollectionViewCell.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/10/20.
//

import UIKit
import TVUIKit

class FeedCollectionViewCell: UICollectionViewCell {
    var onLongPress: (()->Void)?=nil

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

//            make.height.equalTo(Settings.displayStyle == .normal ? 250 : 313)
        }
        imageView.layer.cornerRadius = 12
        imageView.clipsToBounds = true
        
        cardView.contentView.addSubview(infoView)
        infoView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
            make.top.equalTo(imageView.snp.bottom).offset(8)
            make.bottom.equalToSuperview()
        }
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(upLabel)
        
        infoView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.bottom.equalToSuperview()
            make.leading.equalToSuperview().offset(2)
            make.trailing.equalToSuperview().inset(2)
        }

        if Settings.displayStyle == .normal {
            titleLabel.font = UIFont.systemFont(ofSize: 30,weight: .semibold)
            upLabel.font = UIFont.systemFont(ofSize: 20)
        } else {
            titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
            upLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        }
    }
    
    func setup(data: any DisplayData) {
        titleLabel.text = data.title
        upLabel.text = data.owner
        imageView.kf.setImage(with:data.pic)
        
    }
    
    func startScroll() {
        titleLabel.restartLabel()
        upLabel.restartLabel()
    }
    
    func stopScroll() {
        titleLabel.shutdownLabel()
        upLabel.shutdownLabel()
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
