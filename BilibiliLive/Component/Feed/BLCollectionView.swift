//
//  BLCollectionView.swift
//  BilibiliLive
//
//  Created by mantieus on 2025/10/10.
//

import UIKit

class BLCollectionView: UICollectionView {
    // MARK: - 捕获遥控器方向键

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        super.pressesBegan(presses, with: event)
        print("pressesBegan")

        for press in presses {
            guard press.type == .leftArrow else { continue }

            // 当前焦点的 indexPath
            if let indexPath = indexPathsForSelectedItems?.first {
                if indexPath.item == 0 {
                    // 🎯 已在最左边，再按左键
                    print("👈 已经在最左边，再往左滑动/按下 —— 触发自定义动作")
                }
            }
        }
    }

    override func motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        print("pressesBegan")
        super.motionBegan(motion, with: event)
    }
}
