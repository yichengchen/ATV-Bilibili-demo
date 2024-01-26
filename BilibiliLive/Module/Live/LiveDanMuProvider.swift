//
//  WSParser.swift
//  BilibiliLive
//
//  Created by Etan on 2021/3/28.
//

import Foundation
import Gzip
import Starscream
import SwiftyJSON

class LiveDanMuProvider {
    private var websocket: WebSocket?
    private var heartBeatTimer: Timer?
    private let roomID: Int
    private var token = ""
    var onDanmu: ((String) -> Void)?
    var onSC: ((String) -> Void)?

    init(roomID: Int) {
        self.roomID = roomID
    }

    deinit {
        stop()
    }

    func start() async throws {
        let info = try await WebRequest.requestDanmuServerInfo(roomID: roomID)
        guard let server = info.host_list.first else {
            Logger.info("Get room server info Fail")
            return
        }
        Logger.info("Get room server info \(server.host):\(server.wss_port)")
        token = info.token
        var request = URLRequest(url: URL(string: "wss://\(server.host):\(server.wss_port)/sub")!)
        request.allHTTPHeaderFields = ["User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/107.0.0.0 Safari/537.36",
                                       "Referer": "https://live.bilibili.com"]
        websocket = WebSocket(request: request)
        websocket?.delegate = self
        websocket?.connect()
    }

    func stop() {
        websocket?.disconnect()
        heartBeatTimer?.invalidate()
    }

    private func setupHeartBeat() {
        heartBeatTimer = Timer.scheduledTimer(timeInterval: 30, target: self, selector: #selector(sendHeartBeat), userInfo: nil, repeats: true)
        sendHeartBeat()
    }

    private func getHeartbeatPackage() -> Data {
        let data = "[object Object]".data(using: .utf8)!
        let header = LiveWSHeader.encode(operatorType: .heartBeat, data: data)
        return header
    }

    @objc private func sendHeartBeat() {
        let data = getHeartbeatPackage()
        websocket?.write(data: data)
    }

    private func sendJoinLiveRoom() {
        let mid = ApiRequest.getToken()?.mid ?? 0
        let package = AuthPackage(uid: mid, roomid: roomID, buvid: CookieHandler.shared.buvid3(), key: token)
        let data = LiveWSHeader.encode(operatorType: .auth, data: package.encode())
        websocket?.write(data: data)
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
            } else if let data = (contentData as NSData).decompressBrotli() {
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
                    if let str = json["info"][1].string { onDanmu?(str) }
                case "DM_INTERACTION":
                    guard let data = json["data"]["data"].string else { return }
                    let comboArr = JSON(parseJSON: data)["combo"]
                    for combo in comboArr.arrayValue {
                        if let str = combo["content"].string, let cnt = combo["cnt"].int {
                            onDanmu?("\(str) x\(cnt)")
                        }
                    }
                case "SUPER_CHAT_MESSAGE":
                    if let str = json["data"]["message"].string { onSC?(str) }
                default:
                    break
                }
            }
    }

    private func getDanMu(data: [JSON]) -> [String] {
        return data.filter {
            $0["cmd"].stringValue == "DANMU_MSG"
        }.compactMap { json in
            json["info"][1].string
        }
    }
}

// MARK: WebSocketDelegate

extension LiveDanMuProvider: WebSocketDelegate {
    func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocketClient) {
        switch event {
        case .connected:
            Logger.info("websocket connected")
            sendJoinLiveRoom()
            setupHeartBeat()
        case .disconnected:
            Logger.info("websocket disconnected")
        case let .binary(data):
            parseData(data: data)
        case let .error(error):
            Logger.info("websocket error: \(String(describing: error))")
        default:
            break
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
