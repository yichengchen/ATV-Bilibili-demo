//
//  DanmakuTextCellModel.swift
//  DanmakuKit_Example
//
//  Created by Q YiZhong on 2020/8/29.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import Foundation
import SwiftyJSON
import UIKit

class DanmakuTextCellModel: DanmakuCellModel, Equatable {
    var identifier = ""

    var text = ""
    var color: UIColor = .white
    var font = UIFont.systemFont(ofSize: Settings.danmuSize.size)

    var cellClass: DanmakuCell.Type {
        return DanmakuTextCell.self
    }

    var size: CGSize = .zero

    var track: UInt?

    var displayTime: Double = 8

    var type: DanmakuCellType = .floating

    var isPause = false

    func calculateSize() {
        size = NSString(string: text).boundingRect(with: CGSize(width: CGFloat(Float.infinity
        ), height: 20), options: [.usesFontLeading, .usesLineFragmentOrigin], attributes: [.font: font], context: nil).size
    }

    static func == (lhs: DanmakuTextCellModel, rhs: DanmakuTextCellModel) -> Bool {
        return lhs.identifier == rhs.identifier
    }

    func isEqual(to cellModel: DanmakuCellModel) -> Bool {
        return identifier == cellModel.identifier
    }

    init(str: String) {
        text = str
        type = .floating
        calculateSize()
    }
}
