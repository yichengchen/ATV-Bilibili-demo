//
//  BVideoPlayPlugin.swift
//  BilibiliLive
//
//  Created by yicheng on 2024/5/24.
//

import AVKit

class BVideoPlayPlugin: CommonPlayerPlugin {
    private weak var playerVC: AVPlayerViewController?
    private var playerDelegate: BilibiliVideoResourceLoaderDelegate?
    private let playData: PlayerDetailData

    init(detailData: PlayerDetailData) {
        playData = detailData
    }

    func playerDidLoad(playerVC: AVPlayerViewController) {
        self.playerVC = playerVC
        Task {
            try? await playmedia(urlInfo: playData.videoPlayURLInfo, playerInfo: playData.playerInfo)
        }
    }

    private func updatePlayerInfoView(aid: Int) async {
//        if data == nil {
//            data = try? await WebRequest.requestDetailVideo(aid: aid)
//        }
//        setPlayerInfo(title: data?.title, subTitle: data?.ownerName, desp: data?.View.desc, pic: data?.pic)
    }

    private func setupDanmuMask() {
        //            if Settings.danmuMask {
        //                if let mask = info?.dm_mask,
        //                   let video = playData.dash.video.first,
        //                   let fps = info?.dm_mask?.fps, fps > 0
        //                {
        //                    maskProvider = BMaskProvider(info: mask, videoSize: CGSize(width: video.width ?? 0, height: video.height ?? 0))
        //                } else if Settings.vnMask {
        //                    maskProvider = VMaskProvider()
        //                }
        //                setupMask()
        //            }
    }

    @MainActor
    private func playmedia(urlInfo: VideoPlayURLInfo, playerInfo: PlayerInfo?) async throws {
        let playURL = URL(string: BilibiliVideoResourceLoaderDelegate.URLs.play)!
        let headers: [String: String] = [
            "User-Agent": Keys.userAgent,
            "Referer": Keys.referer(for: playData.aid),
        ]
        let asset = AVURLAsset(url: playURL, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        playerDelegate = BilibiliVideoResourceLoaderDelegate()
        playerDelegate?.setBilibili(info: urlInfo, subtitles: playerInfo?.subtitle?.subtitles ?? [], aid: playData.aid)
        if Settings.contentMatchOnlyInHDR {
            if playerDelegate?.isHDR != true {
                playerVC?.appliesPreferredDisplayCriteriaAutomatically = false
            }
        }
        asset.resourceLoader.setDelegate(playerDelegate, queue: DispatchQueue(label: "loader"))
        let playable = try await asset.load(.isPlayable)
        if !playable {
            throw "加载资源失败"
        }
        await prepare(toPlay: asset)
    }

    @MainActor
    func prepare(toPlay asset: AVURLAsset) async {
        let playerItem = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: playerItem)
//        player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 1), queue: .main) { [weak self] time in
//            guard let self else { return }
        ////            if self.danMuView.isHidden { return }
//            let seconds = time.seconds
        ////            self.danmuProvider.playerTimeChange(time: seconds)
//
//            if let duration = self.data?.View.duration {
//                BiliBiliUpnpDMR.shared.sendProgress(duration: duration, current: Int(seconds))
//            }
//
//            if let clipInfos = self.clipInfos {
//                var matched = false
//                for clip in clipInfos {
//                    if seconds > clip.start, seconds < clip.end {
//                        let action = {
//                            clip.skipped = true
//                            self.player?.seek(to: CMTime(seconds: Double(clip.end), preferredTimescale: 1), toleranceBefore: .zero, toleranceAfter: .zero)
//                        }
//                        if !(clip.skipped ?? false), Settings.autoSkip {
//                            action()
//                            self.skipAction = nil
//                        } else if self.skipAction?.accessibilityLabel != clip.a11Tag {
//                            self.skipAction = UIAction(title: clip.customText) { _ in
//                                action()
//                            }
//                            self.skipAction?.accessibilityLabel = clip.a11Tag
//                        }
//
//                        self.contextualActions = [self.skipAction].compactMap { $0 }
//                        matched = true
//                        break
//                    }
//                }
//                if !matched {
//                    self.contextualActions = []
//                }
//            }
//        }

        if let defaultRate = playerVC?.player?.defaultRate,
           let speed = PlaySpeed.blDefaults.first(where: { $0.value == defaultRate })
        {
            playerVC?.player = player
            playerVC?.selectSpeed(AVPlaybackSpeed(rate: speed.value, localizedName: speed.name))
        } else {
            playerVC?.player = player
        }
    }
}
