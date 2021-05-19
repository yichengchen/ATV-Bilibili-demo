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
    }
    
    static func request<T: Decodable>(method: HTTPMethod,
                                      url: URLConvertible,
                                      parameters: Parameters? = nil,
                                      headers: [String:String]? = nil,
                                      decoder: JSONDecoder? = nil,
                                      complete: ((Result<T, RequestError>) -> Void)?) {
        
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

