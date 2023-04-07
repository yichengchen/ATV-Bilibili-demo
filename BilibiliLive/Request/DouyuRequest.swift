//
//  DouyuRequest.swift
//  BilibiliLive
//
//  Created by yicheng on 2023/4/5.
//

import Alamofire
import Foundation
import SwiftyJSON

class DouyuRequest {
    static func requestData(method: HTTPMethod = .get,
                            url: URLConvertible,
                            parameters: Parameters = [:],
                            headers: [String: String]? = nil,
                            complete: ((Result<Data, RequestError>) -> Void)? = nil)
    {
//        var parameters = parameters
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
            afheaders.add(HTTPHeader(name: "Referer", value: "https://www.douyu.com"))
        }

        AF.request(url,
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
                                      decoder: JSONDecoder? = nil,
                                      dataObj: String = "data") async throws -> T
    {
        return try await withCheckedThrowingContinuation { configure in
            request(method: method, url: url, parameters: parameters, headers: headers, decoder: decoder, dataObj: dataObj) {
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

extension DouyuRequest {
    static func requestChannel() async throws -> [DChannelData] {
        let res: [DChannelData] = try await request(url: "http://capi.douyucdn.cn/api/v1/getColumnList")
        return res
    }

    static func requestLives(channel: String, page: Int) async throws -> [DLiveRoom] {
        let size = 20
        let offset = size * (page - 1)
        let res: [DLiveRoom] = try await request(url: "http://capi.douyucdn.cn/api/v1/getColumnRoom/\(channel)?limit=\(size)&offset=\(offset)")
        return res
    }
}

struct DChannelData: Codable {
    let cate_id: String
    let cate_name: String
    let orderdisplay: String
    let is_relate: String
}

struct DLiveRoom: Codable, PlayableData {
    let room_id: String
    let room_src: String
    let cate_id: Int
    let room_name: String
    let nickname: String
    let avatar: URL?

    var aid: Int { 0 }
    var cid: Int { 0 }
    var title: String { room_name }
    var ownerName: String { nickname }
    var pic: URL? { return URL(string: room_src) }
}
