//
//  BVideoInfoPlugin.swift
//  BilibiliLive
//
//  Created by yicheng on 2024/5/25.
//

import AVKit
import Kingfisher

class BVideoInfoPlugin: NSObject, CommonPlayerPlugin {
    let title: String?
    let subTitle: String?
    let desp: String?
    let pic: URL?
    let viewPoints: [PlayerInfo.ViewPoint]?

    init(title: String?, subTitle: String?, desp: String?, pic: URL?, viewPoints: [PlayerInfo.ViewPoint]?) {
        self.title = title
        self.subTitle = subTitle
        self.desp = desp
        self.pic = pic
        self.viewPoints = viewPoints
    }

    func playerWillStart(player: AVPlayer) {
        Task {
            async let info: () = AVPlayerMetaUtils.setPlayerInfo(title: title, subTitle: subTitle, desp: desp, pic: pic, player: player)
            if let viewPoints {
                async let vp: () = updatePlayerCharpter(viewPoints: viewPoints, player: player)
                await vp
            }
            await info
        }
    }

    private func updatePlayerCharpter(viewPoints: [PlayerInfo.ViewPoint], player: AVPlayer) async {
        _ = await withTaskGroup(of: Void.self) { group in
            for viewPoint in viewPoints {
                group.addTask {
                    if let pic = viewPoint.imgUrl?.addSchemeIfNeed(),
                       let result = try? await KingfisherManager.shared.retrieveImage(with: Kingfisher.ImageResource(downloadURL: pic)),
                       let data = result.image.pngData()
                    {
                        viewPoint.imageData = data
                    }
                }
            }
            return group
        }

        let metas = viewPoints.compactMap { convertTimedMetadataGroup(viewPoint: $0) }

        MainActor.callSafely {
            player.currentItem?.navigationMarkerGroups = [AVNavigationMarkersGroup(title: nil, timedNavigationMarkers: metas)]
        }
    }

    private func convertTimedMetadataGroup(viewPoint: PlayerInfo.ViewPoint) -> AVTimedMetadataGroup {
        let mapping: [AVMetadataIdentifier: Any?] = [
            .commonIdentifierTitle: viewPoint.content,
        ]
        var metadatas = mapping.compactMap { AVPlayerMetaUtils.createMetadataItem(for: $0, value: $1) }
        let timescale: Int32 = 600
        let cmStartTime = CMTimeMakeWithSeconds(viewPoint.from, preferredTimescale: timescale)
        let cmEndTime = CMTimeMakeWithSeconds(viewPoint.to, preferredTimescale: timescale)
        let timeRange = CMTimeRangeFromTimeToTime(start: cmStartTime, end: cmEndTime)
        if let imageData = viewPoint.imageData,
           let item = AVPlayerMetaUtils.createMetadataItem(for: .commonIdentifierArtwork, value: imageData)
        {
            metadatas.append(item)
        }

        return AVTimedMetadataGroup(items: metadatas, timeRange: timeRange)
    }
}

extension KingfisherManager {
    func retrieveImage(with resource: Resource,
                       options: KingfisherOptionsInfo? = nil) async throws -> RetrieveImageResult
    {
        try await withCheckedThrowingContinuation { conf in
            retrieveImage(with: resource, options: options) { result in
                switch result {
                case let .success(result):
                    conf.resume(returning: result)
                case let .failure(err):
                    conf.resume(throwing: err)
                }
            }
        }
    }
}
