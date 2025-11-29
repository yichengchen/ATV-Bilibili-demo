//
//  CookieManager.swift
//  BilibiliLive
//
//  Created by Etan Chen on 2021/3/28.
//

import Foundation

struct StoredCookie: Codable, Equatable {
    let name: String
    let value: String
    let domain: String
    let path: String
    let expiresDate: Date?
    let isSecure: Bool
    let isHTTPOnly: Bool

    init(cookie: HTTPCookie) {
        name = cookie.name
        value = cookie.value
        domain = cookie.domain
        path = cookie.path
        expiresDate = cookie.expiresDate
        isSecure = cookie.isSecure
        isHTTPOnly = cookie.isHTTPOnly
    }

    func makeHTTPCookie() -> HTTPCookie? {
        var properties: [HTTPCookiePropertyKey: Any] = [
            .domain: domain,
            .name: name,
            .path: path,
            .value: value,
        ]
        if let expiresDate {
            properties[.expires] = expiresDate
        }
        if isSecure {
            properties[.secure] = "TRUE"
        }
        properties[HTTPCookiePropertyKey("HttpOnly")] = isHTTPOnly ? "TRUE" : "FALSE"
        return HTTPCookie(properties: properties)
    }
}

class CookieHandler {
    static let shared: CookieHandler = .init()

    let cookieStorage = HTTPCookieStorage.shared

    func getCookie(forURL url: String) -> [HTTPCookie] {
        guard let computedUrl = URL(string: url) else {
            Logger.warn("CookieHandler: Invalid URL string: \(url)")
            return []
        }
        let cookies = cookieStorage.cookies(for: computedUrl) ?? []
        return cookies
    }

    func currentStoredCookies() -> [StoredCookie] {
        cookieStorage.cookies?.map(StoredCookie.init) ?? []
    }

    func replaceCookies(with cookies: [StoredCookie]) {
        removeCookie()
        cookies.compactMap { $0.makeHTTPCookie() }.forEach { cookieStorage.setCookie($0) }
    }

    func backupCookies() {
        AccountManager.shared.syncActiveAccountCookies()
    }

    func removeCookie() {
        for cookie in cookieStorage.cookies ?? [] {
            cookieStorage.deleteCookie(cookie)
        }
    }

    func saveCookie(list: [HTTPCookie], syncWithAccount: Bool = true) {
        removeCookie()
        list.forEach({ cookieStorage.setCookie($0) })
        if syncWithAccount {
            backupCookies()
        }
    }

    func csrf() -> String? {
        let cookies = getCookie(forURL: "https://bilibili.com")
        return cookies.first(where: { $0.name == "bili_jct" })?.value
    }

    func buvid3() -> String {
        let cookies = getCookie(forURL: "https://bilibili.com")
        return cookies.first(where: { $0.name == "buvid3" })?.value ?? ""
    }
}
