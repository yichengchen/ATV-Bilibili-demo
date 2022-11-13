//
//  CustomPlaylistDelegate.swift
//  MPEGDASHAVPlayerDemo
//
//  Created by yicheng on 2022/08/20.
//  Copyright © 2022 yicheng. All rights reserved.
//

import Alamofire
import AVFoundation
import Swifter
import SwiftyJSON
import UIKit

class BilibiliVideoResourceLoaderDelegate: NSObject, AVAssetResourceLoaderDelegate {
    enum URLs {
        static let customScheme = "atv"
        static let customPrefix = customScheme + "://list/"
        static let play = customPrefix + "play"
        static let customSubtitlePrefix = customScheme + "://subtitle/"
        static let customVideoPrefix = customScheme + "://video/"
    }

    struct PlaybackInfo {
        let info: VideoPlayURLInfo.DashInfo.DashMediaInfo
        let url: String
        let duration: Int
    }

    private var audioPlaylist = ""
    private var videoPlaylist = ""
    private var backupVideoPlaylist = ""
    private var masterPlaylist = ""

    private let badRequestErrorCode = 455

    private var playlists = [String]()
    private var subtitles = [String: String]()
    private var videoInfo = [PlaybackInfo]()
    private var segmentInfoCache = [VideoPlayURLInfo.DashInfo.DashMediaInfo: SidxParseUtil.Sidx]()
    private var hasAudioInMasterListAdded = false
    private(set) var playInfo: VideoPlayURLInfo?
    private var hasSubtitle = false
    private var hasPreferSubtitleAdded = false
    private var httpServer = HttpServer()
    private var aid = 0

    deinit {
        httpServer.stop()
    }

    var infoDebugText: String {
        let videoCodec = playInfo?.dash.video.map({ $0.codecs }).prefix(5).joined(separator: ",") ?? "nil"
        let audioCodec = playInfo?.dash.audio.map({ $0.codecs }).prefix(5).joined(separator: ",") ?? "nil"
        return "video codecs: \(videoCodec), audio: \(audioCodec)"
    }

    let videoCodecBlackList = ["avc1.640034", "hev1.2.4.L153.90"] // high 5.2 is not supported

    private func reset() {
        playlists.removeAll()
        masterPlaylist = """
        #EXTM3U
        #EXT-X-VERSION:6
        #EXT-X-INDEPENDENT-SEGMENTS


        """
    }

    private func addVideoPlayBackInfo(info: VideoPlayURLInfo.DashInfo.DashMediaInfo, url: String, duration: Int) {
        guard !videoCodecBlackList.contains(info.codecs) else { return }
        let subtitlePlaceHolder = hasSubtitle ? ",SUBTITLES=\"subs\"" : ""
        let videoRange = info.id == MediaQualityEnum.quality_hdr_dolby.qn ? "PQ" : "SDR"
        let content = """
        #EXT-X-STREAM-INF:AUDIO="audio"\(subtitlePlaceHolder),CODECS="\(info.codecs)",RESOLUTION=\(info.width)x\(info.height),FRAME-RATE=\(info.frame_rate),BANDWIDTH=\(info.bandwidth),VIDEO-RANGE=\(videoRange)
        \(URLs.customVideoPrefix)\(videoInfo.count)?codec=\(info.codecs)&rate=\(info.frame_rate)&width=\(info.width)&host=\(URL(string: url)?.host ?? "none")&range=\(info.id)

        """
        masterPlaylist.append(content)
        videoInfo.append(PlaybackInfo(info: info, url: url, duration: duration))
    }

