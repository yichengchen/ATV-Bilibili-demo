//
// Created by Yam on 2024/6/9.
//

import Kingfisher
import UIKit

class ReplyCell: UICollectionViewCell {
    class var identifier: String {
        return String(describing: Self.self)
    }

    @IBOutlet var avatarImageView: UIImageView!
    @IBOutlet var userNameLabel: UILabel!
    @IBOutlet var contenLabel: UILabel!

    func config(replay: Replys.Reply) {
        avatarImageView.kf.setImage(
            with: URL(string: replay.member.avatar),
            options: [
                .processor(DownsamplingImageProcessor(size: CGSize(width: 80, height: 80))),
                .processor(RoundCornerImageProcessor(radius: .widthFraction(0.5))),
                .cacheSerializer(FormatIndicatedCacheSerializer.png),
            ]
        )
        userNameLabel.text = replay.member.uname
        if let attr = replay.createAttributedString(displayView: contenLabel) {
            contenLabel.attributedText = attr
        } else {
            contenLabel.text = replay.content.message
        }
    }
}
