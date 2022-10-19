//
//  ApiRequest.swift
//  BilibiliLive
//
//  Created by yicheng on 2021/4/25.
//

import Foundation
import CryptoKit
import Alamofire
import SwiftyJSON


struct LoginToken: Codable {
    let mid:Int
    let accessToken:String
    let refreshToken:String
    let expiresIn:Int
    var expireDate:Date?
}

class ApiRequest {
    static let appkey = "4409e2ce8ffd12b8"
    static let appsec = "59b43e04ad6965f34319062b478f83dd"
    
    enum EndPoint {
        static let loginQR = "https://passport.bilibili.com/x/passport-tv-login/qrcode/auth_code"
        static let verifyQR = "https://passport.bilibili.com/x/passport-tv-login/qrcode/poll"
        static let refresh = "https://passport.bilibili.com/api/v2/oauth2/refresh_token"
        static let ssoCookie = "https://passport.bilibili.com/api/login/sso"
        static let feed = "https://app.bilibili.com/x/v2/feed/index"
    }
    
    enum LoginState {
        case success(token:LoginToken)
        case fail
        case expire
        case waiting
    }
    
    static func save(token:LoginToken) {
        UserDefaults.standard.set(token, forKey: "token")
    }
    
    static func getToken() -> LoginToken? {
        if let token:LoginToken = UserDefaults.standard.codable(forKey: "token") {
            return token
        }
        return nil
    }
    
    static func isLogin() -> Bool {
        return getToken() != nil
    }
    
    static func sign(for param: [String:String]) -> [String: String] {
        var newParam = param
        newParam["appkey"] = appkey
        newParam["ts"] = "\(Date().timeIntervalSince1970)"
        newParam["local_id"] = "0"
        var rawParam = newParam
            .sorted(by: { $0.0 < $1.0 })
            .map({"\($0.key)=\($0.value)"})
            .joined(separator: "&")
        rawParam.append(appsec)
        
        let md5 = Insecure.MD5
            .hash(data: rawParam.data(using: .utf8)!)
            .map { String(format: "%02hhx", $0)}
            .joined()
        newParam["sign"] = md5
        return newParam
    }
    
    static func logout(complete:(()->Void)?=nil) {
        UserDefaults.standard.removeObject(forKey: "token")
        complete?()
    }
    
    
    static func requestJSON(_ url: URLConvertible,
                        method: HTTPMethod = .get,
                        parameters: [String:String] = [:],
                        auth:Bool = true,
                        encoding: ParameterEncoding = URLEncoding.default,
                        complete: ((Result<JSON, RequestError>) -> Void)?) {
        var param = parameters
        if auth {
            param["access_key"] = getToken()?.accessToken
        }
        param = sign(for: param)
        AF.request(url,method: method,parameters: param,encoding: encoding).responseData { response in
            switch response.result {
            case .success(let data):
                let json = JSON(data)
                print(json)
                let errorCode = json["code"].intValue
                if errorCode != 0 {
                    print(errorCode)
                    if errorCode == -101 {
                        UserDefaults.standard.removeObject(forKey: "token")
                        AppDelegate.shared.showLogin()
                    }
                    complete?(.failure(.statusFail(code:errorCode)))
                    return
                }
                complete?(.success(json))
            case .failure(let err):
                print(err)
                complete?(.failure(.networkFail))
            }
        }
    }
    
    static func request<T: Decodable>(_ url: URLConvertible,
                        method: HTTPMethod = .get,
                        parameters: [String:String] = [:],
                        auth:Bool = true,
                        encoding: ParameterEncoding = URLEncoding.default,
                        decoder: JSONDecoder = JSONDecoder(),
                        complete: ((Result<T, RequestError>) -> Void)?) {
        requestJSON(url,method: method,parameters: parameters,auth: auth,encoding: encoding) { result in
            switch result {
            case .success(let data):
                do {
                    let data = try data["data"].rawData()
                    let object = try decoder.decode(T.self, from: data)
                    complete?(.success(object))
                } catch let err {
                    print(err)
                    complete?(.failure(.decodeFail))
                }
            case .failure(let err):
                complete?(.failure(err))
            }
        }
    }
    
