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
}

class ApiRequest {
    static let appkey = "4409e2ce8ffd12b8"
    static let appsec = "59b43e04ad6965f34319062b478f83dd"
    
    enum EndPoint {
        static let loginQR = "http://passport.bilibili.com/x/passport-tv-login/qrcode/auth_code"
        static let verifyQR = "http://passport.bilibili.com/x/passport-tv-login/qrcode/poll"
        static let ssoCookie = "https://passport.bilibili.com/api/login/sso"
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
    
    static func getToken() -> String? {
        if let token:LoginToken = UserDefaults.standard.codable(forKey: "token") {
            return token.accessToken
        }
        return nil
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
    
    static func request<T: Decodable>(_ url: URLConvertible,
                        method: HTTPMethod = .get,
                        parameters: [String:String] = [:],
                        auth:Bool = true,
                        encoding: ParameterEncoding = URLEncoding.default,
                        decoder: JSONDecoder = JSONDecoder(),
                        complete: ((Result<T, RequestError>) -> Void)?) {
        var param = parameters
        if auth {
            param["access_key"] = getToken()
        }
        param = sign(for: param)
        AF.request(url,method: method,parameters: param,encoding: encoding).responseData { response in
            switch response.result {
            case .success(let data):
                let json = JSON(data)
                let errorCode = json["code"].intValue
                if errorCode != 0 {
                    print(errorCode)
                    complete?(.failure(.statusFail(code:errorCode)))
                    return
                }
                
                if let data = try? json["data"].rawData(),
                   let object = try? decoder.decode(T.self, from: data) {
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
    
    static func verifyLoginQR(code: String,handler: ((LoginState)->Void)?=nil) {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        request(EndPoint.verifyQR,
                method: .post,parameters: ["auth_code":code],auth: false,decoder: decoder) {
            (result:Result<LoginToken, RequestError>) in
            switch result {
            case .success(let res):
                handler?(.success(token: res))
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
    

}

extension UserDefaults {
    func set<Element: Codable>(value: Element, forKey key: String) {
        let data = try? JSONEncoder().encode(value)
        UserDefaults.standard.setValue(data, forKey: key)
    }
    func codable<Element: Codable>(forKey key: String) -> Element? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        let element = try? JSONDecoder().decode(Element.self, from: data)
        return element
    }
}
