//
//  AVInfoPanelCollectionViewThumbnailCell+Hook.swift
//  BilibiliLive
//
//  Created by yicheng on 2023/1/9.
//

import Foundation
import UIKit

class AVInfoPanelCollectionViewThumbnailCellHook {
    static func start() {
        UICollectionViewCell.swizzAVInfoPanelCollectionViewThumbnailCell()
    }
}

private extension UICollectionViewCell {
    static func swizzAVInfoPanelCollectionViewThumbnailCell() {
        guard let swizzledClass: AnyClass = NSClassFromString("AVInfoPanelCollectionViewThumbnailCell") else { return }
        let originalSelector = NSSelectorFromString("setTitle:")

        let swizzledSelector = #selector(swizz_setTitle(_:))
        let originalSelector2 = NSSelectorFromString("didUpdateFocusInContext:withAnimationCoordinator:")
        let swizzledSelector2 = #selector(swizz_didUpdateFocusInContext(_:withAnimationCoordinator:))

        guard let originalMethod = class_getInstanceMethod(swizzledClass, originalSelector),
              let swizzledMethod = class_getInstanceMethod(self, swizzledSelector),
              let originalMethod2 = class_getInstanceMethod(swizzledClass, originalSelector2),
              let swizzledMethod2 = class_getInstanceMethod(self, swizzledSelector2)

        else { return }
        method_exchangeImplementations(originalMethod, swizzledMethod)
        method_exchangeImplementations(originalMethod2, swizzledMethod2)
    }

    @objc func swizz_setTitle(_ title: String) {
        swizz_setTitle(title)
        contentView.subviews.compactMap { $0 as? UILabel }.forEach { $0.textColor = .white }
    }

    @objc func swizz_didUpdateFocusInContext(_ selected: Any, withAnimationCoordinator: Any) {
        swizz_didUpdateFocusInContext(selected, withAnimationCoordinator: withAnimationCoordinator)
        contentView.subviews.compactMap { $0 as? UILabel }.forEach { $0.textColor = .white }
    }
}
