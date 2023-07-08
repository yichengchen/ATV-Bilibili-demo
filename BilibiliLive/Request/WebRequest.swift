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

enum ValidationError: Error {
    case argumentInvalid(message: String)
}

enum NoCookieSession {
    static let session = Session(configuration: URLSessionConfiguration.ephemeral)
}

enum WebRequest {
    enum EndPoint {
        static let related = "https://api.bilibili.com/x/web-interface/archive/related"
        static let logout = "https://passport.bilibili.com/login/exit/v2"
        static let info = "https://api.bilibili.com/x/web-interface/view"
        static let fav = "https://api.bilibili.com/x/v3/fav/resource/list"
        static let favList = "https://api.bilibili.com/x/v3/fav/folder/created/list-all"
        static let reportHistory = "https://api.bilibili.com/x/v2/history/report"
        static let upSpace = "https://api.bilibili.com/x/space/wbi/arc/search"
        static let like = "https://api.bilibili.com/x/web-interface/archive/like"
        static let likeStatus = "https://api.bilibili.com/x/web-interface/archive/has/like"
        static let coin = "https://api.bilibili.com/x/web-interface/coin/add"
        static let playerInfo = "https://api.bilibili.com/x/player/v2"
        static let playUrl = "https://api.bilibili.com/x/player/playurl"
        static let pcgPlayUrl = "https://api.bilibili.com/pgc/player/web/playurl"
        static let bangumiSeason = "https://bangumi.bilibili.com/view/web_api/season"
        static let userEpisodeInfo = "https://api.bilibili.com/pgc/season/episode/web/info"
    }

