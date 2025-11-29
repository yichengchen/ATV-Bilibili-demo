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
        guard let superview = superview else {
            assertionFailure("View must have a superview before calling makeConstraintsToBindToSuperview")
            return self
        }
        return makeConstraints { _ in [
            leftAnchor.constraint(equalTo: superview.leftAnchor, constant: inset.left),
            rightAnchor.constraint(equalTo: superview.rightAnchor, constant: -inset.right),
            topAnchor.constraint(equalTo: superview.topAnchor, constant: inset.top),
            bottomAnchor.constraint(equalTo: superview.bottomAnchor, constant: -inset.bottom),
        ] }
    }

    @discardableResult
    func makeConstraintsBindToCenterOfSuperview() -> Self {
        guard let superview = superview else {
            assertionFailure("View must have a superview before calling makeConstraintsBindToCenterOfSuperview")
            return self
        }
        return makeConstraints { _ in [
            centerXAnchor.constraint(equalTo: superview.centerXAnchor),
            centerYAnchor.constraint(equalTo: superview.centerYAnchor),
        ] }
    }
}
