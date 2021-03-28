//
//  DanmakuCellModel.swift
//  DanmakuKit
//
//  Created by Q YiZhong on 2020/8/16.
//

import UIKit

public enum DanmakuCellType {
    case floating
    case top
    case bottom
}

public protocol DanmakuCellModel {
    
    var cellClass: DanmakuCell.Type { get }
    
    var size: CGSize { get }
    
    /// Track for danmaku
    var track: UInt? { get set }
    
    var displayTime: Double { get }
    
    var type: DanmakuCellType { get }
    
    /// unique identifier
    var identifier: String { get }
    
    /// Used to determine if two cellmodels are equal
    /// - Parameter cellModel: other cellModel
    func isEqual(to cellModel: DanmakuCellModel) -> Bool
    
}
