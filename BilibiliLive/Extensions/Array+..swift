//
//  Array+..swift
//  BilibiliLive
//
//  Created by yicheng on 2022/10/21.
//

import Foundation

extension Sequence where Element: Hashable {
    func uniqued() -> [Element] {
        var set = Set<Element>()
        return filter { set.insert($0).inserted }
    }
}
