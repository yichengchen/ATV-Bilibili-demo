//
//  LoginViewController.swift
//  BilibiliLive
//
//  Created by Etan Chen on 2021/3/28.
//


import Foundation

class CookieHandler {
    
    static let shared: CookieHandler = CookieHandler()
    
    let defaults = UserDefaults.standard
    let cookieStorage = HTTPCookieStorage.shared
    
    func getCookie(forURL url: String) -> [HTTPCookie] {
        let computedUrl = URL(string: url)
        let cookies = cookieStorage.cookies(for: computedUrl!) ?? []
        
        return cookies
    }
    
    func backupCookies() -> Void {
        var cookieDict = [String : AnyObject]()
        for cookie in cookieStorage.cookies ?? [] {
            cookieDict[cookie.name] = cookie.properties as AnyObject?
        }
        
        defaults.set(cookieDict, forKey: "SavedCookie")
    }
    
    func restoreCookies() {
        if let cookieDictionary = defaults.dictionary(forKey: "SavedCookie") {
            for (_, cookieProperties) in cookieDictionary {
                if let cookie = HTTPCookie(properties: cookieProperties as! [HTTPCookiePropertyKey : Any] ) {
                    cookieStorage.setCookie(cookie)
                }
            }
        }
    }
}
