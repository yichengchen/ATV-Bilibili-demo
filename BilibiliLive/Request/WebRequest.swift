//
//  WebRequest.swift
//  BilibiliLive
//
//  Created by yicheng on 2021/4/29.
//

import Alamofire
import Foundation
import SwiftyJSON

enum RequestError: Error {
    case networkFail
    case statusFail(code: Int, message: String)
    case decodeFail(message: String)
}

enum WebRequest {
    enum EndPoint {
        static let related = "http://api.bilibili.com/x/web-interface/archive/related"
        static let logout = "http://passport.bilibili.com/login/exit/v2"
        static let info = "http://api.bilibili.com/x/web-interface/view"
        static let fav = "http://api.bilibili.com/x/v3/fav/resource/list"
        static let favList = "http://api.bilibili.com/x/v3/fav/folder/created/list-all"
        static let reportHistory = "https://api.bilibili.com/x/v2/history/report"
        static let upSpace = "http://api.bilibili.com/x/space/arc/search"
        static let like = "http://api.bilibili.com/x/web-interface/archive/like"
        static let likeStatus = "http://api.bilibili.com/x/web-interface/archive/has/like"
        static let coin = "http://api.bilibili.com/x/web-interface/coin/add"
        static let playerInfo = "https://api.bilibili.com/x/player/v2"
        static let playUrl = "https://api.bilibili.com/x/player/playurl"
    }

    static func requestData(method: HTTPMethod = .get,
                            url: URLConvertible,
                            parameters: Parameters = [:],
                            headers: [String: String]? = nil,
                            complete: ((Result<Data, RequestError>) -> Void)? = nil)
    {
        var parameters = parameters
        if method != .get {
            parameters["biliCSRF"] = CookieHandler.shared.csrf()
            parameters["csrf"] = CookieHandler.shared.csrf()
        }
        AF.request(url,
                   method: method,
                   parameters: parameters,
                   encoding: URLEncoding.default,
                   // headers: [.userAgent("ATVBilbili/1.0")],
                   interceptor: nil)
            .responseData { response in
                switch response.result {
                case let .success(data):
                    complete?(.success(data))
                case let .failure(err):
                    print(err)
                    complete?(.failure(.networkFail))
                }
            }
    }

    static func requestJSON(method: HTTPMethod = .get,
                            url: URLConvertible,
                            parameters: Parameters = [:],
                            headers: [String: String]? = nil,
                            dataObj: String = "data",
                            complete: ((Result<JSON, RequestError>) -> Void)? = nil)
    {
        requestData(method: method, url: url, parameters: parameters, headers: headers) { response in
            switch response {
            case let .success(data):
                let json = JSON(data)
                let errorCode = json["code"].intValue
                if errorCode != 0 {
                    let message = json["message"].stringValue
                    print(errorCode, message)
                    complete?(.failure(.statusFail(code: errorCode, message: message)))
                    return
                }
                let dataj = json[dataObj]
                print("\(url) response: \(dataj)")
                complete?(.success(dataj))
            case let .failure(err):
                complete?(.failure(err))
            }
        }
    }

    static func request<T: Decodable>(method: HTTPMethod = .get,
                                      url: URLConvertible,
                                      parameters: Parameters = [:],
                                      headers: [String: String]? = nil,
                                      decoder: JSONDecoder? = nil,
                                      dataObj: String = "data",
                                      complete: ((Result<T, RequestError>) -> Void)?)
    {
        requestJSON(method: method, url: url, parameters: parameters, headers: headers, dataObj: dataObj) { response in
            switch response {
            case let .success(data):
                do {
                    let data = try data.rawData()
                    let object = try (decoder ?? JSONDecoder()).decode(T.self, from: data)
                    complete?(.success(object))
                } catch let err {
                    print("decode fail:", err)
                    complete?(.failure(.decodeFail(message: err.localizedDescription + String(describing: err))))
                }
            case let .failure(err):
                complete?(.failure(err))
            }
        }
    }

    static func requestJSON(method: HTTPMethod = .get,
                            url: URLConvertible,
                            parameters: Parameters = [:],
                            headers: [String: String]? = nil) async throws -> JSON
    {
        return try await withCheckedThrowingContinuation { configure in
            requestJSON(method: method, url: url, parameters: parameters, headers: headers) { resp in
                configure.resume(with: resp)
            }
        }
    }

    static func request<T: Decodable>(method: HTTPMethod = .get,
                                      url: URLConvertible,
                                      parameters: Parameters = [:],
                                      headers: [String: String]? = nil,
                                      decoder: JSONDecoder? = nil) async throws -> T
    {
        return try await withCheckedThrowingContinuation { configure in
            request(method: method, url: url, parameters: parameters, headers: headers, decoder: decoder) {
                (res: Result<T, RequestError>) in
                switch res {
                case let .success(content):
                    configure.resume(returning: content)
                case let .failure(err):
                    configure.resume(throwing: err)
                }
            }
        }
    }
}

