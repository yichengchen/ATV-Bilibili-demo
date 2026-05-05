//
//  AVPlayerMetaUtils.swift
//  BilibiliLive
//
//  Created by yicheng on 2024/6/6.
//

import AVKit
import Kingfisher
import MediaPlayer

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

        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: title ?? "",
            MPMediaItemPropertyArtist: subTitle ?? "",
        ]

        if let pic = pic,
           let resource = try? await KingfisherManager.shared.retrieveImage(
               with: Kingfisher.KF.ImageResource(downloadURL: pic),
               options: [
                   .onlyLoadFirstFrame,
                   .processor(DownsamplingImageProcessor(size: CGSize(width: 640, height: 360))),
               ]
           ),
           let data = resource.image.pngData(),
           let item = createMetadataItem(for: .commonIdentifierArtwork, value: data)
        {
            metas.append(item)
            MainActor.callSafely {
                player.currentItem?.externalMetadata = metas
            }

            let artwork = MPMediaItemArtwork(boundsSize: resource.image.size) { _ in resource.image }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
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
