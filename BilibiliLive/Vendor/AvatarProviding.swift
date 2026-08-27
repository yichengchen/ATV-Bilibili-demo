//
//  AvatarProviding.swift
//  BilibiliLive
//
//  Created by Lucka on 2026-08-27.
//

import Foundation

protocol AvatarProviding {
    var avatar: URL? { get }
}

extension AvatarProviding {
    func avatar(size: Int) -> URL? {
        guard let avatar else {
            return nil
        }
        
        return avatar
            .deletingLastPathComponent()
            .appending(component: avatar.lastPathComponent + "@\(size)w_\(size)h.jpg")
    }
}
