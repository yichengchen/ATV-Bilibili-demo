//
//  HotSearchCell.swift
//  BilibiliLive
//
//  Created by Claude on 2024/12/24.
//

import SnapKit
import UIKit

/// 热搜关键词Cell
class HotSearchCell: BLMotionCollectionViewCell {
    private let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    private let rankLabel = UILabel()
    private let keywordLabel = UILabel()
    private let iconImageView = UIImageView()
    private let containerStack = UIStackView()

    override func setup() {
        super.setup()
        scaleFactor = 1.12

        // 背景模糊效果
        contentView.addSubview(effectView)
        effectView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        effectView.layer.cornerRadius = 12
        effectView.clipsToBounds = true

        // 水平堆叠: 排名 + 关键词 + 图标
        containerStack.axis = .horizontal
        containerStack.spacing = 8
        containerStack.alignment = .center
        effectView.contentView.addSubview(containerStack)
        containerStack.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.bottom.equalToSuperview().inset(12)
        }

        // 排名标签
        rankLabel.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        rankLabel.textAlignment = .center
        rankLabel.setContentHuggingPriority(.required, for: .horizontal)
        rankLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        containerStack.addArrangedSubview(rankLabel)

        // 关键词标签
        keywordLabel.font = UIFont.systemFont(ofSize: 24, weight: .medium)
        keywordLabel.textColor = .white
        keywordLabel.numberOfLines = 1
        keywordLabel.lineBreakMode = .byTruncatingTail
        containerStack.addArrangedSubview(keywordLabel)

        // 热门图标 (可选)
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .systemOrange
        iconImageView.snp.makeConstraints { make in
            make.width.height.equalTo(20)
        }
        iconImageView.isHidden = true
        containerStack.addArrangedSubview(iconImageView)
    }

    /// 配置热搜关键词
    func configure(with hotWord: HotSearchResult.HotWord) {
        keywordLabel.text = hotWord.show_name

        // 排名颜色
        rankLabel.text = "\(hotWord.pos)"
        switch hotWord.pos {
        case 1:
            rankLabel.textColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0) // 金色
        case 2:
            rankLabel.textColor = UIColor(red: 0.75, green: 0.75, blue: 0.75, alpha: 1.0) // 银色
        case 3:
            rankLabel.textColor = UIColor(red: 0.8, green: 0.5, blue: 0.2, alpha: 1.0) // 铜色
        default:
            rankLabel.textColor = UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0) // 灰色
        }

        // 热门图标
        if let iconURL = hotWord.icon, !iconURL.isEmpty {
            iconImageView.isHidden = false
            iconImageView.image = UIImage(systemName: "flame.fill")
        } else {
            iconImageView.isHidden = true
        }
    }

    /// 配置历史搜索关键词
    func configureAsHistory(_ keyword: String) {
        rankLabel.text = ""
        rankLabel.isHidden = true
        keywordLabel.text = keyword
        iconImageView.image = UIImage(systemName: "clock")
        iconImageView.tintColor = .systemGray
        iconImageView.isHidden = false
    }

    /// 配置为"清空历史"按钮
    func configureAsClearHistory() {
        rankLabel.text = ""
        rankLabel.isHidden = true
        keywordLabel.text = "清空历史"
        keywordLabel.textColor = UIColor.systemRed
        iconImageView.image = UIImage(systemName: "trash")
        iconImageView.tintColor = .systemRed
        iconImageView.isHidden = false
    }

    /// 配置为"加载更多"按钮
    func configureAsLoadMore(for sectionTitle: String) {
        rankLabel.text = ""
        rankLabel.isHidden = true
        keywordLabel.text = "加载更多\(sectionTitle)"
        keywordLabel.textColor = UIColor.systemBlue
        iconImageView.image = UIImage(systemName: "arrow.right.circle")
        iconImageView.tintColor = .systemBlue
        iconImageView.isHidden = false
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        rankLabel.isHidden = false
        rankLabel.text = ""
        keywordLabel.text = ""
        keywordLabel.textColor = .white
        iconImageView.isHidden = true
        iconImageView.image = nil
        iconImageView.tintColor = .systemOrange
    }
}

// MARK: - LoadMoreCell

/// 加载更多Cell (用于搜索结果分页)
class LoadMoreCell: BLMotionCollectionViewCell {
    private let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    var isLoading: Bool = false {
        didSet {
            updateLoadingState()
        }
    }

    override func setup() {
        super.setup()
        scaleFactor = 1.08

        contentView.addSubview(effectView)
        effectView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        effectView.layer.cornerRadius = 16
        effectView.clipsToBounds = true

        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        effectView.contentView.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        iconView.image = UIImage(systemName: "arrow.down.circle")
        iconView.tintColor = .systemBlue
        iconView.contentMode = .scaleAspectFit
        iconView.snp.makeConstraints { make in
            make.width.height.equalTo(44)
        }
        stack.addArrangedSubview(iconView)

        titleLabel.text = "加载更多"
        titleLabel.font = UIFont.systemFont(ofSize: 22, weight: .medium)
        titleLabel.textColor = .systemBlue
        stack.addArrangedSubview(titleLabel)

        activityIndicator.hidesWhenStopped = true
        activityIndicator.color = .white
        effectView.contentView.addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }

    private func updateLoadingState() {
        if isLoading {
            iconView.isHidden = true
            titleLabel.isHidden = true
            activityIndicator.startAnimating()
        } else {
            iconView.isHidden = false
            titleLabel.isHidden = false
            activityIndicator.stopAnimating()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        isLoading = false
    }
}