// MARK: - Video

extension WebRequest {
    static func requestBangumiInfo(epid: Int, complete: ((BangumiInfo.Episode) -> Void)?) {
        request(url: "http://api.bilibili.com/pgc/view/web/season", parameters: ["ep_id": epid], dataObj: "result") {
            (result: Result<BangumiInfo, RequestError>) in
            if let info = try? result.get() {
                for epi in info.episodes {
                    if epi.id == epid {
                        complete?(epi)
                        break
                    }
                }
            }
        }
    }

    static func requestHistory(complete: (([HistoryData]) -> Void)?) {
        request(url: "http://api.bilibili.com/x/v2/history") {
            (result: Result<[HistoryData], RequestError>) in
            if let data = try? result.get() {
                complete?(data)
            }
        }
    }

    static func requestPlayerInfo(aid: Int, cid: Int) async throws -> PlayerInfo {
        try await request(url: EndPoint.playerInfo, parameters: ["aid": aid, "cid": cid])
    }

    static func requestRelatedVideo(aid: Int, complete: (([VideoDetail.Info]) -> Void)? = nil) {
        request(method: .get, url: EndPoint.related, parameters: ["aid": aid]) {
            (result: Result<[VideoDetail.Info], RequestError>) in
            if let details = try? result.get() {
                complete?(details)
            }
        }
    }

    static func requestDetailVideo(aid: Int) async throws -> VideoDetail {
        try await request(url: "http://api.bilibili.com/x/web-interface/view/detail", parameters: ["aid": aid])
    }

    static func requestFavVideosList() async throws -> [FavListData] {
        guard let mid = ApiRequest.getToken()?.mid else { return [] }
        struct Resp: Codable {
            let list: [FavListData]
        }
        let res: Resp = try await request(method: .get, url: EndPoint.favList, parameters: ["up_mid": mid])
        return res.list
    }

    static func requestFavVideos(mid: String) async throws -> [FavData] {
        struct Resp: Codable {
            let medias: [FavData]?
        }
        let res: Resp = try await request(method: .get, url: EndPoint.fav, parameters: ["media_id": mid, "ps": "20"])
        return res.medias ?? []
    }

    static func reportWatchHistory(aid: Int, cid: Int, currentTime: Int) {
        requestJSON(method: .post,
                    url: EndPoint.reportHistory,
                    parameters: ["aid": aid, "cid": cid, "progress": currentTime],
                    complete: nil)
    }

    static func requestUpSpaceVideo(mid: Int, page: Int, pageSize: Int = 50) async throws -> [UpSpaceReq.List.VListData] {
        let resp: UpSpaceReq = try await request(url: EndPoint.upSpace, parameters: ["mid": mid, "pn": page, "ps": pageSize])
        return resp.list.vlist
    }

    static func requestLike(aid: Int, like: Bool) async -> Bool {
        do {
            _ = try await requestJSON(method: .post, url: EndPoint.like, parameters: ["aid": aid, "like": like ? "1" : "2"])
            return true
        } catch {
            return false
        }
    }

    static func requestLikeStatus(aid: Int, complete: ((Bool) -> Void)?) {
        requestJSON(url: EndPoint.likeStatus, parameters: ["aid": aid]) {
            response in
            switch response {
            case let .success(data):
                complete?(data.intValue == 1)
            case .failure:
                complete?(false)
            }
        }
    }

    static func requestCoin(aid: Int, num: Int) {
        requestJSON(method: .post, url: EndPoint.coin, parameters: ["aid": aid, "multiply": num, "select_like": 1])
    }

    static func requestCoinStatus(aid: Int, complete: ((Int) -> Void)?) {
        requestJSON(url: "http://api.bilibili.com/x/web-interface/archive/coins", parameters: ["aid": aid]) {
            response in
            switch response {
            case let .success(data):
                complete?(data["multiply"].intValue)
            case .failure:
                complete?(0)
            }
        }
    }

    static func requestTodayCoins(complete: ((Int) -> Void)?) {
        requestData(url: "http://www.bilibili.com/plus/account/exp.php") {
            response in
            switch response {
            case let .success(data):
                let json = JSON(data)
                complete?(json["number"].intValue)
            case .failure:
                complete?(0)
            }
        }
    }

    static func requestFavorite(aid: Int, mlid: Int) {
        requestJSON(method: .post, url: "http://api.bilibili.com/x/v3/fav/resource/deal", parameters: ["rid": aid, "type": 2, "add_media_ids": mlid])
    }

