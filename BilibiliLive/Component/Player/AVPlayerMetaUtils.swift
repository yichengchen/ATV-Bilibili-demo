//
//  AVPlayerMetaUtils.swift
//  BilibiliLive
//
//  Created by yicheng on 2024/6/6.
//

import AVKit
import Kingfisher

enum AVPlayerMetaUtils {
    static func setPlayerInfo(title: String?, subTitle: String?, desp: String?, pic: URL?, player: AVPlayer) async {
        let desp = desp?.components(separatedBy: "\n").joined(separator: " ")
        let mapping: [AVMetadataIdentifier: Any?] = [
            .commonIdentifierTitle: title,
            .iTunesMetadataTrackSubTitle: subTitle,
            .commonIdentifierDescription: desp,
        ]
        var metas = mapping.compactMap { createMetadataItem(for: $0, value: $1) }

        MainActor.callSafely {
            player.currentItem?.externalMetadata = metas
        }

        if let pic = pic,
           let resource = try? await KingfisherManager.shared.retrieveImage(with: Kingfisher.ImageResource(downloadURL: pic)),
           let data = resource.image.pngData(),
           let item = createMetadataItem(for: .commonIdentifierArtwork, value: data)
        {
            metas.append(item)
            MainActor.callSafely {
                player.currentItem?.externalMetadata = metas
            }
        }
    }

    static func createMetadataItem(for identifier: AVMetadataIdentifier, value: Any?) -> AVMetadataItem? {
        if value == nil { return nil }
        let item = AVMutableMetadataItem()
        item.identifier = identifier
        item.value = value as? NSCopying & NSObjectProtocol
        // Specify "und" to indicate an undefined language.
        item.extendedLanguageTag = "und"
        return item.copy() as? AVMetadataItem
    }
}
