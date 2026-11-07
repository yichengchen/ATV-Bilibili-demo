//
//  LiveDanmuHistory.swift
//  BilibiliLive
//
//  直播间弹幕历史：仅保存当次开播（以 live_time 区分场次）的弹幕，并持久化到本地。
//

import Combine
import Foundation
import SwiftyJSON
import UIKit

struct LiveDanmuHistoryItem: Codable, Hashable {
    let uid: Int
    let name: String
    let face: String?
    let text: String
    /// unix 时间戳（秒）
    let time: TimeInterval
    var superChatPrice: Int?

    var isSuperChat: Bool { superChatPrice != nil }
    var faceURL: URL? {
        guard let face, !face.isEmpty, let url = URL(string: face) else { return nil }
        return url.addSchemeIfNeed()
    }

    /// 用于与 gethistory 接口返回的数据去重（接口时间只精确到秒）
    var dedupKey: String { "\(uid)|\(Int(time))|\(text)" }
}

final class LiveDanmuHistoryStore {
    enum Change {
        case appended(Range<Int>)
        case reloaded
    }

    static let maxCount = 1000
    /// 超出上限时额外删除的条数
    private static let trimCount = 200

    let roomID: Int
    /// 当次开播标识（get_info 返回的 live_time）
    let sessionKey: String
    private(set) var items = [LiveDanmuHistoryItem]()
    let onChange = PassthroughSubject<Change, Never>()

    private var keys = Set<String>()
    private var saveWorkItem: DispatchWorkItem?
    private var cancellable: AnyCancellable?
    private static let ioQueue = DispatchQueue(label: "LiveDanmuHistoryStore.io")

    private struct Archive: Codable {
        let sessionKey: String
        let items: [LiveDanmuHistoryItem]
    }

    init(roomID: Int, sessionKey: String) {
        self.roomID = roomID
        self.sessionKey = sessionKey
        loadFromDisk()
        cancellable = NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in self?.saveNow() }
        Self.cleanExpiredFiles()
    }

    deinit {
        saveNow()
    }

    // MARK: - Mutations (main thread)

    func append(_ item: LiveDanmuHistoryItem) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard keys.insert(item.dedupKey).inserted else { return }
        items.append(item)
        if trimIfNeeded() {
            onChange.send(.reloaded)
        } else {
            onChange.send(.appended(items.count - 1..<items.count))
        }
        scheduleSave()
    }

    /// 合并服务端返回的近期弹幕（补全进入直播间之前 / 离开期间的弹幕）
    func merge(_ newItems: [LiveDanmuHistoryItem]) {
        dispatchPrecondition(condition: .onQueue(.main))
        let fresh = newItems.filter { keys.insert($0.dedupKey).inserted }
        guard !fresh.isEmpty else { return }
        items.append(contentsOf: fresh)
        items.sort { $0.time < $1.time }
        trimIfNeeded()
        onChange.send(.reloaded)
        scheduleSave()
    }

    @discardableResult
    private func trimIfNeeded() -> Bool {
        guard items.count > Self.maxCount else { return false }
        // 超出上限时一次多删一批，避免满载后每条弹幕都触发整表重载
        let removeCount = min(items.count, items.count - Self.maxCount + Self.trimCount)
        items.prefix(removeCount).forEach { keys.remove($0.dedupKey) }
        items.removeFirst(removeCount)
        return true
    }

    // MARK: - Persistence

    private static var directory: URL {
        // tvOS 只允许写入 Caches 目录
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LiveDanmuHistory", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var fileURL: URL {
        Self.directory.appendingPathComponent("\(roomID).json")
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: fileURL),
              let archive = try? JSONDecoder().decode(Archive.self, from: data)
        else { return }
        // 不是同一场直播，丢弃旧数据
        guard archive.sessionKey == sessionKey else {
            try? FileManager.default.removeItem(at: fileURL)
            return
        }
        items = archive.items
        keys = Set(items.map(\.dedupKey))
        trimIfNeeded()
    }

    private func scheduleSave() {
        guard saveWorkItem == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            self?.saveNow()
        }
        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
    }

    func saveNow() {
        saveWorkItem?.cancel()
        saveWorkItem = nil
        guard !items.isEmpty else { return }
        let archive = Archive(sessionKey: sessionKey, items: items)
        let url = fileURL
        Self.ioQueue.async {
            do {
                let data = try JSONEncoder().encode(archive)
                try data.write(to: url, options: .atomic)
            } catch {
                Logger.warn("save live danmu history fail: \(error)")
            }
        }
    }

    /// 清理 3 天未更新的直播间记录
    private static func cleanExpiredFiles() {
        ioQueue.async {
            let fm = FileManager.default
            guard let files = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
            let expire = Date().addingTimeInterval(-3 * 24 * 3600)
            for file in files {
                let date = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                if let date, date < expire {
                    try? fm.removeItem(at: file)
                }
            }
        }
    }

    // MARK: - Remote

    /// 拉取服务端近期弹幕（接口仅返回最近约 10 条，未登录时可能为空），只保留本场开播之后的
    func loadRemoteHistory() async {
        guard let list = try? await WebRequest.requestLiveDanmuHistory(roomID: roomID), !list.isEmpty else { return }
        let start = Self.parseBeijingTime(sessionKey)
        let filtered = list.filter { start == nil || $0.time >= start! }
        await MainActor.run {
            merge(filtered)
        }
    }

    static let beijingFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    static func parseBeijingTime(_ str: String?) -> TimeInterval? {
        guard let str else { return nil }
        return beijingFormatter.date(from: str)?.timeIntervalSince1970
    }
}

