//
//  NVASocket.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/11/25.
//

import Foundation
import Swifter
import SwiftyJSON

public func nvasocket(
    uuid: String,
    didConnect: ((NVASession) -> Void)? = nil,
    didDisconnect: ((NVASession) -> Void)? = nil,
    processor: ((NVASession, NVASession.NVAFrame) -> Void)? = nil
) -> ((HttpRequest) -> HttpResponse) {
    return { request in
        guard request.method == "SETUP", let connectSession = request.headers["session"] else {
            return .badRequest(.text("No setup"))
        }

        let protocolSessionClosure: ((Socket) -> Void) = { socket in
            let session = NVASession(socket)
            func read() throws {
                while true {
                    let frame = try session.readFrame()
                    if frame.paramCount == 0 {
                        print("get pong")
                    } else {
                        if frame.isCommand {
                            processor?(session, frame)
                        }
                    }
                }
            }
            didConnect?(session)
            do {
                try read()
            } catch let err {
                print(err)
            }
            didDisconnect?(session)
        }
        let header = ["Session": connectSession,
                      "NvaVersion": "1",
                      "Connection": "Keep-Alive",
                      "UUID": uuid,
                      "User-Agent": "Linux/3.0.0 UPnP/1.0 Platinum/1.0.5.13"]
        return HttpResponse.rawProtocol(200, "OK", header, "NVA", protocolSessionClosure)
    }
}

public class NVASession: Hashable, Equatable {
    public static func == (lhs: NVASession, rhs: NVASession) -> Bool {
        lhs.socket == rhs.socket
    }

    var currentVersion = 1

    public struct NVAFrame {
        // e0
        var isCommand = false
        var paramCount: Int = 0 // 2 or 3  0 menans ping
        var number: UInt32 = 0
        var version = 0x01
        var commandLength: UInt8 = 0
        var command: String = ""
        var actionLength: UInt8 = 0
        var action: String = ""
        var bodyLength: UInt32 = 0
        var body: String = ""
    }

    func readFrame() throws -> NVAFrame {
        var frame = NVAFrame()
        let fst = try socket.read()
        frame.isCommand = fst == 0xe0
        frame.paramCount = Int(try socket.read())

        let versions = try socket.read(length: 4)
        let version = Data(versions).reversed().withUnsafeBytes({ $0.load(as: UInt32.self) })
        frame.version = Int(version)
        print("version=\(frame.version)")
        currentVersion = frame.version

        if frame.paramCount == 0 {
            // is ping
            return frame
        }
        _ = try socket.read() // 0x01
        frame.commandLength = try socket.read()
        frame.command = String(bytes: try socket.read(length: Int(frame.commandLength)).reversed(), encoding: .utf8)!

        if fst != 0xe0 || frame.paramCount == 1 {
            print("reply:", frame.command)
            return frame
        }

        frame.actionLength = try socket.read()
        frame.action = String(bytes: try socket.read(length: Int(frame.actionLength)), encoding: .utf8)!

        if frame.paramCount == 3 {
            let p3L = try socket.read(length: 4)
            let part3Length = Data(p3L).reversed().withUnsafeBytes({ $0.load(as: UInt32.self) })
            frame.bodyLength = part3Length
            frame.body = String(bytes: try socket.read(length: Int(frame.bodyLength)), encoding: .utf8)!
        }

        return frame
    }

    func sendReply(content: [String: Any]) {
        let str = try! JSON(content).rawData()
        let length = UInt32(str.count)
        var arr: [UInt8] = [0xc0, 0x01]
        currentVersion += 1
        arr.append(contentsOf: UInt32(currentVersion).toUInt8s)
        arr.append(contentsOf: length.toUInt8s)
        var data = Data(arr)
        data.append(str)
        try? socket.writeData(data)
    }

    func sendCommand(action: String, content: [String: Any]) {
        let str = try! JSON(content).rawData()
        let length = UInt32(str.count)
        var arr = Data([0xe0, 0x03])
        currentVersion += 1
        arr.append(contentsOf: UInt32(currentVersion).toUInt8s)
        let command = "Command".data(using: .ascii)!
        arr.append(0x01)
        arr.append(UInt8(command.count))
        arr.append(command)
        let actionData = action.data(using: .ascii)!
        arr.append(UInt8(actionData.count))
        arr.append(actionData)

        arr.append(contentsOf: length.toUInt8s)
        arr.append(str)
        try? socket.writeData(arr)
    }

    func sendEmpty() {
        var arr: [UInt8] = [0xc0, 0x00]
        currentVersion += 1
        arr.append(contentsOf: UInt32(currentVersion).toUInt8s)
    }

    let socket: Socket

    init(_ socket: Socket) {
        self.socket = socket
    }

    deinit {
        socket.close()
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(socket)
    }
}

public func == (webSocketSession1: WebSocketSession, webSocketSession2: WebSocketSession) -> Bool {
    return webSocketSession1.socket == webSocketSession2.socket
}
