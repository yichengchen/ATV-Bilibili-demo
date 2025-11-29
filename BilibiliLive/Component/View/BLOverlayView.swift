//
//  BLOverlayView.swift
//  BilibiliLive
//
//  Created by bitxeno on 2025/11/24.
//

import SnapKit
import UIKit

class BLOverlayView: UIView {
    // MARK: - UI Elements

    var fontSize: CGFloat = 21

    // 1. 渐变层
    private let gradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        // 透明 -> 黑色(60%透明度)
        layer.colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.6).cgColor]
        layer.locations = [0.0, 1.0]
        return layer
    }()

    // 2. 左侧容器
    private let leftStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        return stack
    }()

    // 3. 右侧容器
    private let rightStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        return stack
    }()

    // 4. 右上角角标容器
    private let badgeContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .systemPink
        view.layer.cornerRadius = 12
        view.layer.maskedCorners = [.layerMinXMaxYCorner]
        view.layer.masksToBounds = true
        view.isHidden = true
        return view
    }()

    private let badgeLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.textAlignment = .center
        return label
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func layoutSubviews() {
        super.layoutSubviews()
        // 关键：在这里更新渐变层的 frame，确保它始终位于视图底部
        // 假设渐变层高度为 40pt
        let gradientHeight: CGFloat = 60
        gradientLayer.frame = CGRect(
            x: 0,
            y: bounds.height - gradientHeight,
            width: bounds.width,
            height: gradientHeight
        )
    }

    // MARK: - Setup

    private func setupUI() {
        // 插入渐变层到最底层
        layer.addSublayer(gradientLayer)

        addSubview(leftStackView)
        addSubview(rightStackView)

        addSubview(badgeContainer)
        badgeContainer.addSubview(badgeLabel)
    }

    private func setupConstraints() {
        // 左侧容器
        leftStackView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(8)
            make.bottom.equalToSuperview().offset(-6)
        }

        // 右侧容器
        rightStackView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-8)
            make.bottom.equalToSuperview().offset(-6)
        }

        // 角标
        badgeContainer.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.trailing.equalToSuperview()
        }

        badgeLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10))
        }
    }

    // MARK: - Public API

    /// 设置角标
    func setBadge(text: String?, color: UIColor = .systemPink) {
        if let text = text, !text.isEmpty {
            badgeLabel.text = text
            badgeContainer.backgroundColor = color
            badgeContainer.isHidden = false
        } else {
            badgeContainer.isHidden = true
        }
    }

    /// 配置显示数据
    func configure(_ overlay: DisplayOverlay) {
        // 清空现有视图
        leftStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        rightStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // 添加左侧项目
        for item in overlay.leftItems {
            let itemView = createInfoItem(icon: item.icon, text: item.text)
            leftStackView.addArrangedSubview(itemView)
        }

        // 添加右侧项目
        for item in overlay.rightItems {
            let itemView = createInfoItem(icon: item.icon, text: item.text)
            rightStackView.addArrangedSubview(itemView)
        }

        // 配置角标
        if let badgeText = overlay.badge?.text, !badgeText.isEmpty {
            badgeLabel.text = badgeText
            badgeContainer.isHidden = false
        } else {
            badgeContainer.isHidden = true
        }
        if let color = overlay.badge?.color {
            badgeContainer.backgroundColor = color
        }
    }

    // MARK: - Helper Methods

    // 创建包含图标和Label的小容器
    private func createInfoItem(icon: String?, text: String) -> UIView {
        let container = UIView()

        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: fontSize)
        label.text = text

        container.addSubview(label)

        if let iconName = icon {
            let config = UIImage.SymbolConfiguration(pointSize: 10, weight: .regular)
            let image = UIImage(systemName: iconName, withConfiguration: config)?
                .withTintColor(.white, renderingMode: .alwaysOriginal)
            let imageView = UIImageView(image: image)

            container.addSubview(imageView)

            imageView.snp.makeConstraints { make in
                make.leading.centerY.equalToSuperview()
                make.size.equalTo(fontSize)
            }

            label.snp.makeConstraints { make in
                make.leading.equalTo(imageView.snp.trailing).offset(2)
                make.trailing.top.bottom.equalToSuperview()
            }
        } else {
            // 无图标时，label直接填充整个容器
            label.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }

        return container
    }
}