    static func requestFavoriteStatus(aid: Int, complete: ((Bool) -> Void)?) {
        requestJSON(url: "http://api.bilibili.com/x/v2/fav/video/favoured", parameters: ["aid": aid]) {
            response in
            switch response {
            case let .success(data):
                complete?(data["favoured"].boolValue)
            case .failure:
                complete?(false)
            }
        }
    }

    static func requestPlayUrl(aid: Int, cid: Int) async throws -> VideoPlayURLInfo {
        let quality = Settings.mediaQuality
        return try await request(url: EndPoint.playUrl,
                                 parameters: ["avid": aid, "cid": cid, "qn": quality.qn, "type": "", "fnver": 0, "fnval": quality.fnval, "otype": "json"])
    }

    static func requestReplys(aid: Int, complete: ((Replys) -> Void)?) {
        request(url: "http://api.bilibili.com/x/v2/reply", parameters: ["type": 1, "oid": aid, "sort": 1, "nohot": 0]) {
            (result: Result<Replys, RequestError>) in
            if let details = try? result.get() {
                complete?(details)
            }
        }
    }

    static func requestSearchResult(key: String, page: Int, complete: ((SearchResult) -> Void)?) {
        request(url: "http://api.bilibili.com/x/web-interface/search/type", parameters: ["search_type": "video", "keyword": key, "page": page]) {
            (result: Result<SearchResult, RequestError>) in
            if var details = try? result.get() {
                details.result.indices.forEach({ details.result[$0].title = details.result[$0].title.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil) })
                complete?(details)
            }
        }
    }

    static func requestSubtitle(url: URL) async throws -> [SubtitleContent] {
        struct SubtitlContenteResp: Codable {
            let body: [SubtitleContent]
        }
        let resp = try await AF.request(url).serializingDecodable(SubtitlContenteResp.self).value
        return resp.body
    }
}

// MARK: - User

extension WebRequest {
    static func follow(mid: Int, follow: Bool) {
        requestJSON(method: .post, url: "https://api.bilibili.com/x/relation/modify", parameters: ["fid": mid, "act": follow ? 1 : 2, "re_src": 14])
    }

    static func logout(complete: (() -> Void)? = nil) {
        request(method: .post, url: EndPoint.logout) {
            (result: Result<[String: String], RequestError>) in
            if let details = try? result.get() {
                print("logout success")
                print(details)
            } else {
                print("logout fail")
            }
            CookieHandler.shared.removeCookie()
            complete?()
        }
    }

    static func requestLoginInfo(complete: ((Result<JSON, RequestError>) -> Void)?) {
        requestJSON(url: "http://api.bilibili.com/x/web-interface/nav", complete: complete)
    }
}

struct HistoryData: DisplayData, Codable {
    struct HistoryPage: Codable, Hashable {
        let cid: Int
    }

    let title: String
    var ownerName: String { owner.name }
    var avatar: URL? { owner.face }
    let pic: URL?

    let owner: VideoOwner
    let cid: Int?
    let aid: Int
    let progress: Int
    let duration: Int
//    let bangumi: BangumiData?
}

struct FavData: DisplayData, Codable {
    var cover: String
    var upper: VideoOwner
    var id: Int
    var title: String
    var ownerName: String { upper.name }
    var pic: URL? { URL(string: cover) }
}

struct FavListData: Codable, Hashable {
    let title: String
    let id: Int
}

struct VideoDetail: Codable, Hashable {
    struct Info: Codable, Hashable {
        let aid: Int
        let cid: Int
        let title: String
        let videos: Int?
        let pic: URL?
        let desc: String?
        let owner: VideoOwner
        let pages: [VideoPage]?
        let dynamic: String?
        let duration: Int
        let pubdate: Int?
        let ugc_season: UgcSeason?

        let stat: Stat
        struct Stat: Codable, Hashable {
            let favorite: Int
            let coin: Int
            let like: Int
            let share: Int
            let danmaku: Int
            let view: Int
        }

        struct UgcSeason: Codable, Hashable {
            let id: Int
            let title: String
            let cover: URL
            let mid: Int
            let intro: String
            let attribute: Int
            let sections: [UgcSeasonDetail]

            struct UgcSeasonDetail: Codable, Hashable {
                let season_id: Int
                let id: Int
                let title: String
                let episodes: [UgcVideoInfo]
            }

            struct UgcVideoInfo: Codable, Hashable, DisplayData {
                var ownerName: String { "" }
                var pic: URL? { arc.pic }
                let aid: Int
                let cid: Int
                let arc: Arc
                let title: String

