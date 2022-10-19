//
//  WSParser.swift
//  BilibiliLive
//
//  Created by Etan on 2021/3/28.
//

import Foundation
import SwiftyJSON
import Starscream
import Gzip


class LiveDanMuProvider {
    private var websocket: WebSocket?
    private var heartBeatTimer: Timer?
    private let roomID: Int
    
    var onDanmu: ((String)->Void)? = nil
    var onSC: ((String)->Void)? = nil
    
    init(roomID: Int) {
        self.roomID = roomID
    }
    
    deinit {
        stop()
    }
    
    func start() {
        let request = URLRequest(url: URL(string: "ws://broadcastlv.chat.bilibili.com:2244/sub")!)
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
        let data = LiveWSHeader.encode(operatorType: .auth, data: AuthPackage(roomid: roomID).encode())
        websocket?.write(data: data)
    }
    
}

// MARK: Data parse
extension LiveDanMuProvider {
    private func parseData(data: Data) {
        let header = LiveWSHeader.decode(data: data)
        let contentData = data.subdata(in: Int(header.headerSize) ..< Int(header.size))
        let operatorType = OperatorType(rawValue: header.operatorType)
        switch operatorType {
        case nil:
            assertionFailure()
            break
        case .authReply:
            print("get authReply")
        case .heaerBeatReply:
            print("get heaerBeatReply")
        case .normal:
            do {
                if header.protocolType == 0 {
                    parseNormalData(data: contentData)
                } else {
                    parseData(data: try contentData.gunzipped())
                }
            } catch {
                parseNormalData(data: contentData)
            }
        default:
            print("get",operatorType?.rawValue ?? 0)
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
            .map{ JSON(parseJSON: $0) }
            .forEach { json in
                let cmd = json["cmd"].stringValue
                switch cmd {
                case "DANMU_MSG":
                    if let str = json["info"][1].string { onDanmu?(str) }
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
    func didReceive(event: WebSocketEvent, client: WebSocket) {
        print(event)
        switch event {
        case .connected(_):
            sendJoinLiveRoom()
            setupHeartBeat()
        case .disconnected(_, _):
            print("disconnect")
        case .binary(let data):
            parseData(data: data)
        default:
            break
        }
    }
}


private struct LiveWSHeader {
    var size:UInt32
    var headerSize:UInt16 = UInt16(UInt16(16).bigEndian)
    var protocolType:UInt16 = UInt16(UInt16(1).bigEndian)
    var operatorType:UInt32
    var sequence: UInt32 = UInt32(UInt32(1).bigEndian)
    
    static func encode(operatorType:OperatorType, data:Data) -> Data {
        let size = UInt32(data.count) + UInt32(MemoryLayout<LiveWSHeader>.size)
        let header = LiveWSHeader(size: size.bigEndian,operatorType: operatorType.value)
        var headerData = withUnsafePointer(to:header) { p in
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
    
    var value:UInt32 {
        get {self.rawValue.bigEndian}
    }
}

private struct AuthPackage: Encodable {
    let uid = 0
    let roomid:Int
    let protover = 2
    let platform = "web"
    let clientver = "2.6.38"
    let type = 2
    let key = "XxbA7FDv1Zu0tztQcnbagJbO4NqhkD4I8qZLZVkbZwUfXgUF7-CyqxFd91_2EWdCxDWP9gQ6AqY_0J7U3ftThP-qrFiVr3a4VL-MrHrNEATy9MJzbm2BYaAt-TxzJcMcHJU8h7AO-8-zapyR"
    
    func encode() -> Data {
        try! JSONEncoder().encode(self)
    }
}
