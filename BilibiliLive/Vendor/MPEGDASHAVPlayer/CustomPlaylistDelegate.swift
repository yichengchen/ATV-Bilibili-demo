//
//  CustomPlaylistDelegate.swift
//  MPEGDASHAVPlayerDemo
//
//  Created by Tomohiro Matsuzawa on 2019/11/28.
//  Copyright © 2019 Tomohiro Matsuzawa. All rights reserved.
//

import AVFoundation
import Regex
import UIKit

let customPlaylistScheme = "cplp"
let httpsScheme = "http"
let dashExt = "mpd"
let hlsExt = "m3u8"
private let badRequestErrorCode = 400

private struct MpdInfo {
    var key: [String]
    var item: [String]
}

private enum ParseError: Error {
    case invalidUrl
    case notFound(key: String)
    case invalidDuration
}

func toCustomUrl(_ url: String) -> String {
    return customPlaylistScheme + String(url.dropFirst(httpsScheme.count).dropLast(3)) + hlsExt
}

func toOriginalUrl(_ url: String) -> String {
    return httpsScheme + String(url.dropFirst(customPlaylistScheme.count).dropLast(4)) + dashExt
}

class CustomPlaylistDelegate: NSObject, AVAssetResourceLoaderDelegate {
    private var customPlaylists: [String: String] = .init()

    private func reportError(_ loadingRequest: AVAssetResourceLoadingRequest, withErrorCode error: Int) {
        loadingRequest.finishLoading(with: NSError(domain: NSURLErrorDomain, code: error, userInfo: nil))
    }

    func resourceLoader(_: AVAssetResourceLoader,
                        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        guard let scheme = loadingRequest.request.url?.scheme else {
            return false
        }

        if isCustomPlaylistSchemeValid(scheme) {
            DispatchQueue.main.async {
                self.handleCustomPlaylistRequest(loadingRequest)
            }
            return true
        }

        return false
    }
}

private extension CustomPlaylistDelegate {
    func isCustomPlaylistSchemeValid(_ scheme: String) -> Bool {
        return customPlaylistScheme == scheme
    }

