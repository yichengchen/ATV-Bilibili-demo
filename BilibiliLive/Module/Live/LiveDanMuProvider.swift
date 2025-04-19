//
//  LiveDanMuProvider.swift
//  BilibiliLive
//
//  Created by Etan on 2021/3/28.
//

import Combine
import Foundation
@_spi(WebSocket) import Alamofire
import SwiftyJSON

class LiveDanMuProvider: DanmuProviderProtocol {
    let observerPlayerTime = false
    let enableDanmuRemoveDup: Bool
    var onSendTextModel = PassthroughSubject<DanmakuTextCellModel, Never>()

    private var websocket: WebSocketRequest?
    private var heartBeatTimer: Timer?
    private let roomID: Int
    private var token = ""
    private var danmuSet = Set<String>()
    private var danmuSetClearTimer: Timer?
    private let brotliDcompressor = BrotliDecompressor()

    init(roomID: Int, removeDup: Bool) {
        self.roomID = roomID
        enableDanmuRemoveDup = removeDup
    }

    deinit {
        stop()
    }

    func playerTimeChange(time: TimeInterval) {}

    func start() async throws {
        stop()
        let info = try await WebRequest.requestDanmuServerInfo(roomID: roomID)
        guard let server = info.host_list.first else {
            Logger.info("Get room server info Fail")
            return
        }
        Logger.info("Get room server info \(server.host):\(server.wss_port)")
        token = info.token
        var afheaders = HTTPHeaders()
        afheaders.add(.userAgent(Keys.userAgent))
        afheaders.add(HTTPHeader(name: "Referer", value: Keys.referer))

        websocket = AF.webSocketRequest(to: "wss://\(server.host):\(server.wss_port)/sub", headers: afheaders).streamMessageEvents { [weak self] event in
            self?.handleWebsocketEvent(event: event)
        }

        if enableDanmuRemoveDup {
            danmuSetClearTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) {
                [weak self] _ in
                self?.danmuSet.removeAll(keepingCapacity: true)
            }
        }
    }

    func stop() {
        websocket?.close(sending: .normalClosure)
        heartBeatTimer?.invalidate()
        danmuSet.removeAll()
        danmuSetClearTimer?.invalidate()
    }

    private func setupHeartBeat() {
        heartBeatTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true, block: { [weak self] _ in
            self?.sendHeartBeat()
        })
        sendHeartBeat()
    }

    private func getHeartbeatPackage() -> Data {
        let data = "[object Object]".data(using: .utf8)!
        let header = LiveWSHeader.encode(operatorType: .heartBeat, data: data)
        return header
    }

    @objc private func sendHeartBeat() {
        websocket?.send(.data(getHeartbeatPackage()), completionHandler: { _ in })
    }

    private func sendJoinLiveRoom() {
        let mid = ApiRequest.getToken()?.mid ?? 0
        let package = AuthPackage(uid: mid, roomid: roomID, buvid: CookieHandler.shared.buvid3(), key: token)
        let data = LiveWSHeader.encode(operatorType: .auth, data: package.encode())
        websocket?.send(.data(data), completionHandler: { _ in })
    }
}

// MARK: Data parse

extension LiveDanMuProvider {
    private func parseData(data: Data) {
        let header = LiveWSHeader.decode(data: data)
        let contentData = data.subdata(in: Int(header.headerSize)..<Int(header.size))
        let operatorType = OperatorType(rawValue: header.operatorType)
        switch operatorType {
        case nil:
            assertionFailure()
        case .authReply:
            print("get authReply")
        case .heaerBeatReply:
            print("get heaerBeatReply")
        case .normal:
            if header.protocolType == 0 {
                parseNormalData(data: contentData)
            } else if let data = brotliDcompressor.decompressed(compressed: contentData) {
                parseData(data: data)
            } else {
                parseNormalData(data: contentData)
            }
        default:
            print("get", operatorType?.rawValue ?? 0)
        }

        let nextData = data.dropFirst(Int(header.size))
        if nextData.count > header.headerSize {
            parseData(data: Data(nextData))
        }
    }

