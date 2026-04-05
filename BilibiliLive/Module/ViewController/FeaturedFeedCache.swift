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
    let accountMID: Int
    let personalizedEnabled: Bool
    let rankVersion: Int

    // 向后兼容：旧快照不含新字段时解码默认值
    enum CodingKeys: String, CodingKey {
        case savedAt, durationLimit, lastSourceIdx, items
        case accountMID, personalizedEnabled, rankVersion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        savedAt = try container.decode(Date.self, forKey: .savedAt)
        durationLimit = try container.decode(FeaturedDurationLimit.self, forKey: .durationLimit)
        lastSourceIdx = try container.decodeIfPresent(Int.self, forKey: .lastSourceIdx)
        items = try container.decode([CachedRecommendedVideoItem].self, forKey: .items)
        accountMID = try container.decodeIfPresent(Int.self, forKey: .accountMID) ?? 0
        personalizedEnabled = try container.decodeIfPresent(Bool.self, forKey: .personalizedEnabled) ?? false
        rankVersion = try container.decodeIfPresent(Int.self, forKey: .rankVersion) ?? 0
    }

    init(savedAt: Date, durationLimit: FeaturedDurationLimit, lastSourceIdx: Int?,
         items: [CachedRecommendedVideoItem], accountMID: Int, personalizedEnabled: Bool, rankVersion: Int)
    {
        self.savedAt = savedAt
        self.durationLimit = durationLimit
        self.lastSourceIdx = lastSourceIdx
        self.items = items
        self.accountMID = accountMID
        self.personalizedEnabled = personalizedEnabled
        self.rankVersion = rankVersion
    }
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

    func load(durationLimit: FeaturedDurationLimit,
              accountMID: Int? = nil,
              personalizedEnabled: Bool? = nil) -> FeaturedFeedCacheSnapshot?
    {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let snapshot = try? decoder.decode(FeaturedFeedCacheSnapshot.self, from: data),
              snapshot.durationLimit == durationLimit,
              Date().timeIntervalSince(snapshot.savedAt) <= ttl
        else {
            return nil
        }
        // 校验账号和个性化开关
        if let mid = accountMID, snapshot.accountMID != mid { return nil }
        if let enabled = personalizedEnabled, snapshot.personalizedEnabled != enabled { return nil }
        if personalizedEnabled == true, snapshot.rankVersion != FeaturedRanker.rankVersion { return nil }
        return snapshot
    }

    func save(items: [RecommendedVideoItem], lastSourceIdx: Int?,
              durationLimit: FeaturedDurationLimit,
              accountMID: Int = 0, personalizedEnabled: Bool = false)
    {
        let snapshot = FeaturedFeedCacheSnapshot(savedAt: Date(),
                                                 durationLimit: durationLimit,
                                                 lastSourceIdx: lastSourceIdx,
                                                 items: items.map(\.cachedValue),
                                                 accountMID: accountMID,
                                                 personalizedEnabled: personalizedEnabled,
                                                 rankVersion: FeaturedRanker.rankVersion)
        guard let data = try? encoder.encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