    static func requestData(method: HTTPMethod = .get,
                            url: URLConvertible,
                            parameters: Parameters = [:],
                            headers: [String: String]? = nil,
                            noCookie: Bool = false,
                            complete: ((Result<Data, RequestError>) -> Void)? = nil)
    {
        var parameters = parameters
        if method != .get {
            parameters["biliCSRF"] = CookieHandler.shared.csrf()
            parameters["csrf"] = CookieHandler.shared.csrf()
        }

        var afheaders = HTTPHeaders()
        if let headers {
            for (k, v) in headers {
                afheaders.add(HTTPHeader(name: k, value: v))
            }
        }

        if !afheaders.contains(where: { $0.name == "User-Agent" }) {
            afheaders.add(.userAgent("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.2 Safari/605.1.15"))
        }

        if !afheaders.contains(where: { $0.name == "Referer" }) {
            afheaders.add(HTTPHeader(name: "Referer", value: "https://www.bilibili.com"))
        }

        var session = Session.default
        if noCookie {
            session = NoCookieSession.session
            session.sessionConfiguration.httpShouldSetCookies = false
        }
        session.sessionConfiguration.timeoutIntervalForResource = 10
        session.sessionConfiguration.timeoutIntervalForRequest = 10
        session.request(url,
                        method: method,
                        parameters: parameters,
                        encoding: URLEncoding.default,
                        headers: afheaders,
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
                            noCookie: Bool = false,
                            complete: ((Result<JSON, RequestError>) -> Void)? = nil)
    {
        requestData(method: method, url: url, parameters: parameters, headers: headers, noCookie: noCookie) { response in
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
                print("\(url) response: \(json)")
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
                                      noCookie: Bool = false,
                                      complete: ((Result<T, RequestError>) -> Void)?)
    {
        requestJSON(method: method, url: url, parameters: parameters, headers: headers, dataObj: dataObj, noCookie: noCookie) { response in
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
                                      decoder: JSONDecoder? = nil,
                                      noCookie: Bool = false,
                                      dataObj: String = "data") async throws -> T
    {
        return try await withCheckedThrowingContinuation { configure in
            request(method: method, url: url, parameters: parameters, headers: headers, decoder: decoder, dataObj: dataObj, noCookie: noCookie) {
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
    static func requestBangumiInfo(epid: Int) async throws -> BangumiInfo {
        let info: BangumiInfo = try await request(url: "http://api.bilibili.com/pgc/view/web/season", parameters: ["ep_id": epid], dataObj: "result")
        return info
    }

    static func requestBangumiInfo(seasonID: Int) async throws -> BangumiSeasonInfo {
        let res: BangumiSeasonInfo = try await request(url: "https://api.bilibili.com/pgc/web/season/section", parameters: ["season_id": seasonID], dataObj: "result")
        return res
    }

    static func requestBangumiSeasonView(epid: Int) async throws -> BangumiSeasonView {
        let info: BangumiSeasonView = try await request(url: EndPoint.bangumiSeason, parameters: ["ep_id": epid], dataObj: "result")
        return info
    }

    static func requestBangumiSeasonView(seasonID: Int) async throws -> BangumiSeasonView {
        let info: BangumiSeasonView = try await request(url: EndPoint.bangumiSeason, parameters: ["season_id": seasonID], dataObj: "result")
        return info
    }

    static func requestUserEpisodeInfo(epid: Int) async throws -> UserEpisodeInfo {
        try await request(url: EndPoint.userEpisodeInfo, parameters: ["ep_id": epid])
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

    static func requestFavVideos(mid: String, page: Int) async throws -> [FavData] {
        struct Resp: Codable {
            let medias: [FavData]?
        }
        let res: Resp = try await request(method: .get, url: EndPoint.fav, parameters: ["media_id": mid, "ps": "20", "pn": page, "platform": "web"])
        return res.medias ?? []
    }

    static func reportWatchHistory(aid: Int, cid: Int, currentTime: Int) {
        requestJSON(method: .post,
                    url: EndPoint.reportHistory,
                    parameters: ["aid": aid, "cid": cid, "progress": currentTime],
                    complete: nil)
    }

    static func requestUpSpaceVideo(mid: Int, page: Int, pageSize: Int = 50) async throws -> [UpSpaceReq.List.VListData] {
        let resp: UpSpaceReq = try await request(url: EndPoint.upSpace, parameters: ["mid": mid, "pn": page, "ps": pageSize, "platform": "web", "web_location": "1550101"])
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

    static func requestFavorite(aid: Int, mid: Int) {
        requestJSON(method: .post, url: "http://api.bilibili.com/x/v3/fav/resource/deal", parameters: ["rid": aid, "type": 2, "add_media_ids": mid])
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

    static func requestPcgPlayUrl(aid: Int, cid: Int) async throws -> VideoPlayURLInfo {
        let quality = Settings.mediaQuality
        return try await request(url: EndPoint.pcgPlayUrl,
                                 parameters: ["avid": aid, "cid": cid, "qn": quality.qn, "support_multi_audio": true, "fnver": 0, "fnval": quality.fnval, "fourk": 1],
                                 dataObj: "result")
    }

    static func requestAreaLimitPcgPlayUrl(epid: Int, cid: Int, area: String) async throws -> VideoPlayURLInfo {
        let quality = Settings.mediaQuality
        let customServer = Settings.areaLimitCustomServer
        guard !customServer.isEmpty else { throw ValidationError.argumentInvalid(message: "未设置解析服务器") }

        // 解析服务器必须使用ep_id参数，不能使用avid参数，解析服务器一般有缓存，area和ep_id必须保持一致，要不然会被缓存拦截
        let url = EndPoint.pcgPlayUrl.replacingOccurrences(of: "api.bilibili.com", with: customServer)
        var parameters: [String: Any] = ["ep_id": epid, "cid": cid, "qn": quality.qn, "support_multi_audio": 1, "fnver": 0, "fnval": quality.fnval, "fourk": 1, "area": area]
        if let access_key = ApiRequest.getToken()?.accessToken {
            parameters["access_key"] = access_key
        }
        parameters["appkey"] = ApiRequest.appkey
        parameters["local_id"] = 0
        parameters["mobi_app"] = "android"

        // 同步b站cookie给代理域
//        var headers: [String: String] = [:]
//        if let cookies = Session.default.sessionConfiguration.httpCookieStorage?.cookies(for: URL(string: "https://api.bilibili.com")!) {
//            headers = HTTPCookie.requestHeaderFields(with: cookies)
//        }

        return try await request(url: url,
                                 parameters: parameters,
                                 dataObj: "result")
    }

    static func requestReplys(aid: Int, complete: ((Replys) -> Void)?) {
        request(url: "http://api.bilibili.com/x/v2/reply", parameters: ["type": 1, "oid": aid, "sort": 1, "nohot": 0]) {
            (result: Result<Replys, RequestError>) in
            if let details = try? result.get() {
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

    static func requestCid(aid: Int) async throws -> Int {
        let res = try await requestJSON(url: "https://api.bilibili.com/x/player/pagelist?aid=\(aid)&jsonp=jsonp")
        let cid = res[0]["cid"].intValue
        return cid
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
    var avatar: URL? { URL(string: owner.face) }
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
    var type: Int?
    var title: String
    var ogv: Ogv?
    var ownerName: String { upper.name }
    var pic: URL? { URL(string: cover) }

    struct Ogv: Codable, Hashable {
        let season_id: Int?
    }
}

class FavListData: Codable, Hashable {
    let title: String
    let id: Int
    var currentPage = 1
    var end = false
    var loading = false
    enum CodingKeys: String, CodingKey {
        case title, id
    }

    static func == (lhs: FavListData, rhs: FavListData) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    init(title: String, id: Int, currentPage: Int = 1) {
        self.title = title
        self.id = id
        self.currentPage = currentPage
    }
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
        let bvid: String?
        let duration: Int
        let pubdate: Int?
        let ugc_season: UgcSeason?
        let redirect_url: URL?
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
        let follower: Int?
    }

    let View: Info
    let Related: [Info]
    let Card: Owner
}

extension VideoDetail: DisplayData {
    var title: String { View.title }
    var ownerName: String { View.owner.name }
    var pic: URL? { View.pic }
    var avatar: URL? { URL(string: View.owner.face) }
    var date: String? { DateFormatter.stringFor(timestamp: View.pubdate) }
}

extension VideoDetail.Info: DisplayData, PlayableData {
    var ownerName: String { owner.name }
    var avatar: URL? { URL(string: owner.face) }
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

    let replies: [Reply]?
}

struct BangumiSeasonInfo: Codable {
    let main_section: BangumiInfo
    let section: [BangumiInfo]
}

struct BangumiInfo: Codable, Hashable {
    struct Episode: Codable, Hashable {
        let id: Int
        let aid: Int
        let cid: Int
        let cover: URL
        let long_title: String
        let title: String
    }

    let episodes: [Episode] // 正片剧集列表
}

struct BangumiSeasonView: Codable, Hashable {
    struct Episode: Codable, Hashable {
        let ep_id: Int
        let aid: Int
        let cid: Int
        let bvid: String?
        let duration: Int
        let cover: URL
        let index_title: String?
        let index: String
        let pub_real_time: String
        let section_type: Int

        var pubdate: Int? {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            if let date = dateFormatter.date(from: pub_real_time) {
                return Int(date.timeIntervalSince1970)
            }
            return nil
        }

        var durationSeconds: Int {
            return Int(duration / 1000)
        }
    }

    struct UpInfo: Codable, Hashable {
        let mid: Int
        let uname: String
        let avatar: String
        let follower: Int?
    }

    let up_info: UpInfo
    let episodes: [Episode]
    let title: String
    let series_title: String
    let evaluate: String
}

struct UserEpisodeInfo: Codable, Hashable {
    struct RelatedUp: Codable, Hashable {
        let avatar: String
        let is_follow: Int
        let mid: Int
        let uname: String
    }

    struct Stat: Codable, Hashable {
        let coin: Int
        let dm: Int
        let like: Int
        let reply: Int
        let view: Int
    }

    struct UserCommunity: Codable, Hashable {
        let coin_number: Int
        let favorite: Int
        let is_original: Int
        let like: Int
    }

    let related_up: [RelatedUp]
    let stat: Stat
    let user_community: UserCommunity
}

struct VideoOwner: Codable, Hashable {
    let mid: Int
    let name: String
    let face: String
}

struct VideoPage: Codable, Hashable {
    let cid: Int
    let page: Int
    let epid: Int?
    let from: String
    let part: String
}

struct UpSpaceReq: Codable, Hashable {
    let list: List
    struct List: Codable, Hashable {
        let vlist: [VListData]
        struct VListData: Codable, Hashable, DisplayData, PlayableData {
            let title: String
            let author: String
            let aid: Int
            let pic: URL?
            var ownerName: String {
                return author
            }

            var cid: Int { return 0 }
        }
    }
}

struct PlayerInfo: Codable {
    let last_play_time: Int
    let subtitle: SubtitleResp?
    let view_points: [ViewPoint]?
    let dm_mask: MaskInfo?
    let last_play_cid: Int
    var playTimeInSecond: Int {
        last_play_time / 1000
    }

    struct ViewPoint: Codable {
        let type: Int
        let from: TimeInterval
        let to: TimeInterval
        let content: String
        let imgUrl: URL?
    }

    struct MaskInfo: Codable {
        let mask_url: URL?
        let fps: Int
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
    let clip_info_list: [ClipInfo]?

    class ClipInfo: Codable {
        let start: CGFloat
        let end: CGFloat
        let clipType: String?
        let toastText: String?
        var a11Tag: String {
            "\(start)\(end)"
        }

        var skipped: Bool? = false

        var customText: String {
            if clipType == "CLIP_TYPE_OP" {
                return "跳过片头"
            } else if clipType == "CLIP_TYPE_ED" {
                return "跳过片尾"
            } else {
                return toastText ?? "跳过"
            }
        }

        init(start: CGFloat, end: CGFloat, clipType: String?, toastText: String?) {
            self.start = start
            self.end = end
            self.clipType = clipType
            self.toastText = toastText
        }
    }

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
        let audio: [DashMediaInfo]?
        let dolby: DolbyInfo?
        let flac: FlacInfo?
        struct DashMediaInfo: Codable, Hashable {
            let id: Int
            let base_url: String
            let backup_url: [String]?
            let bandwidth: Int
            let mime_type: String
            let codecs: String
            let width: Int?
            let height: Int?
            let frame_rate: String?
            let sar: String?
            let start_with_sap: Int?
            let segment_base: DashSegmentBase
            let codecid: Int?
        }

        struct DashSegmentBase: Codable, Hashable {
            let initialization: String
            let index_range: String
        }

        struct DolbyInfo: Codable {
            let type: Int
            let audio: [DashMediaInfo]?
        }

        struct FlacInfo: Codable {
            let display: Bool
            let audio: DashMediaInfo?
        }
    }
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
