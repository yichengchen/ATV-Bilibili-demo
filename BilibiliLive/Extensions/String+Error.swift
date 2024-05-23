//
//  String+Error.swift
//  BilibiliLive
//
//  Created by yicheng on 2024/5/24.
//

import Foundation

extension String: LocalizedError {
    public var errorDescription: String? { return self }
}