// MARK: - Parse

extension LiveDanmuHistoryItem {
    /// 解析 websocket DANMU_MSG
    init?(danmuMsgInfo info: JSON) {
        guard let text = info[1].string else { return nil }
        let user = info[2]
        let extra = info[0][15]
        let ts = info[0][4].double.map { $0 / 1000 } ?? Date().timeIntervalSince1970
        let name = extra["user"]["base"]["name"].string ?? user[1].stringValue
        self.init(uid: user[0].intValue,
                  name: name,
                  face: extra["user"]["base"]["face"].string,
                  text: text,
                  time: ts,
                  superChatPrice: nil)
    }

    /// 解析 websocket SUPER_CHAT_MESSAGE 的 data
    init?(superChat data: JSON) {
        guard let text = data["message"].string else { return nil }
        let ts = data["start_time"].double ?? data["ts"].double ?? Date().timeIntervalSince1970
        self.init(uid: data["uid"].intValue,
                  name: data["user_info"]["uname"].stringValue,
                  face: data["user_info"]["face"].string,
                  text: text,
                  time: ts,
                  superChatPrice: data["price"].intValue)
    }

    /// 解析 gethistory 接口的单条数据
    init?(history json: JSON) {
        guard let text = json["text"].string else { return nil }
        let ts = json["check_info"]["ts"].double
            ?? LiveDanmuHistoryStore.parseBeijingTime(json["timeline"].string)
            ?? Date().timeIntervalSince1970
        let name = json["nickname"].string ?? json["user"]["base"]["name"].stringValue
        self.init(uid: json["uid"].int ?? json["user"]["uid"].intValue,
                  name: name,
                  face: json["user"]["base"]["face"].string,
                  text: text,
                  time: ts,
                  superChatPrice: nil)
    }
}

extension WebRequest.EndPoint {
    static let liveDanmuHistory = "https://api.live.bilibili.com/xlive/web-room/v1/dM/gethistory"
}

extension WebRequest {
    static func requestLiveDanmuHistory(roomID: Int) async throws -> [LiveDanmuHistoryItem] {
        let json = try await requestJSON(url: EndPoint.liveDanmuHistory, parameters: ["roomid": roomID, "room_type": 0])
        return json["room"].arrayValue.compactMap { LiveDanmuHistoryItem(history: $0) }
    }
}
