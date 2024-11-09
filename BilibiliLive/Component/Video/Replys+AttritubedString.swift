//
//  Replys+AttritubedString.swift
//  BilibiliLive
//
//  Created by yicheng on 9/11/2024.
//

import Kingfisher
import UIKit

extension Replys.Reply {
    func createAttributedString(displayView: UIView) -> NSAttributedString? {
        guard let emote = content.emote, !emote.isEmpty else {
            return nil
        }
        let attr = NSMutableAttributedString(string: content.message)
        for (tag, emote) in emote {
            guard let url = URL(string: emote.url) else { continue }
            let ranges = attr.string.ranges(of: tag).reversed()
            for range in ranges {
                let textAttachment = NSTextAttachment()
                attr.replaceCharacters(in: NSRange(range, in: attr.string), with: NSAttributedString(attachment: textAttachment))
                // TODO: 文本对其，添加间距
                KF.url(url)
                    .resizing(referenceSize: CGSize(width: 36, height: 36))
                    .roundCorner(radius: .point(15))
                    .set(to: textAttachment, attributedView: displayView)
            }
        }
        return attr
    }
}
