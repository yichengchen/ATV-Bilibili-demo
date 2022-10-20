//
//  UICollectionView+..swift
//  BilibiliLive
//
//  Created by yicheng on 2022/10/20.
//

import UIKit

extension UICollectionView.CellRegistration {
    var cellProvider: (UICollectionView, IndexPath, Item) -> Cell {
        return { collectionView, indexPath, item in
            collectionView.dequeueConfiguredReusableCell(
                using: self,
                for: indexPath,
                item: item
            )
        }
    }
}
