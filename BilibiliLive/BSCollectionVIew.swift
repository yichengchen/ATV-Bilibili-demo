//
//  BSCollectionVIew.swift
//  BilibiliLive
//
//  Created by ManTie on 2024/7/4.
//

import UIKit

class BSCollectionVIew: UICollectionView {
    /*
     // Only override draw() if you perform custom drawing.
     // An empty implementation adversely affects performance during animation.
     override func draw(_ rect: CGRect) {
         // Drawing code
     }
     */
    override var canBecomeFocused: Bool {
        return false
    }

    override var preferredFocusedView: UIView? {
        return visibleCells.last
    }
}
