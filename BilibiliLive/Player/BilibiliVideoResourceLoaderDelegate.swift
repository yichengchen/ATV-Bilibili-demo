//
//  CustomPlaylistDelegate.swift
//  MPEGDASHAVPlayerDemo
//
//  Created by yicheng on 2022/08/20.
//  Copyright © 2022 yicheng. All rights reserved.
//

import AVFoundation
import Regex
import UIKit
import SwiftyJSON

class BilibiliVideoResourceLoaderDelegate: NSObject, AVAssetResourceLoaderDelegate {
    
    enum URLs {
        static let customScheme = "atv"
        static let customPrefix = customScheme + "://"
        static let play = customPrefix + "play"
        static let video = customPrefix + "video.m3u8"
        static let audio = customPrefix + "audio.m3u8"
    }

    private var audioPlaylist = ""
    private var videoPlaylist = ""
    private var masterPlaylist = ""
    
    private let badRequestErrorCode = 455

    func setBilibili(info:JSON) {
        let dash = info["data"]["dash"]
        let duration = dash["duration"].intValue
        
        let video = dash["video"][1]
        let videoBaseURL = video["base_url"].stringValue
        let videoBackupURL = video["backup_url"].arrayValue.map({$0.stringValue})
                
        let width = video["width"].intValue
        let height = video["height"].intValue
        let videocodecs = video["codecs"].stringValue
        let frameRate = video["frameRate"].stringValue
        let sar = video["sar"].stringValue
        let videoBandwidth = video["bandwidth"].stringValue
        
        let videoURL = videoBackupURL.first ?? videoBaseURL
        
        let audio = dash["audio"][0]
        let audioBaseURL = audio["base_url"].stringValue
        let audioBackupURL = audio["backup_url"].arrayValue.map({$0.stringValue})
        let audioURL = audioBackupURL.first ?? audioBaseURL
        
        let audioCodec = audio["codecs"].stringValue
        
        let audioBandwidth = audio["bandwidth"].stringValue
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
                        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
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
