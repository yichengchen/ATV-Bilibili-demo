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
