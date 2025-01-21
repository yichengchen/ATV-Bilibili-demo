//
//  UIView+Layout.swift
//  BilibiliLive
//
//  Created by Etan Chen on 2021/4/4.
//

import UIKit

extension UIView {
    @discardableResult
    func makeConstraints(_ block: (UIView) -> [NSLayoutConstraint]) -> Self {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate(block(self))
        return self
    }

    @discardableResult
    func makeConstraintsToBindToSuperview(_ inset: UIEdgeInsets = .zero) -> Self {
        return makeConstraints { [
            $0.leftAnchor.constraint(equalTo: $0.superview!.leftAnchor, constant: inset.left),
            $0.rightAnchor.constraint(equalTo: $0.superview!.rightAnchor, constant: -inset.right),
            $0.topAnchor.constraint(equalTo: $0.superview!.topAnchor, constant: inset.top),
            $0.bottomAnchor.constraint(equalTo: $0.superview!.bottomAnchor, constant: -inset.bottom),
        ] }
    }

    @discardableResult
    func makeConstraintsBindToCenterOfSuperview() -> Self {
        return makeConstraints { [
            $0.centerXAnchor.constraint(equalTo: $0.superview!.centerXAnchor),
            $0.centerYAnchor.constraint(equalTo: $0.superview!.centerYAnchor),
        ] }
    }

    /// 添加一个毛玻璃view
    /// - Parameters:
    ///   - style: 样式
    ///   - isShowShadow: 是否有阴影
    func setBlurEffectView(style: UIBlurEffect.Style? = .regular,
                           cornerRadius: CGFloat? = 0,
                           cornerMask: CACornerMask? = nil,
                           alpha: CGFloat = 1.0)
    {
        let setStyle = style
        let eView = getblurEffectView(style: setStyle)
        eView.alpha = alpha
        eView.isUserInteractionEnabled = true
        addSubview(eView)
        eView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        if cornerRadius ?? 0 > 0 {
            eView.contentView.setCornerRadius(cornerRadius: cornerRadius!, cornerMask: cornerMask)
        }

        sendSubviewToBack(eView)
    }

    func setAutoGlassEffectView(
        cornerRadius: CGFloat? = 0,
        cornerMask: CACornerMask? = nil
    ) {
        if #available(tvOS 26.0, *) {
            self.backgroundColor = .clear
            let glassEffect = UIGlassEffect()
            let effectView = UIVisualEffectView()
            self.insertSubview(effectView, at: 0)
            if let v = cornerRadius {
                effectView.cornerConfiguration = .corners(radius: .fixed(v))
            }
            effectView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }

