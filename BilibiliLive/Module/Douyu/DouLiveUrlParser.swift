//
//  DouyuCateViewController.swift
//  BilibiliLive
//
//  Created by yicheng on 2023/4/5.
//

// from https://github.com/xjbeta/iina-plus/blob/master/IINA%2B/Utils/VideoDecoder/Douyu.swift

import Alamofire
import CryptoKit
import JavaScriptCore
import SwiftyJSON

enum DouLiveUrlParser {
    enum DouLiveError: Error {
        case douyuNotFoundRoomId
        case jsonNotFind
    }

    static func liveInfo(_ id: Int) async throws {
        let data = try await AF.request("https://www.douyu.com/betard/\(id)").serializingData().result.get()
        let json = JSON(data)
        print(json)
        return
    }

    static func liveURL(_ id: Int) async throws -> String {
        let context = try await getDouyuHtml(id: id)!
        let json = try await getDouyuUrl(id, jsContext: context)
        print(json)
        let rtmp_live = json["data"]["rtmp_live"].stringValue
        let rtmp_url = json["data"]["rtmp_url"].stringValue
        let url = "\(rtmp_url)/\(rtmp_live)"
        return url
    }

    /*
     {
       "error" : 0,
       "data" : {
         "rtc_stream_url" : "",
         "p2p" : 2,
         "multirates" : [
           {
             "diamondFan" : 0,
             "highBit" : 1,
             "bit" : 3912,
             "name" : "原画1080P30",
             "rate" : 0
           },
           {
             "diamondFan" : 0,
             "highBit" : 0,
             "bit" : 900,
             "name" : "高清",
             "rate" : 2
           }
         ],
         "smt" : 0,
         "streamStatus" : 1,
         "room_id" : 4262033,
         "rtc_stream_config" : "",
         "p2pMeta" : null,
         "online" : 0,
         "p2pCids" : "",
         "mixedCDN" : "",
         "rtmp_live" : "4262033r62gPZ2gp.flv?wsAuth=e61da0a495d435f2a4154e6dfc056326&token=web-h5-0-4262033-55a56bbee5a4c5ef5224e9ded5fe9bcd784a195df42b1a4e&logo=0&expire=0&did=2e813b1adb6d1abead01382408cab87b&ver=Douyu_221111905&pt=2&st=0&origin=tct&mix=0&isp=",
         "rtmp_cdn" : "tct-h5",
         "pictureQualitySwitch" : 1,
         "rateSwitch" : 1,
         "h265_p2p" : 0,
         "client_ip" : "106.122.171.61",
         "isPassPlayer" : 0,
         "is_mixed" : false,
         "cdnsWithName" : [
           {
             "name" : "备用线路5",
             "isH265" : false,
             "cdn" : "tct-h5"
           }
         ],
         "p2pCid" : 0,
         "rtmp_url" : "https:\/\/tc-tct.douyucdn2.cn\/dyliveflv3a",
         "player_1" : "",
         "h265_p2p_cid" : 0,
         "mixed_live" : "",
         "inNA" : 0,
         "h265_p2p_cids" : "",
         "mixed_url" : "",
         "acdn" : "",
         "eticket" : null,
         "av1_url" : "",
         "rate" : 0
       },
       "msg" : "ok"
     }
      */

    static func getDouyuHtml(id: Int) async throws -> JSContext? {
        let html = try await AF.request("http://douyu.com/\(id)").serializingString().result.get()
        let jsContext = douyuJSContext(html)
        return jsContext
    }

    static func douyuJSContext(_ text: String) -> JSContext? {
        var text = text

        let start = #"<script type="text/javascript">"#
        let end = #"</script>"#

        var scriptTexts = [String]()

        while text.contains(start) {
            let js = text.subString(from: start, to: end)
            scriptTexts.append(js)
            text = text.subString(from: start)
        }

        guard let context = JSContext(),
              let cryptoPath = Bundle.main.path(forResource: "crypto-js", ofType: "js"),
              let cryptoData = FileManager.default.contents(atPath: cryptoPath),
              let cryptoJS = String(data: cryptoData, encoding: .utf8),
              // ?.subString(from: #"}(this,function(){"#, to: #"return CryptoJS;"#),
              let signJS = scriptTexts.first(where: { $0.contains("ub98484234") })
        else {
            return nil
        }
        context.name = "DouYin Sign"
        context.evaluateScript(cryptoJS)
        context.evaluateScript(signJS)

        return context
    }

    static func getDouyuUrl(_ roomID: Int, rate: Int = 0, jsContext: JSContext) async throws -> JSON {
        let time = Int(Date().timeIntervalSince1970)
        let didStr: String = {
            let time = UInt32(NSDate().timeIntervalSinceReferenceDate)
            srand48(Int(time))
            let random = "\(drand48())"
            return Insecure.MD5.hash(data: Data(random.utf8)).map { String(format: "%02hhx", $0) }.joined()
        }()

        guard let sign = jsContext.evaluateScript("ub98484234(\(roomID), '\(didStr)', \(time))").toString(),
              let v = jsContext.evaluateScript("vdwdae325w_64we").toString()
        else {
            throw DouLiveError.jsonNotFind
        }

        let pars = ["v": v,
                    "did": didStr,
                    "tt": time,
                    "sign": sign.subString(from: "sign="),
                    "cdn": "ali-h5",
                    "rate": "\(rate)",
                    "ver": "Douyu_221111905",
                    "iar": "0",
                    "ive": "0"] as [String: Any]

        let data = try await AF.request("https://www.douyu.com/lapi/live/getH5Play/\(roomID)", method: .post, parameters: pars).serializingData().result.get()
        let json = JSON(data)
        print(json)
        return json
    }
}

fileprivate extension String {
    func subString(from startString: String, to endString: String) -> String {
        var str = self
        if let startIndex = range(of: startString)?.upperBound {
            str.removeSubrange(str.startIndex..<startIndex)
            if let endIndex = str.range(of: endString)?.lowerBound {
                str.removeSubrange(endIndex..<str.endIndex)
                return str
            }
        }
        return ""
    }

    func subString(from startString: String) -> String {
        var str = self
        if let startIndex = range(of: startString)?.upperBound {
            str.removeSubrange(self.startIndex..<startIndex)
            return str
        }
        return ""
    }
}
