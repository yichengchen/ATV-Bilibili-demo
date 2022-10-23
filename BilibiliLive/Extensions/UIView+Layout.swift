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
}
