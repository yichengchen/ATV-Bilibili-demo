//
//  WSParser.swift
//  BilibiliLive
//
//  Created by Etan on 2021/3/28.
//

import Foundation

struct LiveWSHeader {
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


enum OperatorType: UInt32 {
    case heartBeat = 2
    case heaerBeatReply = 3
    case normal = 5
    case auth = 7
    case authReply = 8
    
    var value:UInt32 {
        get {self.rawValue.bigEndian}
    }
}

struct AuthPackage: Encodable {
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

struct WSParser {
    static func getHeartbeatPackage() -> Data {
        let data = "[object Object]".data(using: .utf8)!
        let header = LiveWSHeader.encode(operatorType: .heartBeat, data: data)
        return header
    }
}