                struct Arc: Codable, Hashable {
                    let pic: URL
                }
            }
        }

        var durationString: String {
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.hour, .minute, .second]
            formatter.unitsStyle = .brief
            return formatter.string(from: TimeInterval(duration)) ?? ""
        }
    }

    struct Owner: Hashable, Codable {
        let following: Bool
    }

    let View: Info
    let Related: [Info]
    let Card: Owner
}

extension VideoDetail: DisplayData {
    var title: String { View.title }
    var ownerName: String { View.owner.name }
    var pic: URL? { View.pic }
    var avatar: URL? { View.owner.face }
    var date: String? { DateFormatter.stringFor(timestamp: View.pubdate) }
}

extension VideoDetail.Info: DisplayData {
    var ownerName: String { owner.name }
    var avatar: URL? { owner.face }
    var date: String? { DateFormatter.stringFor(timestamp: pubdate) }
}

struct SubtitleResp: Codable {
    let subtitles: [SubtitleData]
}

struct SubtitleData: Codable, Hashable {
    let lan_doc: String
    let subtitle_url: URL
    let lan: String

    var url: URL { subtitle_url.addSchemeIfNeed() }
    var subtitleContents: [SubtitleContent]?
}

struct Replys: Codable, Hashable {
    struct Reply: Codable, Hashable {
        struct Member: Codable, Hashable {
            let uname: String
            let avatar: String
        }

        struct Content: Codable, Hashable {
            let message: String
        }

        let member: Member
        let content: Content
    }

    let replies: [Reply]
}

struct BangumiInfo: Codable, Hashable {
    struct Episode: Codable, Hashable {
        let id: Int
        let aid: Int
        let cid: Int
    }

    let episodes: [Episode] // 正片剧集列表
}

struct VideoOwner: Codable, Hashable {
    let mid: Int
    let name: String
    let face: URL
}

struct VideoPage: Codable, Hashable {
    let cid: Int
    let page: Int
    let from: String
    let part: String
}

struct UpSpaceReq: Codable, Hashable {
    let list: List
    struct List: Codable, Hashable {
        let vlist: [VListData]
        struct VListData: Codable, Hashable, DisplayData {
            let title: String
            let author: String
            let aid: Int
            let pic: URL?
            var ownerName: String {
                return author
            }
        }
    }
}

struct PlayerInfo: Codable {
    let last_play_time: Int
    let subtitle: SubtitleResp?
    var playTimeInSecond: Int {
        last_play_time / 1000
    }
}

struct VideoPlayURLInfo: Codable {
    let quality: Int
    let format: String
    let timelength: Int
    let accept_format: String
    let accept_description: [String]
    let accept_quality: [Int]
    let video_codecid: Int
    let support_formats: [SupportFormate]
    let dash: DashInfo

    struct SupportFormate: Codable {
        let quality: Int
        let format: String
        let new_description: String
        let display_desc: String
        let codecs: [String]
    }

    struct DashInfo: Codable {
        let duration: Int
        let minBufferTime: CGFloat
        let video: [DashMediaInfo]
        let audio: [DashMediaInfo]
        let dolby: DolbyInfo?
        let flac: FlacInfo?
        struct DashMediaInfo: Codable {
            let id: Int
            let base_url: String
            let backup_url: [String]?
            let bandwidth: Int
            let mime_type: String
            let codecs: String
            let width: Int
            let height: Int
            let frame_rate: String
            let sar: String
            let start_with_sap: Int
            let segment_base: DashSegmentBase
            let codecid: Int
        }

        struct DashSegmentBase: Codable {
            let initialization: String
            let index_range: String
        }

        struct DolbyInfo: Codable {
            let type: Int
            let audio: [DolbyAudioInfo]

            struct DolbyAudioInfo: Codable {
                let id: Int
                let base_url: String
                let backup_url: [String]?
                let bandwidth: Int
                let mime_type: String
                let codecs: String
                let segment_base: DashSegmentBase
                let size: Int
            }
        }

        struct FlacInfo: Codable {
            let display: Bool
            let audio: DashMediaInfo
        }
    }
}

struct SearchResult: Codable, Hashable {
    struct Result: Codable, Hashable, DisplayData {
        let author: String
        let upic: URL
        let aid: Int

        // DisplayData
        var title: String
        var ownerName: String { author }
        let pic: URL?
        var avatar: URL? { upic }
    }

    var result: [Result]
}

struct SubtitleContent: Codable, Hashable {
    let from: CGFloat
    let to: CGFloat
    let location: Int
    let content: String
}

extension URL {
    func addSchemeIfNeed() -> URL {
        if scheme == nil {
            return URL(string: "https:\(absoluteString)")!
        }
        return self
    }
}
