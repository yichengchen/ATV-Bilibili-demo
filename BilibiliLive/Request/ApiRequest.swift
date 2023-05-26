//
//  ApiRequest.swift
//  BilibiliLive
//
//  Created by yicheng on 2021/4/25.
//

import Alamofire
import CryptoKit
import Foundation
import SwiftyJSON

struct LoginToken: Codable {
    let mid: Int
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    var expireDate: Date?
}

enum ApiRequest {
    static let appkey = "4409e2ce8ffd12b8"
    static let appsec = "59b43e04ad6965f34319062b478f83dd"

    enum EndPoint {
        static let loginQR = "https://passport.bilibili.com/x/passport-tv-login/qrcode/auth_code"
        static let verifyQR = "https://passport.bilibili.com/x/passport-tv-login/qrcode/poll"
        static let refresh = "https://passport.bilibili.com/api/v2/oauth2/refresh_token"
        static let ssoCookie = "https://passport.bilibili.com/api/login/sso"
        static let feed = "https://app.bilibili.com/x/v2/feed/index"
        static let season = "https://api.bilibili.com/pgc/view/v2/app/season"
    }

    enum LoginState {
        case success(token: LoginToken)
        case fail
        case expire
        case waiting
    }

    static func save(token: LoginToken) {
        UserDefaults.standard.set(token, forKey: "token")
    }

    static func getToken() -> LoginToken? {
        if let token: LoginToken = UserDefaults.standard.codable(forKey: "token") {
            return token
        }
        return nil
    }

    static func isLogin() -> Bool {
        return getToken() != nil
    }

    static func sign(for param: [String: Any]) -> [String: Any] {
        var newParam = param
        newParam["appkey"] = appkey
        newParam["ts"] = "\(Int(Date().timeIntervalSince1970))"
        newParam["local_id"] = "0"
        newParam["mobi_app"] = "android"
        var rawParam = newParam
            .sorted(by: { $0.0 < $1.0 })
            .map({ "\($0.key)=\($0.value)" })
            .joined(separator: "&")
        rawParam.append(appsec)

        let md5 = Insecure.MD5
            .hash(data: rawParam.data(using: .utf8)!)
            .map { String(format: "%02hhx", $0) }
            .joined()
        newParam["sign"] = md5
        return newParam
    }

    static func logout(complete: (() -> Void)? = nil) {
        UserDefaults.standard.removeObject(forKey: "token")
        complete?()
    }

    static func requestJSON(_ url: URLConvertible,
                            method: HTTPMethod = .get,
                            parameters: Parameters = [:],
                            auth: Bool = true,
                            encoding: ParameterEncoding = URLEncoding.default,
                            complete: ((Result<JSON, RequestError>) -> Void)? = nil)
    {
        var parameters = parameters
        if auth {
            parameters["access_key"] = getToken()?.accessToken
        }
        parameters = sign(for: parameters)
        AF.request(url, method: method, parameters: parameters, encoding: encoding).responseData { response in
            switch response.result {
            case let .success(data):
                let json = JSON(data)
                print(json)
                let errorCode = json["code"].intValue
                if errorCode != 0 {
                    if errorCode == -101 {
                        UserDefaults.standard.removeObject(forKey: "token")
                        AppDelegate.shared.showLogin()
                    }
                    let message = json["message"].stringValue
                    print(errorCode, message)
                    complete?(.failure(.statusFail(code: errorCode, message: message)))
                    return
                }
                complete?(.success(json))
            case let .failure(err):
                print(err)
                complete?(.failure(.networkFail))
            }
        }
    }

    static func request<T: Decodable>(_ url: URLConvertible,
                                      method: HTTPMethod = .get,
                                      parameters: Parameters = [:],
                                      auth: Bool = true,
                                      encoding: ParameterEncoding = URLEncoding.default,
                                      decoder: JSONDecoder = JSONDecoder(),
                                      complete: ((Result<T, RequestError>) -> Void)?)
    {
        requestJSON(url, method: method, parameters: parameters, auth: auth, encoding: encoding) { result in
            switch result {
            case let .success(data):
                do {
                    let data = try data["data"].rawData()
                    let object = try decoder.decode(T.self, from: data)
                    complete?(.success(object))
                } catch let err {
                    print(err)
                    complete?(.failure(.decodeFail(message: err.localizedDescription + String(describing: err))))
                }
            case let .failure(err):
                complete?(.failure(err))
            }
        }
    }

    static func request<T: Decodable>(_ url: URLConvertible,
                                      method: HTTPMethod = .get,
                                      parameters: Parameters = [:],
                                      auth: Bool = true,
                                      encoding: ParameterEncoding = URLEncoding.default,
                                      decoder: JSONDecoder = JSONDecoder()) async throws -> T
    {
        try await withCheckedThrowingContinuation { configure in
            request(url, method: method, parameters: parameters, auth: auth, encoding: encoding, decoder: decoder) { resp in
                configure.resume(with: resp)
            }
        }
    }

