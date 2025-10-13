//
//  WebRequest+WbiSign.swift
//  BilibiliLive
//
//  Created by yicheng on 1/12/2024.
//

import Alamofire
import CryptoKit
import Foundation
import SwiftyJSON

extension WebRequest {
    static func addWbiSign(method: HTTPMethod = .get,
                           url: URLConvertible,
                           parameters: Parameters = [:],
                           onComplete: @escaping (String?) -> Void)
    {
        do {
            let urlObj = try url.asURL()
            if method == .get {
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
        // WebId Cache
        class WebIdCache {
            var webId: String?
            static let shared = WebIdCache()
        }

        func getWebId(completion: @escaping (String?) -> Void) {
            if let cached = WebIdCache.shared.webId {
                completion(cached)
                return
            }

            // Generate random visit_id (16 char lowercase hex string)
            let visitId = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(16).lowercased()
            let urlString = "https://live.bilibili.com/p/eden/area-tags?parentAreaId=2&areaId=0&visit_id=\(visitId)"

            guard let url = URL(string: urlString) else {
                completion(nil)
                return
            }

            var request = URLRequest(url: url)
            request.setValue(Keys.userAgent, forHTTPHeaderField: "User-Agent")
            request.setValue(Keys.liveReferer, forHTTPHeaderField: "Referer")

            if let cookies = HTTPCookieStorage.shared.cookies(for: url) {
                let cookieHeaders = HTTPCookie.requestHeaderFields(with: cookies)
                for (key, value) in cookieHeaders {
                    request.setValue(value, forHTTPHeaderField: key)
                }
            }

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                guard let data = data,
                      let html = String(data: data, encoding: .utf8),
                      error == nil
                else {
                    completion(nil)
                    return
                }

                do {
                    // Look for window._render_data_ = {"access_id":"..."}
                    let regex = try NSRegularExpression(pattern: #"window\._render_data_\s*=\s*\{\"access_id\":\"([^\"]+)\""#, options: [])
                    if let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                       let range = Range(match.range(at: 1), in: html)
                    {
                        let accessId = String(html[range])
                        WebIdCache.shared.webId = accessId
                        completion(accessId)
                        return
                    }
                } catch {}

                completion(nil)
            }
            task.resume()
        }

        func getMixinKey(orig: String) -> String {
            let mixinKeyEncTab = [
                46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35, 27, 43, 5, 49,
                33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13, 37, 48, 7, 16, 24, 55, 40,
                61, 26, 17, 0, 1, 60, 51, 30, 4, 22, 25, 54, 21, 56, 59, 6, 63, 57, 62, 11,
                36, 20, 34, 44, 52,
            ]
            return String(mixinKeyEncTab.map { orig[orig.index(orig.startIndex, offsetBy: $0)] }.prefix(32))
        }

        func encWbi(params: [String: Any], imgKey: String, subKey: String) -> [String: Any] {
            var params = params
            let mixinKey = getMixinKey(orig: imgKey + subKey)
            let currTime = Int(Date().timeIntervalSince1970)
            params["wts"] = currTime

            // Keep parameters as sorted array for query generation
            let sortedParams = params.sorted { $0.key < $1.key }

            // Generate query string directly from sorted array
            let query = sortedParams
                .map { key, value in
                    let filteredValue = String(describing: value).filter { !"!'()*".contains($0) }
                    return "\(key)=\(filteredValue)"
                }
                .joined(separator: "&")

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

        getWbiKeys { result in
            switch result {
            case let .success(keys):
                getWebId { webId in
                    let spdParam = param.components(separatedBy: "&")
                    var spdDicParam = [String: String]()
                    for pair in spdParam {
                        let components = pair.components(separatedBy: "=")
                        if components.count == 2 {
                            // URL decode the parameter value
                            let decodedValue = components[1].removingPercentEncoding ?? components[1]
                            spdDicParam[components[0]] = decodedValue
                        }
                    }

                    // Add w_webid parameter
                    if let webId = webId {
                        spdDicParam["w_webid"] = webId
                    }

                    let signedParams = encWbi(params: spdDicParam, imgKey: keys.imgKey, subKey: keys.subKey)

                    // Correct parameter ordering (reference: bilibili-plus)
                    let wbiKeys = ["w_webid", "w_rid", "wts"]
                    var orderedParams = signedParams
                        .filter { !wbiKeys.contains($0.key) }
                        .sorted { $0.key < $1.key }
                        .map { "\($0.key)=\($0.value)" }

                    // Append WBI parameters in fixed order
                    for key in wbiKeys {
                        if let value = signedParams[key] {
                            orderedParams.append("\(key)=\(value)")
                        }
                    }

                    let query = orderedParams.joined(separator: "&")
                    completion(query)
                }
            case let .failure(error):
                print("Error getting keys: \(error)")
                completion(nil)
            }
        }
    }
}
