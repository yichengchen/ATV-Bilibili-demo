//
//  FeaturedInterestProfileCache.swift
//  BilibiliLive
//
//  Created on 2026/4/5.
//

import Foundation

struct FeaturedInterestProfileSnapshot: Codable {
    let savedAt: Date
    let accountMID: Int
    let sampleCount: Int
    let rankVersion: Int
    let ownerWeights: [String: Double]
    let durationBucketWeights: [String: Double] // DurationBucket.rawValue -> weight
    let topicTokenWeights: [String: Double]
}

extension FeaturedInterestProfileSnapshot {
    init(profile: FeaturedInterestProfile, mid: Int, rankVersion: Int) {
        savedAt = Date()
        accountMID = mid
        sampleCount = profile.sampleCount
        self.rankVersion = rankVersion
        ownerWeights = profile.ownerWeights
        durationBucketWeights = Dictionary(
            uniqueKeysWithValues: profile.durationBucketWeights.map { ($0.key.rawValue, $0.value) }
        )
        topicTokenWeights = profile.topicTokenWeights
    }

    func toProfile() -> FeaturedInterestProfile {
        let tier = InterestSampleTier.from(sampleCount: sampleCount)
        let bucketWeights = Dictionary(
            uniqueKeysWithValues: durationBucketWeights.compactMap { key, value -> (DurationBucket, Double)? in
                guard let bucket = DurationBucket(rawValue: key) else { return nil }
                return (bucket, value)
            }
        )
        return FeaturedInterestProfile(
            ownerWeights: ownerWeights,
            durationBucketWeights: bucketWeights,
            topicTokenWeights: topicTokenWeights,
            sampleTier: tier,
            sampleCount: sampleCount
        )
    }
}

final class FeaturedInterestProfileCache {
    static let shared = FeaturedInterestProfileCache()

    private let storageKey = "FeaturedBrowser.interestProfile"
    private let ttl: TimeInterval = 24 * 3600 // 24h
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private init() {}

    func load(mid: Int, rankVersion: Int) -> FeaturedInterestProfile? {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let snapshot = try? decoder.decode(FeaturedInterestProfileSnapshot.self, from: data),
              snapshot.accountMID == mid,
              snapshot.rankVersion == rankVersion,
              Date().timeIntervalSince(snapshot.savedAt) <= ttl
        else {
            return nil
        }
        return snapshot.toProfile()
    }

    func save(_ profile: FeaturedInterestProfile, mid: Int, rankVersion: Int) {
        let snapshot = FeaturedInterestProfileSnapshot(profile: profile, mid: mid, rankVersion: rankVersion)
        guard let data = try? encoder.encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