    private func getVideoPlayList(info: PlaybackInfo) async -> String {
        var segment = segmentInfoCache[info.info]
        if segment == nil {
            let range = info.info.segment_base.index_range
            if let res = try? await AF.request(info.url,
                                               headers: ["Range": "bytes=\(range)",
                                                         "Referer": "https://www.bilibili.com/video/av\(aid)"])
                .serializingData().result.get()
            {
                segment = SidxParseUtil.processIndexData(data: res)
            }
        } else {
            print("cache hit")
        }
        let inits = info.info.segment_base.initialization.components(separatedBy: "-")
        guard let moovIdxStr = inits.last,
              let moovIdx = Int(moovIdxStr),
              let moovOffset = inits.first,
              let offsetStr = info.info.segment_base.index_range.components(separatedBy: "-").last,
              var offset = Int(offsetStr),
              let segment = segment
        else {
            return """
            #EXTM3U
            #EXT-X-VERSION:7
            #EXT-X-TARGETDURATION:\(info.duration)
            #EXT-X-MEDIA-SEQUENCE:1
            #EXT-X-INDEPENDENT-SEGMENTS
            #EXT-X-PLAYLIST-TYPE:VOD
            #EXTINF:\(info.duration)
            \(info.url)
            #EXT-X-ENDLIST
            """
        }

        var playList = """
        #EXTM3U
        #EXT-X-VERSION:7
        #EXT-X-TARGETDURATION:\(info.duration)
        #EXT-X-MEDIA-SEQUENCE:1
        #EXT-X-INDEPENDENT-SEGMENTS
        #EXT-X-PLAYLIST-TYPE:VOD
        #EXT-X-MAP:URI="\(info.url)",BYTERANGE="\(moovIdx)@\(moovOffset)"

        """

        for segInfo in segment.segments {
            let segStr = """
            #EXTINF:\(Double(segInfo.duration) / Double(segment.timescale)),
            #EXT-X-BYTERANGE:\(segInfo.size)@\(offset)
            \(info.url)

            """
            playList.append(segStr)
            offset += (segInfo.size)
        }

        playList.append("\n#EXT-X-ENDLIST")

        return playList
    }

    private func addVideoPlayBackInfo(codec: String, width: Int, height: Int, frameRate: String, bandwidth: Int, duration: Int, url: String, sar: String, quality: Int) {
        guard !videoCodecBlackList.contains(codec) else { return }
        let subtitlePlaceHolder = hasSubtitle ? ",SUBTITLES=\"subs\"" : ""
        let videoRange = quality == MediaQualityEnum.quality_hdr_dolby.qn ? "PQ" : "SDR"
        let content = """
        #EXT-X-STREAM-INF:AUDIO="audio"\(subtitlePlaceHolder),CODECS="\(codec)",RESOLUTION=\(width)x\(height),FRAME-RATE=\(frameRate),BANDWIDTH=\(bandwidth),VIDEO-RANGE=\(videoRange)
        \(URLs.customPrefix)\(playlists.count)?codec=\(codec)&rate=\(frameRate)&width=\(width)&host=\(URL(string: url)?.host ?? "none")&range=\(quality)

        """
        masterPlaylist.append(content)

        let playList = """
        #EXTM3U
        #EXT-X-VERSION:7
        #EXT-X-TARGETDURATION:\(duration)
        #EXT-X-MEDIA-SEQUENCE:1
        #EXT-X-INDEPENDENT-SEGMENTS
        #EXT-X-PLAYLIST-TYPE:VOD
        #EXTINF:\(duration)
        \(url)
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
        #EXT-X-INDEPENDENT-SEGMENTS
        #EXT-X-MEDIA-SEQUENCE:1
        #EXT-X-PLAYLIST-TYPE:VOD
        #EXTINF:\(duration)
        \(url)
        #EXT-X-ENDLIST
        """
        playlists.append(playList)
    }

    private func addSubtitleData(lang: String, name: String, duration: Int, url: String) {
        var lang = lang
        var canBeDefault = !hasPreferSubtitleAdded
        if lang.hasPrefix("ai-") {
            lang = String(lang.dropFirst(3))
            canBeDefault = false
        }
        if canBeDefault {
            hasPreferSubtitleAdded = true
        }
        let defaultStr = canBeDefault ? "YES" : "NO"

        let master = """
        #EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",LANGUAGE="\(lang)",NAME="\(name)",AUTOSELECT=\(defaultStr),DEFAULT=\(defaultStr),URI="\(URLs.customPrefix)\(playlists.count)"

        """
        masterPlaylist.append(master)

        let playList = """
        #EXTM3U
        #EXT-X-TARGETDURATION:\(duration)
        #EXT-X-VERSION:3
        #EXT-X-MEDIA-SEQUENCE:0
        #EXT-X-PLAYLIST-TYPE:VOD
        #EXTINF:\(duration),

        \(URLs.customSubtitlePrefix)\(url.addingPercentEncoding(withAllowedCharacters: .afURLQueryAllowed) ?? url)
        #EXT-X-ENDLIST

        """
        playlists.append(playList)
    }

