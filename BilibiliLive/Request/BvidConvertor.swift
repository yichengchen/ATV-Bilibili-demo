//
//  BvidConvertor.swift
//  BilibiliLive
//
//  Created by yicheng on 2024/12/13.
//

enum BvidConvertor {
    // https://github.com/SocialSisterYi/bilibili-API-collect/blob/master/docs/misc/bvid_desc.md
    private static let XOR_CODE: UInt64 = 23442827791579
    private static let MASK_CODE: UInt64 = 2251799813685247
    private static let MAX_AID: UInt64 = 1 << 51

    private static let data: [UInt8] = [70, 99, 119, 65, 80, 78, 75, 84, 77, 117, 103, 51, 71, 86, 53, 76, 106, 55, 69, 74, 110, 72, 112, 87, 115, 120, 52, 116, 98, 56, 104, 97, 89, 101, 118, 105, 113, 66, 122, 54, 114, 107, 67, 121, 49, 50, 109, 85, 83, 68, 81, 88, 57, 82, 100, 111, 90, 102]

    private static let BASE: UInt64 = 58
    private static let BV_LEN: Int = 12
    private static let PREFIX: String = "BV1"

    static func av2bv(avid: UInt64) -> String {
        var bytes: [UInt8] = [66, 86, 49, 48, 48, 48, 48, 48, 48, 48, 48, 48]
        var bvIdx = BV_LEN - 1
        var tmp = (MAX_AID | avid) ^ XOR_CODE

        while tmp != 0 {
            bytes[bvIdx] = data[Int(tmp % BASE)]
            tmp /= BASE
            bvIdx -= 1
        }

        bytes.swapAt(3, 9)
        bytes.swapAt(4, 7)

        return String(decoding: bytes, as: UTF8.self)
    }

    static func bv2av(bvid: String) -> UInt64 {
        let fixedBvid: String
        if bvid.hasPrefix("BV") {
            fixedBvid = bvid
        } else {
            fixedBvid = "BV" + bvid
        }
        var bvidArray = Array(fixedBvid.utf8)

        bvidArray.swapAt(3, 9)
        bvidArray.swapAt(4, 7)

        let trimmedBvid = String(decoding: bvidArray[3...], as: UTF8.self)

        var tmp: UInt64 = 0

        for char in trimmedBvid {
            if let idx = data.firstIndex(of: char.utf8.first!) {
                tmp = tmp * BASE + UInt64(idx)
            }
        }

        return (tmp & MASK_CODE) ^ XOR_CODE
    }
}
