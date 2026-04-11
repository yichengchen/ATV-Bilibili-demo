//
//  TvOTTSigner.swift
//  BilibiliLive
//
//  Created by OpenAI on 2026/4/9.
//

import CryptoKit
import Foundation

enum TvOTTSigner {
    static let appKey = "4409e2ce8ffd12b8"
    static let appSec = "59b43e04ad6965f34319062b478f83dd"
    static let mobiApp = "android_tv_yst"
    static let build = "1606"
    static let platform = "android"
    static let userAgent = "tv.danmaku.bili/\(build) CFNetwork"

    static func signGETQuery(_ parameters: [String: String] = [:], accessKey: String? = nil) -> String {
        var signedParameters = parameters
        if signedParameters["platform"] == nil {
            signedParameters["platform"] = platform
        }
        signedParameters["mobi_app"] = mobiApp
        signedParameters["appkey"] = appKey
        signedParameters["build"] = build
        if signedParameters["ts"] == nil {
            signedParameters["ts"] = String(Int(Date().timeIntervalSince1970))
        }
        if let accessKey, !accessKey.isEmpty {
            signedParameters["access_key"] = accessKey
        }

        let query = encodeQuery(signedParameters)
        let sign = md5("\(query)\(appSec)")
        return "\(query)&sign=\(sign)"
    }

    static func signedURL(endpoint: String,
                          parameters: [String: String] = [:],
                          accessKey: String? = nil) -> URL?
    {
        guard var components = URLComponents(string: endpoint) else { return nil }
        components.percentEncodedQuery = signGETQuery(parameters, accessKey: accessKey)
        return components.url
    }

    private static func encodeQuery(_ parameters: [String: String]) -> String {
        parameters
            .sorted { $0.key < $1.key }
            .map { "\(percentEncode($0.key))=\(percentEncode($0.value))" }
            .joined(separator: "&")
    }

    private static func percentEncode(_ string: String) -> String {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~")
        var output = ""
        for scalar in string.unicodeScalars {
            if allowed.contains(scalar) {
                output.append(String(scalar))
                continue
            }

            for byte in String(scalar).utf8 {
                output.append(String(format: "%%%02X", byte))
            }
        }
        return output
    }

    private static func md5(_ string: String) -> String {
        Insecure.MD5
            .hash(data: Data(string.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
