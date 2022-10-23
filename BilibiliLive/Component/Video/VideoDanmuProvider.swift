//
//  VideoDanmuProvider.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/8/19.
//

import Alamofire
import Foundation
import SwiftyXMLParser
import UIKit

struct Danmu: Codable {
    var time: TimeInterval
    var mode: Int
    var fontSize: Int
    var color: Int
    var text: String

    init(_ attr: String, str: String) {
        text = str
        let attrs: [String] = attr.components(separatedBy: ",")
        time = TimeInterval(attrs[0])!
        mode = Int(attrs[1])!
        fontSize = Int(attrs[2])!
        color = Int(attrs[3])!
    }
}

class VideoDanmuProvider {
    var cid: Int!
    private var allDanmus = [Danmu]()
    private var playingDanmus = [Danmu]()

    var onShowDanmu: ((DanmakuTextCellModel) -> Void)?

    func fetchDanmuData() {
        AF.request("https://api.bilibili.com/x/v1/dm/list.so?oid=\(cid!)").responseString(encoding: .utf8) {
            [weak self] resp in
            guard let self = self else { return }
            switch resp.result {
            case let .success(data):
                self.parseDanmuData(data: data)
            case let .failure(err):
                print(err)
            }
        }
    }

    func parseDanmuData(data: String) {
        guard let xml = try? XML.parse(data) else { return }
        allDanmus = xml["i"]["d"].all?.map { xml in
            Danmu(xml.attributes["p"]!, str: xml.text!)
        } ?? []
        allDanmus.sort {
            $0.time < $1.time
        }
        print("danmu count: \(allDanmus.count)")
        playingDanmus = allDanmus
    }

    func playerTimeChange(time: TimeInterval) {
        let advanceTime = time.advanced(by: 1)
        while let first = playingDanmus.first, first.time <= advanceTime {
            let danmu = playingDanmus.removeFirst()
            let offset = advanceTime - danmu.time
            let model = DanmakuTextCellModel(str: danmu.text)
            model.color = UIColor(hex: UInt32(danmu.color))
            switch danmu.mode {
            case 1, 2, 3:
                model.type = .floating
            case 4:
                model.type = .bottom
            case 5:
                model.type = .top
            default:
                continue
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + offset) {
                [weak self] in
                self?.onShowDanmu?(model)
            }
        }
    }
}
