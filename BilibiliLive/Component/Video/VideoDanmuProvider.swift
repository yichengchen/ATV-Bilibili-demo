//
//  VideoDanmuProvider.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/8/19.
//

import Alamofire
import Combine
import Foundation
import SwiftyXMLParser
import UIKit

struct Danmu: Codable {
    var text: String
    var time: TimeInterval
    var mode: Int32 = 1
    var fontSize: Int32 = 25
    var color: UInt32 = 16_777_215
    var isUp: Bool = false
    var aiLevel: Int32 = 0

    init(dm: DanmakuElem) {
        text = dm.content
        time = TimeInterval(dm.progress / 1000)
        mode = dm.mode
        fontSize = dm.fontsize
        color = dm.color
        aiLevel = dm.weight
    }

    init(upDm dm: CommandDm) {
        text = dm.content
        time = TimeInterval(dm.progress / 1000)
        isUp = true
    }
}

class VideoDanmuProvider: DanmuProviderProtocol {
    var cid: Int!
    private var allDanmus = [Danmu]()
    private var playingDanmus = [Danmu]()

    let observerPlayerTime: Bool = true
    let onSendTextModel = PassthroughSubject<DanmakuTextCellModel, Never>()

    var onShowDanmu: ((DanmakuTextCellModel) -> Void)?

    private var upDanmus = [Danmu]()
    private static let segmentMinCap = 5
    private var segmentDanmus = [Int: [Danmu]](minimumCapacity: segmentMinCap)
    private var segmentStatuses = [Int: Any](minimumCapacity: segmentMinCap)

    private var lastTime: TimeInterval = 0
    private var lastSegmentIdx: Int = 0
    private var upDanmuIdx: Int = 0
    private var danmuIdx: Int = 0

    private let segmentDuration = 60 * 6
    private func getSegmentIdx(time: TimeInterval) -> Int { Int(time) / segmentDuration + 1 }

    func initVideo(cid id: Int, startPos: Int) async {
        cid = id
        upDanmus.removeAll()
        segmentDanmus.removeAll(keepingCapacity: true)
        segmentStatuses.removeAll(keepingCapacity: true)
        lastTime = 0
        lastSegmentIdx = 0
        upDanmuIdx = 0
        danmuIdx = 0

        async let view: () = fetchDanmuView()
        let segmentIdx = getSegmentIdx(time: TimeInterval(startPos))
        segmentStatuses[segmentIdx] = true
        async let list: () = fetchDanmuList(getSegmentIdx(time: TimeInterval(startPos)))
        await view
        await list
    }

    func fetchDanmuView() async {
        var reply: DmWebViewReply
        do {
            reply = try await WebRequest.requestDanmuWebView(cid: cid)
        } catch let err {
            Logger.warn("[dm] cid:\(cid!) requestDanmuWebView error: \(err)")
            return
        }

        var dms = reply.commandDms
            .filter { $0.command == "#UP#" }
            .map { Danmu(upDm: $0) }
        dms.sort { $0.time < $1.time }
        upDanmus = dms

        Logger.debug("[dm] cid:\(cid!) up danmu cnt: \(dms.count)")
    }

    func fetchDanmuList(_ idx: Int) async {
        var reply: DmSegMobileReply
        do {
            reply = try await WebRequest.requestDanmuList(cid: cid, segmentIdx: idx)
        } catch let err {
            segmentStatuses[idx] = nil // 等待下次重试
            Logger.warn("[dm] cid:\(cid!) sidx:\(idx) requestDanmuList error: \(err)")
            return
        }

        var dms = reply.elems
            .filter { $0.mode <= 5 }

        if Settings.enableDanmuFilter {
            dms = dms.filter {
                VideoDanmuFilter.shared.accept($0.content)
            }
        }

        var models = dms
            .map { Danmu(dm: $0) }
        models.sort { $0.time < $1.time }
        segmentDanmus[idx] = models

        Logger.debug("[dm] cid:\(cid!) sidx:\(idx) danmu cnt: \(dms.count)")
    }

    private let advancedDuration = 30 // 提前x秒加载下段弹幕
    private func fetchMoreDanmuInBackground(time: TimeInterval) {
        func fetchDanmuInBackground(_ idx: Int) {
            segmentStatuses[idx] = true
            Task.detached {
                await self.fetchDanmuList(idx)
            }
            Logger.debug("[dm] cid:\(cid!) time:\(Int(time)) fetching sidx:\(idx)")
        }

        let sidx = getSegmentIdx(time: time)

        if segmentStatuses[sidx].isNil() {
            fetchDanmuInBackground(sidx)
        }

        if sidx > 1, segmentStatuses[sidx - 1].isNil(),
           Int(time) % segmentDuration < advancedDuration
        {
            fetchDanmuInBackground(sidx - 1)
        }

        if segmentStatuses[sidx + 1].isNil(),
           segmentDuration - Int(time) % segmentDuration < advancedDuration
        {
            fetchDanmuInBackground(sidx + 1)
        }
    }

    func playerTimeChange(time: TimeInterval) {
        guard cid != nil else { return }

        fetchMoreDanmuInBackground(time: time)
        let sidx = getSegmentIdx(time: time)
        guard let dms = segmentDanmus[sidx] else { return }

        let diff = time - lastTime
        if diff > 5 || diff < 0 {
            danmuIdx = dms.firstIndex(where: { $0.time > time }) ?? dms.count
            upDanmuIdx = upDanmus.firstIndex(where: { $0.time > time }) ?? upDanmus.count
        } else if sidx == lastSegmentIdx + 1 {
            danmuIdx = 0
        }
        lastTime = time
        lastSegmentIdx = sidx

        while upDanmuIdx < upDanmus.count {
            let dm = upDanmus[upDanmuIdx]
            guard dm.time < time else { break }
            upDanmuIdx += 1
            let model = DanmakuTextCellModel(dm: dm)
            onShowDanmu?(model)
            onSendTextModel.send(model)
        }

        while danmuIdx < dms.count {
            let dm = dms[danmuIdx]
            guard dm.time < time else { break }
            danmuIdx += 1
            if dm.aiLevel < Settings.danmuAILevel { continue }
            let model = DanmakuTextCellModel(dm: dm)
            onShowDanmu?(model)
            onSendTextModel.send(model)
        }
    }
}
