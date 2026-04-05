//
//  AVInfoPanelCollectionViewThumbnailCell+Hook.swift
//  BilibiliLive
//
//  Created by yicheng on 2023/1/9.
//

import Foundation
import ObjectiveC
import UIKit

class AVInfoPanelCollectionViewThumbnailCellHook {
    static func start() {
        UICollectionViewCell.startAVInfoPanelSwizzle()
    }
}

extension UICollectionViewCell {
    static let infoActionFocusedNotification = Notification.Name("AVInfoPanelActionFocused")
}

private extension UICollectionViewCell {
    private static var avInfoPanelActionTitleKey: UInt8 = 0
    private static let infoPanelClassNameMarker = "AVInfoPanel"

    static func startAVInfoPanelSwizzle() {
        _ = avInfoPanelSwizzleToken
    }

    static let avInfoPanelSwizzleToken: Void = {
        swizzAVInfoPanelCollectionViewThumbnailCell()
    }()

    static func swizzAVInfoPanelCollectionViewThumbnailCell() {
        let didUpdateFocusSelector = #selector(didUpdateFocus(in:with:))
        let swizzledDidUpdateFocusSelector = #selector(swizz_didUpdateFocus(in:with:))
        let setTitleSelector = NSSelectorFromString("setTitle:")
        let swizzledSetTitleSelector = #selector(swizz_setTitle(_:))

        for targetClass in avInfoPanelCellClasses() {
            swizzleMethodIfNeeded(on: targetClass,
                                  originalSelector: didUpdateFocusSelector,
                                  swizzledSelector: swizzledDidUpdateFocusSelector)
            swizzleMethodIfNeeded(on: targetClass,
                                  originalSelector: setTitleSelector,
                                  swizzledSelector: swizzledSetTitleSelector)
        }
    }

    static func avInfoPanelCellClasses() -> [AnyClass] {
        let expectedClassCount = Int(objc_getClassList(nil, 0))
        guard expectedClassCount > 0 else { return [] }

        let classBuffer = UnsafeMutablePointer<AnyClass?>.allocate(capacity: expectedClassCount)
        defer { classBuffer.deallocate() }

        let autoreleasingClassBuffer = AutoreleasingUnsafeMutablePointer<AnyClass>(classBuffer)
        let actualClassCount = Int(objc_getClassList(autoreleasingClassBuffer, Int32(expectedClassCount)))

        let matchedClasses = UnsafeBufferPointer(start: classBuffer, count: actualClassCount)
            .compactMap { $0 }
            .filter { targetClass in
                let className = NSStringFromClass(targetClass)
                return className.contains(infoPanelClassNameMarker) &&
                    isSubclass(targetClass, of: UICollectionViewCell.self)
            }

        return matchedClasses
            .filter { candidateClass in
                !matchedClasses.contains { otherClass in
                    otherClass !== candidateClass && isSubclass(otherClass, of: candidateClass)
                }
            }
            .sorted { NSStringFromClass($0) < NSStringFromClass($1) }
    }

    static func isSubclass(_ targetClass: AnyClass, of parentClass: AnyClass) -> Bool {
        var currentClass: AnyClass? = targetClass
        while let candidateClass = currentClass {
            if candidateClass == parentClass {
                return true
            }
            currentClass = class_getSuperclass(candidateClass)
        }
        return false
    }

    static func swizzleMethodIfNeeded(on targetClass: AnyClass,
                                      originalSelector: Selector,
                                      swizzledSelector: Selector)
    {
        guard let originalMethod = class_getInstanceMethod(targetClass, originalSelector),
              let baseSwizzledMethod = class_getInstanceMethod(UICollectionViewCell.self, swizzledSelector)
        else { return }

        class_addMethod(targetClass,
                        swizzledSelector,
                        method_getImplementation(baseSwizzledMethod),
                        method_getTypeEncoding(baseSwizzledMethod))

        guard let targetSwizzledMethod = class_getInstanceMethod(targetClass, swizzledSelector) else { return }

        let didAddOriginalMethod = class_addMethod(targetClass,
                                                   originalSelector,
                                                   method_getImplementation(targetSwizzledMethod),
                                                   method_getTypeEncoding(targetSwizzledMethod))

        if didAddOriginalMethod {
            class_replaceMethod(targetClass,
                                swizzledSelector,
                                method_getImplementation(originalMethod),
                                method_getTypeEncoding(originalMethod))
        } else {
            method_exchangeImplementations(originalMethod, targetSwizzledMethod)
        }
    }

    @objc func swizz_setTitle(_ title: String) {
        // 调用原实现 (已被交换)
        swizz_setTitle(title)
        avInfoPanelActionTitle = title
        contentView.subviews.compactMap { $0 as? UILabel }.forEach { $0.textColor = .white }
    }

    @objc func swizz_didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        // 调用原实现
        swizz_didUpdateFocus(in: context, with: coordinator)

        let className = NSStringFromClass(type(of: self))
        guard className.contains("AVInfoPanel") else { return }

        // 强制白色文字 (视觉一致性)
        recursiveApplyWhiteText(to: self)

        guard isFocused else { return }

        // 尝试多种方式提取标题
        let title = avInfoPanelActionTitle ??
            accessibilityLabel ??
            recursiveFindTitle(in: self)

        if let title = title {
            NotificationCenter.default.post(name: Self.infoActionFocusedNotification,
                                            object: nil,
                                            userInfo: ["title": title])
        }
    }

    private func recursiveApplyWhiteText(to view: UIView) {
        if let label = view as? UILabel {
            label.textColor = .white
        }
        for subview in view.subviews {
            recursiveApplyWhiteText(to: subview)
        }
    }

    private func recursiveFindTitle(in view: UIView) -> String? {
        if let label = view as? UILabel, let text = label.text, !text.isEmpty {
            return text
        }
        for subview in view.subviews {
            if let found = recursiveFindTitle(in: subview) {
                return found
            }
        }
        return nil
    }

    var avInfoPanelActionTitle: String? {
        get {
            objc_getAssociatedObject(self, &Self.avInfoPanelActionTitleKey) as? String
        }
        set {
            objc_setAssociatedObject(self, &Self.avInfoPanelActionTitleKey, newValue, .OBJC_ASSOCIATION_COPY_NONATOMIC)
        }
    }
}
