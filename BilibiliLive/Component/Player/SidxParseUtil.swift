//
//  SidxParseUtil.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/11/13.
//

import Foundation

enum SidxParseUtil {
    struct Sidx {
        let timescale: Int
        let firstOffset: Int
        let earliestPresentationTime: Int
        let segments: [SegmentInfo]

        struct SegmentInfo {
            let type: Int
            let size: Int
            let duration: Int
            let sap: Int
            let sap_type: Int
            let sap_delta: Int
        }

        func maxSegmentDuration() -> Int? {
            if let duration = segments.map({ Double($0.duration) / Double(timescale) }).max() {
                return Int(duration + 1)
            }
            return nil
        }
    }

    static func processIndexData(data: Data) -> Sidx? {
        var offset: UInt64 = 0
        var typeString = ""
        var sidx: Sidx?
        while offset < data.count - 8 {
            print("offset:", offset)
            var size = UInt64(data.getUint32(offset: &offset))
            let typeArr = data.getUint32(offset: &offset).toUInt8s
            typeString = String(bytes: typeArr, encoding: .utf8)!
            print(size, typeString)
            switch typeString {
            case "sidx":
                if size == 1 {
                    size = data.getValue(type: UInt64.self, offset: &offset)
                }
                sidx = processSIDX(data: Data(data[Data.Index(offset)..<Int(size)]))
                offset += (size - 8)
            default: break
            }
        }
        return sidx
    }

    private static func processSIDX(data: Data) -> Sidx {
        var offset: UInt64 = 0
        _ = data.getUint8(offset: &offset) // version
        _ = data.getUint8(offset: &offset) // none
        _ = data.getUint8(offset: &offset) // none
        _ = data.getUint8(offset: &offset) // none
        _ = data.getUint32(offset: &offset) // refID
        let timescale = data.getUint32(offset: &offset)
        let earliest_presentation_time = data.getUint32(offset: &offset)
        let first_offset = data.getUint32(offset: &offset)
        _ = data.getValue(type: UInt16.self, offset: &offset).bigEndian // reversed
        let reference_count = data.getValue(type: UInt16.self, offset: &offset).bigEndian

        var infos = [Sidx.SegmentInfo]()
        for _ in 0..<reference_count {
            var code = data.getUint32(offset: &offset)
            let reference_type = (code >> 31) & 1
            let referenced_size = (code & 0x7fffffff)
            let duration = data.getUint32(offset: &offset)

            code = data.getUint32(offset: &offset)
            let starts_with_SAP = (code >> 31) & 1
            let sap_type = (code >> 29) & 7
            let sap_delta_time = (code & 0x0fffffff)
            let info = Sidx.SegmentInfo(type: Int(reference_type), size: Int(referenced_size), duration: Int(duration), sap: Int(starts_with_SAP), sap_type: Int(sap_type), sap_delta: Int(sap_delta_time))
            infos.append(info)
        }

        return Sidx(timescale: Int(timescale), firstOffset: Int(first_offset), earliestPresentationTime: Int(earliest_presentation_time), segments: infos)
    }
}

extension Data {
    func getUint32(offset: inout UInt64) -> UInt32 {
        getValue(type: UInt32.self, offset: &offset).bigEndian
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
