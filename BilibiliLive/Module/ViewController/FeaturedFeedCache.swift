//
//  FeaturedFeedCache.swift
//  BilibiliLive
//
//  Created by OpenAI on 2026/4/4.
//

import Foundation

struct CachedRecommendedVideoItem: Codable {
    let aid: Int
    let cid: Int
    let idx: Int
    let title: String
    let ownerName: String
    let coverURL: String?
    let avatarURL: String?
    let duration: Int
    let durationText: String
    let reasonText: String?
}

struct FeaturedFeedCacheSnapshot: Codable {
    let savedAt: Date
    let durationLimit: FeaturedDurationLimit
    let lastSourceIdx: Int?
    let items: [CachedRecommendedVideoItem]
}

extension RecommendedVideoItem {
    init(cached item: CachedRecommendedVideoItem) {
        aid = item.aid
        cid = item.cid
        idx = item.idx
        title = item.title
        ownerName = item.ownerName
        coverURL = item.coverURL.flatMap(URL.init(string:))
        avatarURL = item.avatarURL.flatMap(URL.init(string:))
        duration = item.duration
        durationText = item.durationText
        reasonText = item.reasonText
    }

    var cachedValue: CachedRecommendedVideoItem {
        CachedRecommendedVideoItem(aid: aid,
                                   cid: cid,
                                   idx: idx,
                                   title: title,
                                   ownerName: ownerName,
                                   coverURL: coverURL?.absoluteString,
                                   avatarURL: avatarURL?.absoluteString,
                                   duration: duration,
                                   durationText: durationText,
                                   reasonText: reasonText)
    }
}

final class FeaturedFeedCache {
    static let shared = FeaturedFeedCache()

    private let storageKey = "FeaturedBrowser.cachedSnapshot"
    private let ttl: TimeInterval = 15 * 60
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private init() {}

    func load(durationLimit: FeaturedDurationLimit) -> FeaturedFeedCacheSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let snapshot = try? decoder.decode(FeaturedFeedCacheSnapshot.self, from: data),
              snapshot.durationLimit == durationLimit,
              Date().timeIntervalSince(snapshot.savedAt) <= ttl
        else {
            return nil
        }
        return snapshot
    }

    func save(items: [RecommendedVideoItem], lastSourceIdx: Int?, durationLimit: FeaturedDurationLimit) {
        let snapshot = FeaturedFeedCacheSnapshot(savedAt: Date(),
                                                 durationLimit: durationLimit,
                                                 lastSourceIdx: lastSourceIdx,
                                                 items: items.map(\.cachedValue))
        guard let data = try? encoder.encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
