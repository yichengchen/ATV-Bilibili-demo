//
//  CustomPlaylistDelegate.swift
//  MPEGDASHAVPlayerDemo
//
//  Created by yicheng on 2022/08/20.
//  Copyright © 2022 yicheng. All rights reserved.
//

import AVFoundation
import SwiftyJSON
import UIKit

class BilibiliVideoResourceLoaderDelegate: NSObject, AVAssetResourceLoaderDelegate {
    enum URLs {
        static let customScheme = "atv"
        static let customPrefix = customScheme + "://"
        static let play = customPrefix + "play"
    }

    private var audioPlaylist = ""
    private var videoPlaylist = ""
    private var backupVideoPlaylist = ""
    private var masterPlaylist = ""

    private let badRequestErrorCode = 455

    private var playlists = [String]()
    private var hasAudioInMasterListAdded = false

    let videoCodecBlackList = ["avc1.640034"] // high 5.2 is not supported

    private func reset() {
        playlists.removeAll()
        masterPlaylist = """
        #EXTM3U
        #EXT-X-VERSION:6

        """
    }

    private func addVideoPlayBackInfo(codec: String, width: Int, height: Int, frameRate: String, bandwidth: Int, duration: Int, url: String, sar: String) {
        guard !videoCodecBlackList.contains(codec) else { return }
        let content = """
        #EXT-X-STREAM-INF:AUDIO="audio",CODECS="\(codec)",RESOLUTION=\(width)x\(height),FRAME-RATE=\(frameRate),BANDWIDTH=\(bandwidth)
        \(URLs.customPrefix)\(playlists.count)

        """
        masterPlaylist.append(content)

        let playList = """
        #EXTM3U
        #EXT-X-VERSION:6
        #EXT-X-TARGETDURATION:\(duration)
        #EXT-X-MEDIA-SEQUENCE:1
        #EXT-X-PLAYLIST-TYPE:EVENT
        #EXTINF:\(duration)
        \(url)
        #EXT-X-MLB-VIDEO-INFO:codecs="\(codec)",width="\(width)",height="\(height)",sar="\(sar)",frame-duration=1
        #EXT-X-MLB-INFO:max-bw=\(bandwidth),duration=\(duration)
        #EXT-X-ENDLIST
        """
        playlists.append(playList)
    }

    private func addAudioPlayBackInfo(codec: String, bandwidth: Int, duration: Int, url: String) {
        let defaultStr = !hasAudioInMasterListAdded ? "YES" : "NO"
        hasAudioInMasterListAdded = true
        let content = """
        #EXT-X-MEDIA:TYPE=AUDIO,DEFAULT=\(defaultStr),GROUP-ID="audio",NAME="Main",URI="\(URLs.customPrefix)\(playlists.count)"

        """
        masterPlaylist.append(content)

        let playList = """
        #EXTM3U
        #EXT-X-VERSION:6
        #EXT-X-TARGETDURATION:\(duration)
        #EXT-X-MEDIA-SEQUENCE:1
        #EXT-X-PLAYLIST-TYPE:EVENT
        #EXTINF:\(duration)
        \(url)
        #EXT-X-MLB-AUDIO-INFO:codecs="\(codec)"
        #EXT-X-MLB-INFO:max-bw=\(bandwidth),duration=\(duration)
        #EXT-X-ENDLIST
        """
        playlists.append(playList)
    }

    func setBilibili(info: VideoPlayURLInfo) {
        reset()
        for video in info.dash.video {
            for url in video.playableURLs {
                addVideoPlayBackInfo(codec: video.codecs, width: video.width, height: video.height, frameRate: video.frame_rate, bandwidth: video.bandwidth, duration: info.dash.duration, url: url, sar: video.sar)
            }
        }

        if Settings.losslessAudio {
            if let audios = info.dash.dolby?.audio {
                for audio in audios {
                    for url in BVideoUrlUtils.sortUrls(base: audio.base_url, backup: audio.backup_url) {
                        addAudioPlayBackInfo(codec: audio.codecs, bandwidth: audio.bandwidth, duration: info.dash.duration, url: url)
                    }
                }
            } else if let audio = info.dash.flac?.audio {
                for url in audio.playableURLs {
                    addAudioPlayBackInfo(codec: audio.codecs, bandwidth: audio.bandwidth, duration: info.dash.duration, url: url)
                }
            }
        }

        for audio in info.dash.audio {
            for url in audio.playableURLs {
                addAudioPlayBackInfo(codec: audio.codecs, bandwidth: audio.bandwidth, duration: info.dash.duration, url: url)
            }
        }
    }

    private func reportError(_ loadingRequest: AVAssetResourceLoadingRequest, withErrorCode error: Int) {
        loadingRequest.finishLoading(with: NSError(domain: NSURLErrorDomain, code: error, userInfo: nil))
    }

    private func report(_ loadingRequest: AVAssetResourceLoadingRequest, content: String) {
        if let data = content.data(using: .utf8) {
            loadingRequest.dataRequest?.respond(with: data)
            loadingRequest.finishLoading()
        } else {
            reportError(loadingRequest, withErrorCode: badRequestErrorCode)
        }
    }

    func resourceLoader(_: AVAssetResourceLoader,
                        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool
    {
        guard let scheme = loadingRequest.request.url?.scheme, scheme == URLs.customScheme else {
            return false
        }

        DispatchQueue.main.async {
            self.handleCustomPlaylistRequest(loadingRequest)
        }
        return true
    }
}

private extension BilibiliVideoResourceLoaderDelegate {
    func handleCustomPlaylistRequest(_ loadingRequest: AVAssetResourceLoadingRequest) {
        guard let customUrl = loadingRequest.request.url?.absoluteString else {
            reportError(loadingRequest, withErrorCode: badRequestErrorCode)
            return
        }

        if customUrl == URLs.play {
            report(loadingRequest, content: masterPlaylist)
            return
        }
        if let index = Int(customUrl.dropFirst(URLs.customPrefix.count)) {
            let playlist = playlists[index]
            report(loadingRequest, content: playlist)
            return
        }
        print("handle loading", customUrl)
    }
}

enum BVideoUrlUtils {
    static func sortUrls(base: String, backup: [String]) -> [String] {
        var urls = [base]
        urls.append(contentsOf: backup)
        return
            urls.sorted { lhs, rhs in
                let lhsIsPCDN = lhs.contains("szbdyd.com") || lhs.contains("mcdn.bilivideo.cn")
                let rhsIsPCDN = rhs.contains("szbdyd.com") || rhs.contains("mcdn.bilivideo.cn")
                switch (lhsIsPCDN, rhsIsPCDN) {
                case (true, false): return false
                case (false, true): return true
                case (true, true): fallthrough
                case (false, false): return lhs > rhs
                }
            }
    }
}

extension VideoPlayURLInfo.DashInfo.DashMediaInfo {
    var playableURLs: [String] {
        BVideoUrlUtils.sortUrls(base: base_url, backup: backup_url)
    }
}