    static func requestLoginQR(handler: ((String, String) -> Void)? = nil) {
        class Resp: Codable {
            let authCode: String
            let url: String
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        request(EndPoint.loginQR, method: .post, auth: false, decoder: decoder) {
            (result: Result<Resp, RequestError>) in
            switch result {
            case let .success(res):
                handler?(res.authCode, res.url)
            case let .failure(error):
                print(error)
            }
        }
    }

    struct LoginResp: Codable {
        struct CookieInfo: Codable {
            let domains: [String]
            let cookies: [Cookie]
            func toCookies() -> [HTTPCookie] {
                domains.map { domain in
                    cookies.compactMap { $0.toCookie(domain: domain) }
                }.reduce([], +)
            }
        }

        struct Cookie: Codable {
            let name: String
            let value: String
            let httpOnly: Int
            let expires: Int

            func toCookie(domain: String) -> HTTPCookie? {
                HTTPCookie(properties: [.domain: domain,
                                        .name: name,
                                        .value: value,
                                        .expires: Date(timeIntervalSince1970: TimeInterval(expires)),
                                        HTTPCookiePropertyKey("HttpOnly"): httpOnly,
                                        .path: ""])
            }
        }

        var tokenInfo: LoginToken
        let cookieInfo: CookieInfo
    }

    static func verifyLoginQR(code: String, handler: ((LoginState) -> Void)? = nil) {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        request(EndPoint.verifyQR,
                method: .post, parameters: ["auth_code": code], auth: false, decoder: decoder) {
            (result: Result<LoginResp, RequestError>) in
            switch result {
            case var .success(res):
                res.tokenInfo.expireDate = Date().addingTimeInterval(TimeInterval(res.tokenInfo.expiresIn))
                CookieHandler.shared.saveCookie(list: res.cookieInfo.toCookies())
                handler?(.success(token: res.tokenInfo))
            case let .failure(error):
                switch error {
                case let .statusFail(code, _):
                    switch code {
                    case 86038: handler?(.expire)
                    case 86039: handler?(.waiting)
                    default:
                        break
                    }
                default:
                    break
                }
            }
        }
    }

    static func refreshToken() {
        AF.cancelAllRequests()
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        request(EndPoint.refresh, method: .post, parameters: ["refresh_token": getToken()?.refreshToken ?? ""], decoder: decoder) {
            (result: Result<LoginResp, RequestError>) in
            switch result {
            case var .success(res):
                res.tokenInfo.expireDate = Date().addingTimeInterval(TimeInterval(res.tokenInfo.expiresIn))
                CookieHandler.shared.saveCookie(list: res.cookieInfo.toCookies())
                UserDefaults.standard.set(codable: res.tokenInfo, forKey: "token")
            case let .failure(err):
                print(err)
            }
        }
    }

    struct FeedResp: Codable {
        let items: [Items]

        struct Items: DisplayData, Codable {
            let can_play: Int?
            let title: String
            let param: String
            let args: Args
            let idx: Int
            let cover: String
            let goto: String
            let rcmd_reason: String?

            var ownerName: String {
                return args.up_name ?? ""
            }

            var pic: URL? {
                return URL(string: cover)
            }

            var date: String? { rcmd_reason }
        }

        struct Args: Codable, Hashable {
            let up_name: String?
//            let aid: Int?
        }
    }

    static func getFeeds(lastIdx: Int = 0) async throws -> [FeedResp.Items] {
        let idx = "\(lastIdx)"
        let resp: FeedResp = try await request(EndPoint.feed, parameters: ["idx": idx, "flush": "0", "column": "4", "device": "pad", "pull": idx == "0" ? "1" : "0"])
        return resp.items.filter({ $0.goto == "av" })
    }

    static func requestDislike(aid: Int, dislike: Bool) {
        requestJSON("http://app.biliapi.net/x/v2/view/dislike", method: .post, parameters: ["aid": aid, "dislike": dislike ? 0 : 1])
    }

    struct BangumiInfo: Codable, Hashable {
        struct Stat: Codable, Hashable {
            let coins, danmakus, favorite, favorites: Int
            let likes, reply, share, views: Int
        }

        struct Rights: Codable, Hashable {
            let area_limit: Int
            let ban_area_show: Int
        }

        struct UserStatus: Codable, Hashable {
            let follow: Int
            let follow_status: Int
        }

        let title: String
        let cover: String
        let evaluate: String?
        let season_id: Int
        let season_title: String
        let user_status: UserStatus
        let stat: Stat
        let rights: Rights
    }

    static func requestBangumiInfo(epid: Int) async throws -> BangumiInfo {
        let info: BangumiInfo = try await request(EndPoint.season, parameters: ["ep_id": "\(epid)"])
        return info
    }

    static func requestBangumiInfo(seasonID: Int) async throws -> BangumiInfo {
        let info: BangumiInfo = try await request(EndPoint.season, parameters: ["season_id": "\(seasonID)"])
        return info
    }

    struct UpSpaceListData: Codable, Hashable, DisplayData, PlayableData {
        var pic: URL? { return cover }

        var aid: Int { return Int(param) ?? 0 }

        let title: String
        let author: String
        let param: String
        let cover: URL?
        var ownerName: String {
            return author
        }

        var cid: Int { return 0 }
    }

    static func requestUpSpaceVideo(mid: Int, lastAid: Int?, pageSize: Int = 20) async throws -> [UpSpaceListData] {
        struct Resp: Codable {
            let item: [UpSpaceListData]
        }

        var param: Parameters = ["vmid": mid, "ps": pageSize, "actionKey": "appkey", "disable_rcmd": 0, "fnval": 976, "fnver": 0, "force_host": 0, "fourk": 1, "order": "pubdate", "player_net": 1, "qn": 120]
        if let lastAid {
            param["aid"] = lastAid
        }
        let resp: Resp = try await request("https://app.bilibili.com/x/v2/space/archive/cursor", parameters: param)
        return resp.item
    }
}
