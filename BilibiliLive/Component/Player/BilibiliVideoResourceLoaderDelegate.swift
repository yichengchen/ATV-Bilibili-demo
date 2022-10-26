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
            addVideoPlayBackInfo(codec: video.codecs, width: video.width, height: video.height, frameRate: video.frame_rate, bandwidth: video.bandwidth, duration: info.dash.duration, url: video.base_url, sar: video.sar)
        }

        if Settings.losslessAudio {
            if let audios = info.dash.dolby?.audio {
                for audio in audios {
                    addAudioPlayBackInfo(codec: audio.codecs, bandwidth: audio.bandwidth, duration: info.dash.duration, url: audio.base_url)
                }
            } else if let audio = info.dash.flac?.audio {
                addAudioPlayBackInfo(codec: audio.codecs, bandwidth: audio.bandwidth, duration: info.dash.duration, url: audio.base_url)
            }
        }

        for audio in info.dash.audio {
            addAudioPlayBackInfo(codec: audio.codecs, bandwidth: audio.bandwidth, duration: info.dash.duration, url: audio.base_url)
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
