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
    }
    
    static func request<T: Decodable>(method: HTTPMethod,
                                      url: URLConvertible,
                                      parameters: Parameters = [:],
                                      headers: [String:String]? = nil,
                                      decoder: JSONDecoder? = nil,
                                      complete: ((Result<T, RequestError>) -> Void)?) {
        var parameters = parameters
        parameters["biliCSRF"] = CookieHandler.shared.csrf()
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
                    
                    if let data = try? json["data"].rawData(),
                       let object = try? (decoder ?? JSONDecoder()).decode(T.self, from: data) {
                        complete?(.success(object))
                    } else {
                        complete?(.failure(.decodeFail))
                    }
                case .failure(let err):
                    print(err)
                    complete?(.failure(.networkFail))
                }
            }
    }
    
    static func requestRelatedVideo(aid: Int,complete: (([VideoDetail])->Void)?=nil) {
        request(method: .get, url: EndPoint.related, parameters: ["aid":aid]) {
            (result: Result<[VideoDetail], RequestError>) in
            if let details = try? result.get() {
                complete?(details)
            }
        }
    }
    
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

