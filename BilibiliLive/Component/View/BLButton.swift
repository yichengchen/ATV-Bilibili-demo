//
//  BLButton.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/10/22.
//

import SnapKit
import TVUIKit

@IBDesignable
@MainActor
class BLCustomButton: BLButton {
    @IBInspectable var image: UIImage? {
        didSet { updateButton() }
    }

    @IBInspectable var onImage: UIImage? {
        didSet { updateButton() }
    }

    @IBInspectable var highLightImage: UIImage? {
        didSet { updateButton() }
    }

    @IBInspectable var title: String? {
        didSet {
            updateTitleLabel()
        }
    }

    @IBInspectable var titleColor: UIColor = .white.withAlphaComponent(0.9) {
        didSet { titleLabel.textColor = titleColor }
    }

    @IBInspectable var titleFont: UIFont = .systemFont(ofSize: 20) {
        didSet { titleLabel.font = titleFont }
    }

    var isOn: Bool = false {
        didSet {
            updateButton()
        }
    }

    private let titleLabel = UILabel()
    private let imageView = UIImageView()

    override func setup() {
        super.setup()
        titleLabel.isUserInteractionEnabled = false
        effectView.contentView.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.height.equalToSuperview().multipliedBy(0.5)
            make.height.equalTo(imageView.snp.width)
        }
        imageView.image = image
        addSubview(titleLabel)
        titleLabel.textAlignment = .center
        titleLabel.font = titleFont
        titleLabel.textColor = .white
        updateTitleLabel(force: true)
    }

    private func updateTitleLabel(force: Bool = false) {
        let shouldHide = title == nil || title?.count == 0
        titleLabel.text = title
        if force || titleLabel.isHidden != shouldHide {
            titleLabel.isHidden = shouldHide
            if shouldHide {
                titleLabel.snp.removeConstraints()
            } else {
                titleLabel.snp.makeConstraints { make in
                    make.leading.trailing.bottom.equalToSuperview()
                    make.top.equalTo(effectView.snp.bottom).offset(10)
                }
            }
        }
    }

    private func getImage() -> UIImage? {
        isOn ? onImage : image
    }

    private func updateButton() {
        action?(isFocused)
        if isFocused {
            if UITraitCollection.current.userInterfaceStyle == .dark {
                print("当前是暗黑模式 🌙")
                imageView.image = highLightImage ?? getImage()
                imageView.tintColor = .black
            } else {
                print("当前是浅色模式 ☀️")
                imageView.image = highLightImage ?? getImage()
                imageView.tintColor = .black
            }

        } else {
            if UITraitCollection.current.userInterfaceStyle == .dark {
                print("当前是暗黑模式 🌙")
                imageView.image = getImage()
                imageView.tintColor = .white
            } else {
                print("当前是浅色模式 ☀️")
                imageView.image = getImage()
                imageView.tintColor = .white
            }
        }
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        updateButton()
    }
}

@IBDesignable
@MainActor
class BLCustomTextButton: BLButton {
    private let titleLabel = UILabel()
    var object: Any?

    @IBInspectable var title: String? {
        didSet { titleLabel.text = title }
    }

    @IBInspectable var titleColor: UIColor = .white {
        didSet { titleLabel.textColor = titleColor }
    }

    @IBInspectable var titleSelectedColor: UIColor = .black {
        didSet { titleLabel.textColor = titleColor }
    }

    @IBInspectable var titleFont: UIFont = .systemFont(ofSize: 18) {
        didSet { titleLabel.font = titleFont }
    }

    override func setup() {
        super.setup()
        effectView.layer.cornerRadius = normailSornerRadius
        effectView.contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.right.equalToSuperview().inset(24)
        }
        titleLabel.text = title
        titleLabel.font = titleFont
        if UITraitCollection.current.userInterfaceStyle == .dark {
            print("当前是暗黑模式 🌙")
            titleLabel.textColor = titleColor
        } else {
            print("当前是浅色模式 ☀️")
            titleLabel.textColor = titleColor
        }
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        if UITraitCollection.current.userInterfaceStyle == .dark {
            print("当前是暗黑模式 🌙")
            titleLabel.textColor = isFocused ? titleSelectedColor : titleColor
        } else {
            print("当前是浅色模式 ☀️")
            titleLabel.textColor = isFocused ? titleSelectedColor : titleColor
        }
    }
}

class BLButton: UIControl {
    private var motionEffect: UIInterpolatingMotionEffect!

    fileprivate var effectView = UIVisualEffectView()
    private let selectedWhiteView = UIView()

    var action: ((_ isFocused: Bool) -> Void)?

    var onPrimaryAction: ((BLButton) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override var canBecomeFocused: Bool { return true }

    func setup() {
        effectView.effect = UIBlurEffect(style: .extraDark)

        isUserInteractionEnabled = true
        motionEffect = UIInterpolatingMotionEffect(keyPath: "center.x", type: .tiltAlongHorizontalAxis)
        motionEffect.maximumRelativeValue = 2
        motionEffect.minimumRelativeValue = -2
        selectedWhiteView.isHidden = !isFocused
        addSubview(effectView)
        effectView.isUserInteractionEnabled = false
        effectView.clipsToBounds = true
        effectView.layer.cornerRadius = normailSornerRadius
        effectView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().priority(.high)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.effectView.layer.cornerRadius = self.effectView.height / 2
        }

        effectView.contentView.addSubview(selectedWhiteView)
        selectedWhiteView.backgroundColor = UIColor.white
        selectedWhiteView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        super.pressesEnded(presses, with: event)
        if presses.first?.type == .select {
            sendActions(for: .primaryActionTriggered)
            onPrimaryAction?(self)
        }
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        if isFocused {
            selectedWhiteView.isHidden = false
            let scale = 1.04
            coordinator.addCoordinatedAnimations {
                self.transform = CGAffineTransformMakeScale(scale, scale)
                let scaleDiff = (self.bounds.size.height * scale - self.bounds.size.height) / 2
                self.transform = CGAffineTransformTranslate(self.transform, 0, -scaleDiff)
                self.layer.shadowOffset = CGSizeMake(0, 10)
                self.layer.shadowOpacity = 0.15
                self.layer.shadowRadius = 16.0
                self.addMotionEffect(self.motionEffect)
            }
        } else {
            selectedWhiteView.isHidden = true
            coordinator.addCoordinatedAnimations {
                self.transform = CGAffineTransformIdentity
                self.layer.shadowOpacity = 0
                self.layer.shadowOffset = CGSizeMake(0, 0)
                self.removeMotionEffect(self.motionEffect)
            }
        }
    }
}