    static func requestLoginQR(handler: ((String,String)->Void)?=nil) {
        
        class Resp:Codable {
            let authCode: String
            let url: String
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        request(EndPoint.loginQR, method: .post,auth: false, decoder: decoder){
            (result:Result<Resp, RequestError>) in
            switch result {
            case .success(let res):
                handler?(res.authCode,res.url)
            case .failure(let error):
                print(error)
            }
        }
    }
    
    
    struct LoginResp: Codable {
        struct CookieInfo: Codable {
            let domains:[String]
            let cookies:[Cookie]
            func toCookies()->[HTTPCookie] {
                domains.map { domain in
                    cookies.compactMap{$0.toCookie(domain: domain)}
                }.reduce([], +)
            }

        }
        struct Cookie:Codable {
            let name: String
            let value:String
            let httpOnly:Int
            let expires: Int
            
            func toCookie(domain: String)->HTTPCookie? {
                HTTPCookie(properties: [.domain :domain,
                                        .name:name,
                                        .value:value,
                                        .expires:Date(timeIntervalSince1970: TimeInterval(expires)),
                                        HTTPCookiePropertyKey("HttpOnly"):httpOnly,
                                        .path:""])
            }
        }
        var tokenInfo: LoginToken
        let cookieInfo:CookieInfo
    }
    
    static func verifyLoginQR(code: String,handler: ((LoginState)->Void)?=nil) {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        request(EndPoint.verifyQR,
                method: .post,parameters: ["auth_code":code],auth: false,decoder: decoder) {
            (result:Result<LoginResp, RequestError>) in
            switch result {
            case .success(var res):
                res.tokenInfo.expireDate = Date().addingTimeInterval(TimeInterval(res.tokenInfo.expiresIn))
                CookieHandler.shared.saveCookie(list: res.cookieInfo.toCookies())
                handler?(.success(token: res.tokenInfo))
            case .failure(let error):
                switch error {
                case .statusFail(let code):
                    switch code {
                    case 86038: handler?(.expire)
                    case 86039: handler?(.waiting)
                    default:
                        break
                    }
                    break
                default:
                    break
                }
            }
        }
    }
    
    static func getSSOCookie() {
        
    }
    
    static func refreshToken() {
        AF.cancelAllRequests()
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        request(EndPoint.refresh,method: .post,parameters: ["refresh_token" : getToken()?.refreshToken ?? ""],decoder: decoder) {
            (result:Result<LoginResp, RequestError>) in
            switch result {
            case .success(var res):
                res.tokenInfo.expireDate = Date().addingTimeInterval(TimeInterval(res.tokenInfo.expiresIn))
                CookieHandler.shared.saveCookie(list: res.cookieInfo.toCookies())
                UserDefaults.standard.set(codable: res.tokenInfo, forKey: "token")
            case .failure(let err):
                print(err)
            }
        }
    }
    
    
    struct FeedResp:Codable {
        let items:[Items]
        
        struct Items: Codable,DisplayData {
            let can_play:Int?
            let title: String
            let param: String
            let args: Args
            let idx: Int
            let cover: String
            
            var owner: String {
                return args.up_name ?? ""
            }
            var pic: URL? {
                return URL(string: cover)
            }
        }
        
        struct Args: Codable {
            let up_name:String?
//            let aid: Int?
        }
    }
    
    static func getFeeds(datas:[FeedResp.Items]=[], complete:(([FeedResp.Items])->Void)?=nil) {
        let idx = "\(datas.last?.idx ?? 0)"
        request(EndPoint.feed,parameters: ["idx":idx,"flush":"0","column":"4","device":"pad","pull":idx == "0" ? "1" : "0"]) {
            (resp: Result<FeedResp, RequestError>) in
            switch resp {
            case .success(let data):
                print(data.items)
                complete?(datas + data.items)
            case .failure(let err):
                print(err)
                complete?(datas)
                break
            }
        }
    }
    

}