    func extractMpdInfo(_ textToDec: String) -> MpdInfo {
        // find the pattern [xxx="yyy"], remember xxx and yyy
        let pattern = Regex(#"(\w+)=\"(.*?)\""#)
        var mpdInfo = MpdInfo(key: [], item: [])
        for match in pattern.allMatches(in: textToDec) {
            guard let key = match.captures[0], let item = match.captures[1] else {
                continue
            }
            mpdInfo.key.append(key)
            mpdInfo.item.append(item)
        }
        return mpdInfo
    }

    func tryGetItem(_ key: String, items: [String], keys: [String], index: Int = 0) -> String? {
        guard let idx = keys.dropFirst(index).firstIndex(of: key) else {
            return nil
        }
        return items[idx]
    }

    func getItem(_ key: String, items: [String], keys: [String], index: Int = 0) throws -> String {
        guard let item = tryGetItem(key, items: items, keys: keys, index: index) else {
            throw ParseError.notFound(key: key)
        }
        return item
    }

    func getDuration(_ rawDuration: String) throws -> Float {
        return Float(rawDuration) ?? 1
        let timePatternFull = Regex(#"(\d*)H(\d*)M(.*)S"#)
        let timePatternSec = Regex(#"(\d*)S"#)
        if let match = timePatternFull.firstMatch(in: rawDuration),
            let hour = match.captures[0],
            let minute = match.captures[1],
            let second = match.captures[2] {
            return (hour as NSString).floatValue * 3600 + (minute as NSString).floatValue * 60 + (second as NSString).floatValue
        } else if let match = timePatternSec.firstMatch(in: rawDuration),
            let second = match.captures[1] {
            return (second as NSString).floatValue
        } else {
            throw ParseError.invalidDuration
        }
    }

    func createMediaPlaylist(_ mpdInfo: MpdInfo, url: String) throws -> [String] {
        let header = "#EXTM3U\n" + "#EXT-X-VERSION:6\n"
        let tail = "#EXT-X-ENDLIST"
        var mediaPlaylists: [String] = []

        let key = mpdInfo.key
        let item = mpdInfo.item

        let videoKey = "video"
        let audioKey = "audio"
        guard let index = url.lastIndex(of: "/") else {
            throw ParseError.invalidUrl
        }
        let httpUrlPath = String(url[..<index]).replacingOccurrences(of: customPlaylistScheme, with: httpsScheme)
        var curIdx = key.firstIndex(of: "mimeType")
        var j = 0
        while let idx = curIdx {
            let segmentType = item[idx]

            let rawDuration = try getItem("duration", items: item, keys: key)

            // #EXT-X-MEDIA-SEQUENCE:
            let firstSequence: Int
            if let rawStartNumber = tryGetItem("startNumber", items: item, keys: key, index: idx), let startNumber = Int(rawStartNumber) {
                firstSequence = startNumber
            } else {
                firstSequence = 1 // by default, number starts from 1
            }
            let startSequence = "#EXT-X-MEDIA-SEQUENCE:\(firstSequence)\n"

            // #EXT-X-PLAYLIST-TYPE:EVENT
            var playlistType = ""
            if let typeIdx = key.firstIndex(of: "type") {
                switch item[typeIdx] {
                case "static":
                    playlistType = "#EXT-X-PLAYLIST-TYPE:EVENT\n" // VOD
                case "live":
                    playlistType = "#EXT-X-PLAYLIST-TYPE:EVENT\n"
                default:
                    break
                }
            }

            // #EXT-X-MAP:URI="tears_of_steel_1080p_1000k_h264_dash_track1_init.mp4"
            let path = httpUrlPath + "/"
//            let mapInit = try #"#EXT-X-MAP:URI=""# + path + getItem("initialization", items: item, keys: key, index: idx) + "\"\n"

            // #EXT-X-MLB-INFO:max-bw=999120,duration=4.000
            // totalDuration
            /* if let mediaPresentationDurationIdx = key.firstIndex(of: "mediaPresentationDuration") {
                 let rawtotalDuration = item[mediaPresentationDurationIdx]
             } */
            let totalDuration = try getDuration(rawDuration)

            let info = "#EXT-X-MLB-INFO:max-bw=\(try getItem("bandwidth", items: item, keys: key, index: idx)),duration=\(totalDuration)\n"

            let segmentsName = try getItem("media", items: item, keys: key, index: idx)
            var segmentDuration =
                (try getItem("duration", items: item, keys: key, index: idx) as NSString).floatValue /
                (try getItem("timescale", items: item, keys: key, index: idx) as NSString).floatValue
            let numSegment = Int(ceil(totalDuration / segmentDuration)) // how many segments of the representation
            var segmentUnit = ""

            var output: String?
            // #EXT-X-TARGETDURATION:
            var maxDuration = 1
            if segmentType.contains(videoKey) {
                for i in firstSequence ... numSegment {
                    if i == numSegment {
                        segmentDuration = totalDuration - segmentDuration * Float(numSegment - 1)
                    }
                    let duration = Int(round(segmentDuration))
                    if maxDuration < duration {
                        maxDuration = duration
                    }
                    // #EXTINF
                    let inf = "#EXTINF:\(segmentDuration)\n"
                    // tears_of_steel_1080p_1000k_h264_dash_track1_$Number$.m4s
                    let segment = httpUrlPath + "/" + segmentsName.replacingOccurrences(of: #"\$.*?\$"#, with: String(i), options: .regularExpression) + "\n"
                    segmentUnit += inf + segment
                }

                // #EXT-X-MLB-VIDEO-INFO:codecs="avc1.640028",width="1920",height="1080",sar="1:1",frame-duration=12288
                let video_info =
                    try "#EXT-X-MLB-VIDEO-INFO:" + #"codecs=""# + getItem("codecs", items: item, keys: key, index: idx)
                + #"","# + #"width=""# + getItem("width", items: item, keys: key, index: idx)
                + #"","# + #"height=""# + getItem("height", items: item, keys: key, index: idx)
                + #"","# + #"sar=""# + getItem("sar", items: item, keys: key, index: idx)
                + #"","# + "frame-duration=" + getItem("timescale", items: item, keys: key, index: idx) + "\n"

                let maxSegmentDuration = "#EXT-X-TARGETDURATION:\(maxDuration)\n"
                output = maxSegmentDuration + startSequence + playlistType + segmentUnit + video_info + info
            } else if segmentType.contains(audioKey) {
                for i in firstSequence ... numSegment {
                    if i == numSegment {
                        segmentDuration = totalDuration - segmentDuration * Float(numSegment - 1)
                    }
                    let duration = Int(round(segmentDuration))
                    if maxDuration < duration {
                        maxDuration = duration
                    }
                    // #EXTINF:2.000
                    let inf = "#EXTINF:\(segmentDuration)\n"
                    // tears_of_steel_1080p_1000k_h264_dash_track1_$Number$.m4s
                    let segment = httpUrlPath + "/" + segmentsName.replacingOccurrences(of: #"\$.*?\$"#, with: String(i), options: .regularExpression) + "\n"
                    segmentUnit += inf + segment
                }

                // #EXT-X-MLB-AUDIO-INFO:codecs="mp4a.40.2",audioSamplingRate="48000"
                let audio_info =
                    try "#EXT-X-MLB-AUDIO-INFO:" + #"codecs=""# + getItem("codecs", items: item, keys: key, index: idx)
                + #"","# + #"audioSamplingRate=""# + getItem("audioSamplingRate", items: item, keys: key, index: idx)
                    + "\"\n"

                // #EXT-X-MLB-AUDIO-CHANNEL-INFO:schemeIdUri="urn:mpeg:dash:23003:3:audio_channel_configuration:2011",value="2"
                let channel_info =
                    try #"#EXT-X-MLB-AUDIO-CHANNEL-INFO:schemeIdUri=""#
                + getItem("schemeIdUri", items: item, keys: key, index: idx)
                + #"","# + #"value=""# + getItem("value", items: item, keys: key, index: idx) + "\"\n"

                let maxSegmentDuration = "#EXT-X-TARGETDURATION:\(maxDuration)\n"
                output = maxSegmentDuration + startSequence + playlistType + segmentUnit + audio_info + channel_info + info
            }

            curIdx = key.dropFirst(idx + 1).firstIndex(of: "mimeType")
            if let output = output {
                mediaPlaylists.append(try saveAsCustomPlaylist(url, index: j, playlist: header + output + tail))
                j += 1
            }
        }
        return mediaPlaylists
    }

    func createMasterPlaylist(_ mpdInfo: MpdInfo, mediaPlaylists: [String]) throws -> String {
        let header = "#EXTM3U\n" + "#EXT-X-VERSION:6\n"
        var output = ""

        let key = mpdInfo.key
        let item = mpdInfo.item
        // segment type
        let videoKey = "video"
        let audioKey = "audio"
        var curIdx = key.firstIndex(of: "mimeType")
        var j = 0
        while let idx = curIdx {
            defer {
                curIdx = key.dropFirst(idx + 1).firstIndex(of: "mimeType")
            }
            let segmentType = item[idx]

            if segmentType.contains(videoKey) {
                // Trick Play is not supported yet
                guard tryGetItem("frameRate", items: item, keys: key, index: idx) != "1" else {
                    j += 1
                    continue
                }
                // video segments
                var videoMasterInfo = #"#EXT-X-STREAM-INF:AUDIO="audio","# // audio name be improved according to audio segments!
                videoMasterInfo += try #"CODECS=""# + getItem("codecs", items: item, keys: key, index: idx) + #"","#
                videoMasterInfo += try "RESOLUTION=" + getItem("width", items: item, keys: key, index: idx) + "x" + getItem("height", items: item, keys: key, index: idx) + ","
                if let frameRate = tryGetItem("frameRate", items: item, keys: key, index: idx) {
                    videoMasterInfo += "FRAME-RATE=" + frameRate + ","
                }
                videoMasterInfo += try "BANDWIDTH=" + getItem("bandwidth", items: item, keys: key, index: idx)

                // let mediaRep = try getItem("media", items: item, keys: key, index: idx) // may need improvement
                let videoMediaPlaylist = (mediaPlaylists[j] as NSString).lastPathComponent
                j += 1
                output += videoMasterInfo + "\n" + videoMediaPlaylist + "\n"
            } else if segmentType.contains(audioKey) {
                // audio segments
                // let mediaRep = try getItem("media", items: item, keys: key, index: idx)
                let audioMaster = #"#EXT-X-MEDIA:TYPE=AUDIO,DEFAULT=YES,GROUP-ID="audio",NAME="Main",URI=""# + (mediaPlaylists[j] as NSString).lastPathComponent + "\"\n"
                output = audioMaster + output
            }
        }
        return header + output
    }

    func saveAsCustomPlaylist(_ url: String, index: Int, playlist: String) throws -> String {
        guard let i = url.lastIndex(of: ".") else {
            throw ParseError.invalidUrl
        }
        let playlistUrl = String(url[..<i]) + "_" + String(index) + "." + hlsExt
        customPlaylists[playlistUrl] = playlist
        return playlistUrl
    }

    func handleCustomPlaylistRequest(_ loadingRequest: AVAssetResourceLoadingRequest) {
        guard let customUrl = loadingRequest.request.url?.absoluteString else {
            reportError(loadingRequest, withErrorCode: badRequestErrorCode)
            return
        }
        if let playlist = customPlaylists[customUrl] {
            guard let data = playlist.data(using: .utf8) else {
                reportError(loadingRequest, withErrorCode: badRequestErrorCode)
                return
            }
            loadingRequest.dataRequest?.respond(with: data)
            loadingRequest.finishLoading()
            return
        }
        guard let url = URL(string: toOriginalUrl(customUrl)) else {
            reportError(loadingRequest, withErrorCode: badRequestErrorCode)
            return
        }
        let request = URLRequest(url: url)
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        let session = URLSession(configuration: config)
        let task = session.dataTask(with: request, completionHandler: { data, _, error in
            guard error == nil, let data = data else {
                self.reportError(loadingRequest, withErrorCode: badRequestErrorCode)
                return
            }

            let mpdInfo = self.extractMpdInfo(String(decoding: data, as: UTF8.self))
            do {
                let masterPlaylist = try self.createMasterPlaylist(mpdInfo, mediaPlaylists: self.createMediaPlaylist(mpdInfo, url: customUrl))
                guard let data = masterPlaylist.data(using: .utf8) else {
                    self.reportError(loadingRequest, withErrorCode: badRequestErrorCode)
                    return
                }
                loadingRequest.dataRequest?.respond(with: data)
                loadingRequest.finishLoading()
            } catch let err {
                print(err)
                self.reportError(loadingRequest, withErrorCode: badRequestErrorCode)
            }
        })

        task.resume()

        return
    }
}
