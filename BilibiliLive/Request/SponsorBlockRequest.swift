//
//  SponsorBlockRequest.swift
//  BilibiliLive
//
//  Created by yicheng on 2/11/2024.
//

import Alamofire
import CryptoKit
import Foundation

enum SponsorBlockRequest {
    class SkipSegment: Codable {
        let segment: [Double]
        let category: String
        let UUID: String
        let actionType: String
        let videoDuration: Double

        var vaild: Bool {
            segment.count >= 2
        }

        var start: Double {
            guard segment.count >= 1 else { return 0 }
            return segment[0]
        }

        var end: Double {
            guard segment.count >= 2 else { return 0 }
            return segment[1]
        }
    }

    enum Category: String, Codable {
        case sponsor
    }

    static let sponsorBlockAPI = "https://bsbsb.top/api/skipSegments/"

    static func getSkipSegments(bvid: String) async throws -> [SkipSegment] {
        class Infos: Codable {
            let segments: [SkipSegment]
            let videoID: String
        }

        guard let bvidData = bvid.data(using: .utf8) else {
            return []
        }
        let sha256 = SHA256.hash(data: bvidData)
            .map({ String(format: "%02x", $0) }).prefix(2).joined()
        let parameters = ["category": Category.sponsor.rawValue]

        let request = AF.request(sponsorBlockAPI + sha256, parameters: parameters)
            .serializingDecodable([Infos].self)
        do {
            let response = try await request.value

            let segs = response.filter({ $0.videoID == bvid })
                .map({ $0.segments })
                .flatMap({ $0 })
                .filter({ $0.vaild })
            return segs
        } catch {
            throw error
        }
    }
}