    func setBilibili(info: VideoPlayURLInfo, subtitles: [SubtitleData], aid: Int) {
        playInfo = info
        self.aid = aid
        reset()
        hasSubtitle = subtitles.count > 0
        var videos = info.dash.video
        if Settings.preferHevc {
            if videos.contains(where: { $0.isHevc }) {
                videos.removeAll(where: { !$0.isHevc })
            }
        }

        for video in videos {
            for url in video.playableURLs {
                addVideoPlayBackInfo(info: video, url: url, duration: info.dash.duration)
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

        if hasSubtitle {
            try? httpServer.start(0)
            bindHttpServer()
        }
        for subtitle in subtitles {
            addSubtitleData(lang: subtitle.lan, name: subtitle.lan_doc, duration: info.dash.duration, url: subtitle.url.absoluteString)
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
        guard let customUrl = loadingRequest.request.url else {
            reportError(loadingRequest, withErrorCode: badRequestErrorCode)
            return
        }
        let urlStr = customUrl.absoluteString
        if urlStr == URLs.play {
            report(loadingRequest, content: masterPlaylist)
            return
        }

        if urlStr.hasPrefix(URLs.customPrefix), let index = Int(customUrl.lastPathComponent) {
            let playlist = playlists[index]
            report(loadingRequest, content: playlist)
            return
        }
        if urlStr.hasPrefix(URLs.customVideoPrefix), let index = Int(customUrl.lastPathComponent) {
            let info = videoInfo[index]
            Task {
                report(loadingRequest, content: await getVideoPlayList(info: info))
            }
        }
        if urlStr.hasPrefix(URLs.customSubtitlePrefix) {
            let url = String(urlStr.dropFirst(URLs.customSubtitlePrefix.count))
            let req = url.removingPercentEncoding ?? url
            Task {
                do {
                    if subtitles[req] == nil {
                        let content = try await WebRequest.requestSubtitle(url: URL(string: req)!)
                        let vtt = BVideoUrlUtils.convertToVTT(subtitle: content)
                        subtitles[req] = vtt
                    }
                    let port = try self.httpServer.port()
                    let url = "http://127.0.0.1:\(port)/subtitle?u=" + url
                    let redirectRequest = URLRequest(url: URL(string: url)!)
                    let redirectResponse = HTTPURLResponse(url: URL(string: url)!, statusCode: 302, httpVersion: nil, headerFields: nil)

                    loadingRequest.redirect = redirectRequest
                    loadingRequest.response = redirectResponse
                    loadingRequest.finishLoading()
                    return
                } catch let err {
                    loadingRequest.finishLoading(with: err)
                }
            }
            return
        }
        print("handle loading", customUrl)
    }

    func bindHttpServer() {
        httpServer["/subtitle"] = { [weak self] req in
            if let url = req.queryParams.first(where: { $0.0 == "u" })?.1 {
                let req = url.removingPercentEncoding ?? url
                if let content = self?.subtitles[req] {
                    return HttpResponse.ok(.text(content))
                }
            }
            return HttpResponse.notFound
        }
    }
}

enum BVideoUrlUtils {
    static func sortUrls(base: String, backup: [String]?) -> [String] {
        var urls = [base]
        if let backup {
            urls.append(contentsOf: backup)
        }
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

    static func convertVTTFormate(_ time: CGFloat) -> String {
        let seconds = Int(time)
        let hour = seconds / 3600
        let min = (seconds % 3600) / 60
        let second = CGFloat((seconds % 3600) % 60) + time - CGFloat(Int(time))
        return String(format: "%02d:%02d:%06.3f", hour, min, second)
    }

    static func convertToVTT(subtitle: [SubtitleContent]) -> String {
        var vtt = "WEBVTT\n\n"
        for model in subtitle {
            let from = convertVTTFormate(model.from)
            let to = convertVTTFormate(model.to)
            // hours:minutes:seconds.millisecond
            vtt.append("\(from) --> \(to)\n\(model.content)\n\n")
        }
        return vtt
    }
}

extension VideoPlayURLInfo.DashInfo.DashMediaInfo {
    var playableURLs: [String] {
        BVideoUrlUtils.sortUrls(base: base_url, backup: backup_url)
    }

    var isHevc: Bool {
        return codecs.starts(with: "hev") || codecs.starts(with: "hvc") || codecs.starts(with: "dvh1")
    }
}
