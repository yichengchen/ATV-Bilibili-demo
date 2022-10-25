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
        static let video = customPrefix + "video.m3u8"
        static let backupVideo = customPrefix + "backupVideo.m3u8"
        static let audio = customPrefix + "audio.m3u8"
    }

    private var audioPlaylist = ""
    private var videoPlaylist = ""
    private var backupVideoPlaylist = ""
    private var masterPlaylist = ""

    private let badRequestErrorCode = 455

    func setBilibili(info: JSON) {
        let dash = info["data"]["dash"]
        let duration = dash["duration"].intValue

        if Settings.mediaQuality == .quality_hdr_dolby {
            let video = dash["video"][0]
            let videoBaseURL = video["base_url"].stringValue
            let videoBackupURL = video["backup_url"].arrayValue.map({ $0.stringValue })

            let width = video["width"].intValue
            let height = video["height"].intValue
            let videocodecs = video["codecs"].stringValue
            let frameRate = video["frameRate"].stringValue
            let sar = video["sar"].stringValue
            let videoBandwidth = video["bandwidth"].stringValue

            let videoURL = videoBackupURL.first ?? videoBaseURL

            let backupVideo = dash["video"][1]
            let backupVideoBaseURL = backupVideo["base_url"].stringValue
            let backupVideoBackupURL = backupVideo["backup_url"].arrayValue.map({ $0.stringValue })

            let backupWidth = backupVideo["width"].intValue
            let backupHeight = backupVideo["height"].intValue
            let backupVideocodecs = backupVideo["codecs"].stringValue
            let backupFrameRate = backupVideo["frameRate"].stringValue
            let backupSar = backupVideo["sar"].stringValue
            let backupVideoBandwidth = backupVideo["bandwidth"].stringValue

            let backupVideoURL = backupVideoBackupURL.first ?? backupVideoBaseURL

            masterPlaylist = """
            #EXTM3U
            #EXT-X-VERSION:6
            #EXT-X-MEDIA:TYPE=AUDIO,DEFAULT=YES,GROUP-ID="audio",NAME="Main",URI="\(URLs.audio)"
            #EXT-X-STREAM-INF:AUDIO="audio",CODECS="\(videocodecs)",RESOLUTION=\(width)x\(height),FRAME-RATE=\(frameRate),BANDWIDTH=\(videoBandwidth)
            \(URLs.video)
            #EXT-X-STREAM-INF:AUDIO="audio",CODECS="\(backupVideocodecs)",RESOLUTION=\(backupWidth)x\(backupHeight),FRAME-RATE=\(backupFrameRate),BANDWIDTH=\(backupVideoBandwidth)
            \(URLs.backupVideo)
            """

            videoPlaylist = """
            #EXTM3U
            #EXT-X-VERSION:6
            #EXT-X-TARGETDURATION:\(duration)
            #EXT-X-MEDIA-SEQUENCE:1
            #EXT-X-PLAYLIST-TYPE:EVENT
            #EXTINF:\(duration)
            \(videoURL)
            #EXT-X-MLB-VIDEO-INFO:codecs="\(videocodecs)",width="\(width)",height="\(height)",sar="\(sar)",frame-duration=1
            #EXT-X-MLB-INFO:max-bw=\(videoBandwidth),duration=\(duration)
            #EXT-X-ENDLIST
            """

            backupVideoPlaylist = """
            #EXTM3U
            #EXT-X-VERSION:6
            #EXT-X-TARGETDURATION:\(duration)
            #EXT-X-MEDIA-SEQUENCE:1
            #EXT-X-PLAYLIST-TYPE:EVENT
            #EXTINF:\(duration)
            \(backupVideoURL)
            #EXT-X-MLB-VIDEO-INFO:codecs="\(backupVideocodecs)",width="\(backupWidth)",height="\(backupHeight)",sar="\(backupSar)",frame-duration=1
            #EXT-X-MLB-INFO:max-bw=\(backupVideoBandwidth),duration=\(duration)
            #EXT-X-ENDLIST
            """

        } else {
            let video = dash["video"][1]
            let videoBaseURL = video["base_url"].stringValue
            let videoBackupURL = video["backup_url"].arrayValue.map({ $0.stringValue })

            let width = video["width"].intValue
            let height = video["height"].intValue
            let videocodecs = video["codecs"].stringValue
            let frameRate = video["frameRate"].stringValue
            let sar = video["sar"].stringValue
            let videoBandwidth = video["bandwidth"].stringValue

            let videoURL = videoBackupURL.first ?? videoBaseURL

            masterPlaylist = """
            #EXTM3U
            #EXT-X-VERSION:6
            #EXT-X-MEDIA:TYPE=AUDIO,DEFAULT=YES,GROUP-ID="audio",NAME="Main",URI="\(URLs.audio)"
            #EXT-X-STREAM-INF:AUDIO="audio",CODECS="\(videocodecs)",RESOLUTION=\(width)x\(height),FRAME-RATE=\(frameRate),BANDWIDTH=\(videoBandwidth)
            \(URLs.video)
            """

            videoPlaylist = """
            #EXTM3U
            #EXT-X-VERSION:6
            #EXT-X-TARGETDURATION:\(duration)
            #EXT-X-MEDIA-SEQUENCE:1
            #EXT-X-PLAYLIST-TYPE:EVENT
            #EXTINF:\(duration)
            \(videoURL)
            #EXT-X-MLB-VIDEO-INFO:codecs="\(videocodecs)",width="\(width)",height="\(height)",sar="\(sar)",frame-duration=1
            #EXT-X-MLB-INFO:max-bw=\(videoBandwidth),duration=\(duration)
            #EXT-X-ENDLIST
            """
        }

        var audioBaseURL = ""
        var audioBackupURL: [String]
        var audioURL = ""
        var audioCodec = ""
        var audioBandwidth = ""

        if Settings.losslessAudio == true {
            var audio: JSON = .null
            let dolby = dash["dolby"]
            if dolby != .null {
                audio = dolby["audio"][0]
            } else {
                let flac = dash["flac"]
                if flac != .null {
                    audio = flac["audio"]
                } else {
                    audio = dash["audio"][0]
                }
            }

            audioBaseURL = audio["base_url"].stringValue
            audioBackupURL = audio["backup_url"].arrayValue.map({ $0.stringValue })
            audioURL = audioBackupURL.first ?? audioBaseURL

            audioCodec = audio["codecs"].stringValue

            audioBandwidth = audio["bandwidth"].stringValue
        } else {
            let audio = dash["audio"][0]
            audioBaseURL = audio["base_url"].stringValue
            audioBackupURL = audio["backup_url"].arrayValue.map({ $0.stringValue })
            audioURL = audioBackupURL.first ?? audioBaseURL

            audioCodec = audio["codecs"].stringValue

            audioBandwidth = audio["bandwidth"].stringValue
        }

        audioPlaylist = """
        #EXTM3U
        #EXT-X-VERSION:6
        #EXT-X-TARGETDURATION:\(duration)
        #EXT-X-MEDIA-SEQUENCE:1
        #EXT-X-PLAYLIST-TYPE:EVENT
        #EXTINF:\(duration)
        \(audioURL)
        #EXT-X-MLB-AUDIO-INFO:codecs="\(audioCodec)"
        #EXT-X-MLB-INFO:max-bw=\(audioBandwidth),duration=\(duration)
        #EXT-X-ENDLIST
        """
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

        switch customUrl {
        case URLs.video:
            report(loadingRequest, content: videoPlaylist)
        case URLs.backupVideo:
            report(loadingRequest, content: backupVideoPlaylist)
        case URLs.audio:
            report(loadingRequest, content: audioPlaylist)
        case URLs.play:
            report(loadingRequest, content: masterPlaylist)
        default:
            break
        }
        print("handle loading", customUrl)
    }
}
