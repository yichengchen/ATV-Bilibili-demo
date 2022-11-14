//
//  BLMotionCollectionViewCell.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/10/23.
//

import TVUIKit
import UIKit

class BLMotionCollectionViewCell: UICollectionViewCell {
    private var motionEffectV: UIInterpolatingMotionEffect!
    private var motionEffectH: UIInterpolatingMotionEffect!
    var scaleFactor: CGFloat = 1.1
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func setup() {
        motionEffectV = UIInterpolatingMotionEffect(keyPath: "center.y", type: .tiltAlongVerticalAxis)
        motionEffectV.maximumRelativeValue = 8
        motionEffectV.minimumRelativeValue = -8
        motionEffectH = UIInterpolatingMotionEffect(keyPath: "center.x", type: .tiltAlongHorizontalAxis)
        motionEffectH.maximumRelativeValue = 8
        motionEffectH.minimumRelativeValue = -8
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        if isFocused {
            let scaleFactor = self.scaleFactor
            coordinator.addCoordinatedAnimations {
                self.transform = CGAffineTransformMakeScale(scaleFactor, scaleFactor)
                let scaleDiff = (self.bounds.size.height * scaleFactor - self.bounds.size.height) / 2
                self.transform = CGAffineTransformTranslate(self.transform, 0, -scaleDiff)
                self.layer.shadowOffset = CGSizeMake(0, 16)
                self.layer.shadowOpacity = 0.2
                self.layer.shadowRadius = 18.0
                self.addMotionEffect(self.motionEffectH)
                self.addMotionEffect(self.motionEffectV)
            }
        } else {
            coordinator.addCoordinatedAnimations {
                self.transform = CGAffineTransformIdentity
                self.layer.shadowOpacity = 0
                self.layer.shadowOffset = CGSizeMake(0, 0)
                self.removeMotionEffect(self.motionEffectH)
                self.removeMotionEffect(self.motionEffectV)
            }
        }
    }
}