    private func parseNormalData(data: Data) {
        guard let dataStr = String(data: data, encoding: .utf8) else {
            print("decode fail")
            return
        }
        dataStr.components(separatedBy: CharacterSet.controlCharacters)
            .map { JSON(parseJSON: $0) }
            .forEach { json in
                let cmd = json["cmd"].stringValue
                switch cmd {
                case "DANMU_MSG":
                    if let str = json["info"][1].string {
                        let model = DanmakuTextCellModel(str: str)
                        sentDanmuModel(model)
                    }
                case "DM_INTERACTION":
                    guard let data = json["data"]["data"].string else { return }
                    let comboArr = JSON(parseJSON: data)["combo"]
                    for combo in comboArr.arrayValue {
                        if let str = combo["content"].string {
                            let model = DanmakuTextCellModel(str: str)
                            sentDanmuModel(model)
                        }
                    }
                case "SUPER_CHAT_MESSAGE":
                    if let str = json["data"]["message"].string {
                        let model = DanmakuTextCellModel(str: str)
                        model.type = .top
                        model.displayTime = 60
                        sentDanmuModel(model)
                    }
                default:
                    break
                }
            }
    }

    private func sentDanmuModel(_ model: DanmakuTextCellModel) {
        if enableDanmuRemoveDup {
            if danmuSet.contains(model.text) {
                return
            }
            danmuSet.insert(model.text)
        }
        onSendTextModel.send(model)
    }
}

// MARK: WebSocketDelegate

extension LiveDanMuProvider {
    func handleWebsocketEvent(event: WebSocketRequest.Event<URLSessionWebSocketTask.Message, Never>) {
        switch event.kind {
        case .connected:
            Logger.info("websocket connected")
            sendJoinLiveRoom()
            setupHeartBeat()
        case .disconnected:
            Logger.info("websocket disconnected")
        case let .receivedMessage(message):
            if case let .data(data) = message {
                parseData(data: data)
            }
        default:
            Logger.warn(event)
        }
    }
}

private struct LiveWSHeader {
    var size: UInt32
    var headerSize: UInt16 = .init(UInt16(16).bigEndian)
    var protocolType: UInt16 = .init(UInt16(1).bigEndian)
    var operatorType: UInt32
    var sequence: UInt32 = .init(UInt32(1).bigEndian)

    static func encode(operatorType: OperatorType, data: Data) -> Data {
        let size = UInt32(data.count) + UInt32(MemoryLayout<LiveWSHeader>.size)
        let header = LiveWSHeader(size: size.bigEndian, operatorType: operatorType.value)
        var headerData = withUnsafePointer(to: header) { p in
            return Data(bytes: p, count: MemoryLayout<LiveWSHeader>.size)
        }
        headerData.append(data)
        return headerData
    }

    static func decode(data: Data) -> LiveWSHeader {
        var header = (data as NSData).bytes.bindMemory(to: LiveWSHeader.self, capacity: data.count).pointee
        header.headerSize = header.headerSize.bigEndian
        header.protocolType = header.protocolType.bigEndian
        header.operatorType = header.operatorType.bigEndian
        header.sequence = header.sequence.bigEndian
        header.size = header.size.bigEndian
        return header
    }
}

private enum OperatorType: UInt32 {
    case heartBeat = 2
    case heaerBeatReply = 3
    case normal = 5
    case auth = 7
    case authReply = 8

    var value: UInt32 { rawValue.bigEndian }
}

private struct AuthPackage: Encodable {
    let uid: Int
    let roomid: Int
    let protover = 3
    let buvid: String
    let platform = "web"
    let type = 2
    let key: String

    func encode() -> Data {
        try! JSONEncoder().encode(self)
    }
}

extension WebRequest.EndPoint {
    static let getDanmuInfo = "https://api.live.bilibili.com/xlive/web-room/v1/index/getDanmuInfo"
}

extension WebRequest {
    struct DanmuServerInfo: Codable {
        struct Host: Codable {
            let host: String
            let port: Int
            let wss_port: Int
            let ws_port: Int
        }

        let token: String
        let host_list: [Host]
    }

    static func requestDanmuServerInfo(roomID: Int) async throws -> DanmuServerInfo {
        let resp: DanmuServerInfo = try await request(url: EndPoint.getDanmuInfo, parameters: ["id": roomID])
        return resp
    }
}
