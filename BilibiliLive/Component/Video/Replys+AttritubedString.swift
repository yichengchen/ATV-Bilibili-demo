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
            let descender: CGFloat
            if let label = displayView as? UILabel {
                descender = label.font.descender
            } else {
                descender = -5
            }
            let emoteSize = 36.0
            for range in ranges {
                let textAttachment = NSTextAttachment()
                let textAttachmentString = NSMutableAttributedString(attachment: textAttachment)
                textAttachmentString.append(NSAttributedString(string: " ", attributes: [.font: UIFont.systemFont(ofSize: 10)]))
                attr.replaceCharacters(in: NSRange(range, in: attr.string), with: textAttachmentString)
                KF.url(url)
                    .resizing(referenceSize: CGSize(width: emoteSize, height: emoteSize))
                    .onSuccess { [weak textAttachment] res in
                        guard let textAttachment = textAttachment else { return }
                        textAttachment.bounds = CGRect(x: 0, y: descender, width: emoteSize, height: emoteSize)
                    }
                    .set(to: textAttachment, attributedView: displayView)
            }
        }
        return attr
    }
}
