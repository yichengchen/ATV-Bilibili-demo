//
//  DataUtil.swift
//  BilibiliLive
//
//  Created by yicheng on 2023/3/7.
//

import Foundation

extension Data {
    func getUint32(offset: inout UInt64) -> UInt32 {
        getValue(type: UInt32.self, offset: &offset).bigEndian
    }

    func getUint16(offset: inout UInt64) -> UInt16 {
        getValue(type: UInt16.self, offset: &offset).bigEndian
    }

    func getUint8(offset: inout UInt64) -> UInt8 {
        getValue(type: UInt8.self, offset: &offset).bigEndian
    }

    func getValue<T>(type: T.Type, offset: inout UInt64) -> T {
        let size = UInt64(MemoryLayout<T>.size)
        defer {
            offset += size
        }
        return Data(self[offset..<size + offset]).withUnsafeBytes({ $0.load(as: T.self) })
    }
}

protocol UIntToUInt8sConvertable {
    var toUInt8s: [UInt8] { get }
}

extension UIntToUInt8sConvertable {
    func toUInt8Arr<T>(endian: T, count: Int) -> [UInt8] {
        var _endian = endian
        let UInt8Ptr = withUnsafePointer(to: &_endian) {
            $0.withMemoryRebound(to: UInt8.self, capacity: count) {
                UnsafeBufferPointer(start: $0, count: count)
            }
        }
        return [UInt8](UInt8Ptr)
    }
}

extension UInt32: UIntToUInt8sConvertable {
    var toUInt8s: [UInt8] {
        return toUInt8Arr(endian: bigEndian,
                          count: MemoryLayout<UInt32>.size)
    }
}

extension UInt64: UIntToUInt8sConvertable {
    var toUInt8s: [UInt8] {
        return toUInt8Arr(endian: bigEndian,
                          count: MemoryLayout<UInt64>.size)
    }
}
