//
//  DouLiveDanMuProvider.swift
//  BilibiliLive
//
//  Created by yicheng on 2023/4/7.
//

import Foundation
import Starscream

class DouLiveDanMuProvider {
    private var websocket: WebSocket?
    private var heartBeatTimer: Timer?
    private let roomID: Int
    var douyuSavedData: Data = .init()

    var onDanmu: ((String) -> Void)?
    var onSC: ((String) -> Void)?

    init(roomID: Int) {
        self.roomID = roomID
    }

    deinit {
        stop()
    }

    func start() {
        let request = URLRequest(url: URL(string: "wss://danmuproxy.douyu.com:8506")!)
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
        let keeplive = "type@=mrkl/"
        let data = pack(keeplive)
        return data
    }

    private func pack(_ str: String) -> Data {
        var data = Data()
        let str = str + "\0"
        let size = UInt32(str.count + 8)
        data.append(contentsOf: size.bigEndian.toUInt8s)
        data.append(contentsOf: size.bigEndian.toUInt8s)
        data.append(contentsOf: UInt32(689).bigEndian.toUInt8s)
        data.append(str.data(using: .utf8) ?? Data())
        return data
    }

    @objc private func sendHeartBeat() {
        let data = getHeartbeatPackage()
        websocket?.write(data: data)
    }

    private func sendJoinLiveRoom() {
        let loginreq = "type@=loginreq/roomid@=\(roomID)/"
        let joingroup = "type@=joingroup/rid@=\(roomID)/gid@=-9999/"
        websocket?.write(data: pack(loginreq))
        websocket?.write(data: pack(joingroup))
    }
}

// MARK: Data parse

extension DouLiveDanMuProvider {
    private func parseData(data: Data) {
        var d = data

        if douyuSavedData.count != 0 {
            douyuSavedData.append(d)
            d = douyuSavedData
            douyuSavedData = Data()
        }

        var msgDatas: [Data] = []

        while d.count > 12 {
            let head = d.subdata(in: 0..<4)
            let endIndex = Int(CFSwapInt32LittleToHost(head.withUnsafeBytes { $0.load(as: UInt32.self) }))
            if d.count < endIndex + 2 {
                douyuSavedData.append(douyuSavedData)
                d = Data()
            } else {
                guard endIndex + 2 > 12,
                      endIndex + 2 < d.endIndex
                else {
                    print("endIndex out of range.")
                    return
                }
                let msg = d.subdata(in: 12..<endIndex + 2)
                msgDatas.append(msg)
                d = d.subdata(in: endIndex + 2..<d.endIndex)
            }
        }

        msgDatas.forEach {
            guard let msg = String(data: $0, encoding: .utf8) else { return }
            if msg.starts(with: "type@=chatmsg") {
                let dm = msg.split(separator: "/").filter {
                    $0.starts(with: "txt@=")
                }.first

                if let dm = dm {
                    self.onDanmu?(String(dm.dropFirst("txt@=".count)))
                    print(dm)
                }
            } else if msg.starts(with: "type@=error") {
                print("douyu socket disconnected: \(msg)")
                websocket?.disconnect()
            } else if msg.starts(with: "type@=loginres") {
                print("douyu content success")
            } else if msg == "type@=mrkl" {
                print("Danmaku HeartBeatRsp")
            }
        }
    }
}

// MARK: WebSocketDelegate

extension DouLiveDanMuProvider: WebSocketDelegate {
    func didReceive(event: WebSocketEvent, client: WebSocket) {
        print(event)
        switch event {
        case .connected:
            sendJoinLiveRoom()
            setupHeartBeat()
        case .disconnected:
            print("disconnect")
        case let .binary(data):
            parseData(data: data)
        default:
            break
        }
    }
}
