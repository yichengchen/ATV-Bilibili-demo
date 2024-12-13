//
//  WebRequest+WbiSign.swift
//  BilibiliLive
//
//  Created by yicheng on 1/12/2024.
//

import Alamofire
import CryptoKit
import SwiftyJSON

extension WebRequest {
    static func addWbiSign(method: HTTPMethod = .get,
                           url: URLConvertible,
                           parameters: Parameters = [:],
                           onComplete: @escaping (String?) -> Void)
    {
        do {
            let urlObj = try url.asURL()
            if urlObj.absoluteString.contains("/wbi/") == true, method == .get {
                var request = URLRequest(url: urlObj)
                request.method = .get
                request = try URLEncoding.queryString.encode(request, with: parameters)
                if let query = request.url?.query(percentEncoded: true) {
                    biliWbiSign(param: query) { res in
                        if let res {
                            let urlString = urlObj.absoluteString + "?" + res
                            onComplete(urlString)
                            return
                        } else {
                            onComplete(nil)
                        }
                    }
                    return
                }
            }
            onComplete(nil)
        } catch {
            onComplete(nil)
        }
    }

    // https://github.com/SocialSisterYi/bilibili-API-collect/blob/master/docs/misc/sign/wbi.md#Swift
    private static func biliWbiSign(param: String, completion: @escaping (String?) -> Void) {
        func getMixinKey(orig: String) -> String {
            return String(mixinKeyEncTab.map { orig[orig.index(orig.startIndex, offsetBy: $0)] }.prefix(32))
        }

        func encWbi(params: [String: Any], imgKey: String, subKey: String) -> [String: Any] {
            var params = params
            let mixinKey = getMixinKey(orig: imgKey + subKey)
            let currTime = round(Date().timeIntervalSince1970)
            params["wts"] = currTime
            params = params.sorted { $0.key < $1.key }.reduce(into: [:]) { $0[$1.key] = $1.value }
            params = params.mapValues { String(describing: $0).filter { !"!'()*".contains($0) } }
            let query = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            let wbiSign = calculateMD5(string: query + mixinKey)
            params["w_rid"] = wbiSign
            return params
        }

        func getWbiKeys(completion: @escaping (Result<(imgKey: String, subKey: String), Error>) -> Void) {
            class Cache {
                var imgKey: String?
                var subKey: String?
                var lastUpdate: Date?

                static let shared = Cache()
            }

            if let imgKey = Cache.shared.imgKey,
               let subKey = Cache.shared.subKey,
               let lastUpdate = Cache.shared.lastUpdate,
               Date().timeIntervalSince(lastUpdate) < 60 * 60 * 12,
               Calendar.current.isDate(Date(), inSameDayAs: lastUpdate)
            {
                completion(.success((imgKey, subKey)))
                return
            }

            let headers: HTTPHeaders = [
                "User-Agent": Keys.userAgent,
                "Referer": Keys.referer,
            ]

            AF.request("https://api.bilibili.com/x/web-interface/nav", headers: headers).responseData { response in
                switch response.result {
                case let .success(value):
                    let json = JSON(value)
                    let imgURL = json["data"]["wbi_img"]["img_url"].string ?? ""
                    let subURL = json["data"]["wbi_img"]["sub_url"].string ?? ""
                    let imgKey = imgURL.components(separatedBy: "/").last?.components(separatedBy: ".").first ?? ""
                    let subKey = subURL.components(separatedBy: "/").last?.components(separatedBy: ".").first ?? ""
                    Cache.shared.imgKey = imgKey
                    Cache.shared.subKey = subKey
                    Cache.shared.lastUpdate = Date()
                    completion(.success((imgKey, subKey)))
                case let .failure(error):
                    completion(.failure(error))
                }
            }
        }

        func calculateMD5(string: String) -> String {
            let messageData = string.data(using: .utf8)!
            let digestData = Insecure.MD5.hash(data: messageData)
            let digestHex = String(digestData.map { String(format: "%02hhx", $0) }.joined().prefix(32))
            return digestHex
        }

        let mixinKeyEncTab = [
            46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35, 27, 43, 5, 49,
            33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13, 37, 48, 7, 16, 24, 55, 40,
            61, 26, 17, 0, 1, 60, 51, 30, 4, 22, 25, 54, 21, 56, 59, 6, 63, 57, 62, 11,
            36, 20, 34, 44, 52,
        ]

        getWbiKeys { result in
            switch result {
            case let .success(keys):
                let spdParam = param.components(separatedBy: "&")
                var spdDicParam = [String: String]()
                spdParam.forEach { pair in
                    let components = pair.components(separatedBy: "=")
                    if components.count == 2 {
                        spdDicParam[components[0]] = components[1]
                    }
                }

                let signedParams = encWbi(params: spdDicParam, imgKey: keys.imgKey, subKey: keys.subKey)
                let query = signedParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
                completion(query)
            case let .failure(error):
                print("Error getting keys: \(error)")
                completion(nil)
            }
        }
    }
}