            effectView.effect = glassEffect

        } else {
            setBlurEffectView(cornerRadius: cornerRadius, cornerMask: cornerMask)
        }
    }

    func setGlassEffectView() {
        if #available(tvOS 26.0, *) {
            //            self.backgroundColor = .clear
            let glassEffect = UIGlassEffect()
            let effectView = UIVisualEffectView()
            self.insertSubview(effectView, at: 0)
            effectView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }

            effectView.effect = glassEffect
        }
    }

    /// 设置圆角边框
    /// - Parameters:
    ///   - view: 需要设置的view
    ///   - cornerRadius: 圆角
    ///   - borderColor: 颜色
    ///   - borderWidth: 边框宽度
    func setCornerRadius(cornerRadius: CGFloat,
                         cornerMask: CACornerMask? = nil,
                         borderColor: UIColor? = nil,
                         borderWidth: CGFloat? = 0,
                         shadowColor: UIColor? = nil,
                         shadowRadius: CGFloat = 12,
                         shadowOffset: CGSize = CGSize(width: 0, height: 0),
                         shadowAlpha: CGFloat = 0.3,
                         tag: Int? = 100)
    {
        // 圆角
        layer.cornerRadius = cornerRadius
        layer.masksToBounds = true

        // 4个角
        if cornerMask != nil {
            layer.maskedCorners = cornerMask!
        }

        // 边框
        if borderColor != nil {
            layer.borderColor = borderColor?.cgColor
        }

        // 边框宽度
        if borderWidth ?? 0 > 0 {
            layer.borderWidth = borderWidth!
        }

        // 阴影
        BLAfter(afterTime: 0.2) {
            if shadowColor != nil {
                var isFindShadowView = false
                self.superview?.subviews.forEach({ view in
                    if view.tag == tag {
                        isFindShadowView = true
                        return
                    }
                })

                guard !isFindShadowView else {
                    return
                }

                let shadowView: UIView = .init(frame: CGRect(x: 50, y: 300, width: 50, height: 50))
                shadowView.alpha = 0
                shadowView.backgroundColor = UIColor(named: "shadowViewBgColor")
                if cornerMask != nil {
                    shadowView.layer.maskedCorners = cornerMask!
                }

                self.superview?.insertSubview(shadowView, belowSubview: self)
                if shadowView.superview != nil {
                    shadowView.snp.makeConstraints { make in
//                        make.edges.equalTo(self)
                        make.top.left.equalTo(self).offset(1)
                        make.right.bottom.equalTo(self).offset(-1)
                    }
                }

                shadowView.tag = tag!
                shadowView.layer.shadowColor = shadowColor?.cgColor
                shadowView.layer.shadowOpacity = Float(shadowAlpha)
                shadowView.layer.shadowRadius = shadowRadius
                shadowView.layer.shadowOffset = shadowOffset
                shadowView.layer.cornerRadius = cornerRadius
                shadowView.clipsToBounds = false
                BLAnimate(withDuration: 0.2) {
                    shadowView.alpha = shadowAlpha
                }

            } else {
                self.superview?.subviews.forEach({ view in
                    if view.tag == tag {
                        view.removeFromSuperview()
                    }
                })
            }
        }
    }

    /// 设置阴影参数
    /// - Parameters:
    ///   - color: 对应 Sketch 阴影 "颜色"
    ///   - shadowOpacity: 透明度
    ///   - shadowRadius: 陰影的半徑
    ///   - offset: 对应 Sketch 阴影 "偏移" x y, CGSize(width: x, height: y)
    func addShadow(shadowColor: UIColor = .black,
                   shadowOpacity: CGFloat = 1,
                   shadowRadius: CGFloat = 12,
                   shadowOffset: CGSize = CGSize(width: 2, height: 12))
    {
        layer.shadowColor = shadowColor.cgColor
        layer.shadowOffset = shadowOffset
        layer.shadowRadius = shadowRadius
        layer.shadowOpacity = Float(shadowOpacity)
    }
}

public extension UIView {
    @objc var left: CGFloat {
        return frame.origin.x
    }

    @objc var top: CGFloat {
        return frame.origin.y
    }

    @objc var right: CGFloat {
        return frame.origin.x + frame.size.width
    }

    @objc var bottom: CGFloat {
        return frame.origin.y + frame.size.height
    }

    @objc var centerX: CGFloat {
        return center.x
    }

    @objc var centerY: CGFloat {
        return center.y
    }

    @objc var width: CGFloat {
        return frame.size.width
    }

    @objc var height: CGFloat {
        return frame.size.height
    }
}

public func BLAnimate(withDuration: CGFloat, animations: @escaping () -> Void, completion: ((Bool) -> Void)? = nil) {
    UIView.animate(withDuration: withDuration, delay: 0, options: .curveEaseIn, animations: animations, completion: completion)
}

public func BLAfter(afterTime: CGFloat, complete: @escaping () -> Void) {
    DispatchQueue.main.asyncAfter(deadline: .now() + afterTime, execute: {
        complete()
    })
}

public func getblurEffectView(style: UIBlurEffect.Style? = .light) -> UIVisualEffectView {
    // 首先创建一个模糊效果
    let blurEffect = UIBlurEffect(style: style!)
    // 接着创建一个承载模糊效果的视图
    let headView = UIVisualEffectView(effect: blurEffect)

    return headView
}
