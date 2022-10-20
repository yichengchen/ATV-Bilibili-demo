//
//  WebRequest.swift
//  BilibiliLive
//
//  Created by yicheng on 2021/4/29.
//

import Alamofire
import Foundation
import SwiftyJSON

enum RequestError:Error {
    case networkFail
    case statusFail(code:Int)
    case decodeFail
}

class WebRequest {    
    enum EndPoint {
        static let related = "http://api.bilibili.com/x/web-interface/archive/related"
        static let logout = "http://passport.bilibili.com/login/exit/v2"
        static let info = "http://api.bilibili.com/x/web-interface/view"
        static let fav = "http://api.bilibili.com/x/v3/fav/resource/list"
        static let favList = "http://api.bilibili.com/x/v3/fav/folder/created/list-all"
        static let reportHistory = "https://api.bilibili.com/x/v2/history/report"
    }
    
    static func requestJSON(method: HTTPMethod = .get,
                            url: URLConvertible,
                            parameters: Parameters = [:],
                            headers: [String:String]? = nil,
                            complete: ((Result<JSON, RequestError>) -> Void)?) {
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
                case .success(let data):
                    let json = JSON(data)
                    let errorCode = json["code"].intValue
                    if errorCode != 0 {
                        print(errorCode)
                        complete?(.failure(.statusFail(code: errorCode)))
                        return
                    }
                    let dataj = json["data"]
                    print(dataj)
                    complete?(.success(dataj))
                case .failure(let err):
                    print(err)
                    complete?(.failure(.networkFail))
                }
            }
    }
    
    static func request<T: Decodable>(method: HTTPMethod = .get,
                                      url: URLConvertible,
                                      parameters: Parameters = [:],
                                      headers: [String:String]? = nil,
                                      decoder: JSONDecoder? = nil,
                                      complete: ((Result<T, RequestError>) -> Void)?) {
        requestJSON(method: method, url: url, parameters: parameters, headers: headers) { response in
            switch response {
            case .success(let data):
                do {
                    let data = try data.rawData()
                    let object = try (decoder ?? JSONDecoder()).decode(T.self, from: data)
                    complete?(.success(object))
                } catch let err {
                    print("decode fail:", err)
                    complete?(.failure(.decodeFail))
                }
            case .failure(let err):
                complete?(.failure(err))
            }
        }
    }
    
    static func requestJSON(method: HTTPMethod = .get,
                            url: URLConvertible,
                            parameters: Parameters = [:],
                            headers: [String:String]? = nil) async throws -> JSON {
        return try await withCheckedThrowingContinuation{ configure in
            requestJSON(method: method, url: url,parameters: parameters, headers: headers) { resp in
                configure.resume(with: resp)
            }
        }
    }
        
    static func request<T: Decodable>(method: HTTPMethod = .get,
                                      url: URLConvertible,
                                      parameters: Parameters = [:],
                                      headers: [String:String]? = nil,
                                      decoder: JSONDecoder? = nil) async throws ->T {
        return try await withCheckedThrowingContinuation { configure in
            request(method: method, url: url, parameters: parameters, headers: headers, decoder: decoder) {
                (res:Result<T, RequestError>) in
                switch res {
                case .success(let content):
                    configure.resume(returning: content)
                case .failure(let err):
                    configure.resume(throwing: err)
                }
            }
        }
    }
}

// MARK: - Video
extension WebRequest {
    static func requestRelatedVideo(aid: Int,complete: (([VideoDetail])->Void)?=nil) {
        request(method: .get, url: EndPoint.related, parameters: ["aid":aid]) {
            (result: Result<[VideoDetail], RequestError>) in
            if let details = try? result.get() {
                complete?(details)
            }
        }
    }
    
    static func requestDetailVideo(aid: Int) async -> VideoDetail?  {
        do {
            return try await request(method: .get, url: EndPoint.info, parameters: ["aid": aid])
        } catch {
            return nil
        }
    }
    
    static func requestFavVideosList() async throws -> [FavListData] {
        guard let mid = ApiRequest.getToken()?.mid else { return [] }
        struct Resp: Codable {
            let list:[FavListData]
        }
        let res: Resp = try await request(method: .get, url: EndPoint.favList, parameters: ["up_mid": mid])
        return res.list
    }
    
    static func requestFavVideos(mid: String) async throws -> [FavData]  {
        struct Resp:Codable {
            let medias:[FavData]?
        }
        let res: Resp = try await request(method: .get, url: EndPoint.fav, parameters: ["media_id": mid, "ps": "20"])
        return res.medias ?? []
    }
    
    static func reportWatchHistory(aid: Int, cid: Int, currentTime: Int) {
        WebRequest.requestJSON(method: .post,
                               url: EndPoint.reportHistory,
                               parameters: ["aid": aid, "cid": cid, "progress": currentTime],
                               complete: nil)
    }
}

// MARK: - User
extension WebRequest {
    static func logout(complete: (()->Void)?=nil) {
        request(method: .post, url: EndPoint.logout) {
            (result: Result<[String:String], RequestError>) in
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

struct FavData: DisplayData, Codable {
    struct Upper: Codable, Hashable {
        var name: String
    }
    var cover: String
    var upper: Upper
    var id: Int
    var title: String
    var owner: String { get { upper.name } }
    var pic: URL? { get { URL(string: cover) } }
}

struct FavListData: Codable {
    let title: String
    let id: Int
}

struct VideoDetail: Codable {
    let aid: Int
    let cid: Int
    let title: String
    let videos: Int
    let pic: String
    let desc: String
    let owner: VideoOwner
    let pages: [VideoPage]?
}

struct VideoOwner: Codable {
    let mid: Int
    let name: String
    let face: String
}

struct VideoPage: Codable {
    let cid: Int
    let page: Int
    let from: String
    let part: String
}

