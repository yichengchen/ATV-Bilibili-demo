//
//  FeaturedRanker.swift
//  BilibiliLive
//
//  Created on 2026/4/5.
//

import Foundation

enum FeaturedRanker {
    /// 排序算法版本号，升版时使旧缓存失效
    static let rankVersion = 1

    // MARK: - 权重常量

    private static let sourceOrderWeight: Double = 0.40
    private static let ownerWeight: Double = 0.30
    private static let durationBucketWeight: Double = 0.15
    private static let topicTokenWeight: Double = 0.15

    private static let rankWindowSize = 24
    private static let stabilizationPrefixSize = 12
    private static let dominantClusterCount = 2
    private static let dominantClusterBonus: Double = 0.12
    private static let maxConsecutiveSameOwner = 2

    // MARK: - Public API

    /// 对候选列表进行智能排序
    /// - Parameters:
    ///   - items: 经过过滤后的候选视频列表
    ///   - profile: 兴趣画像（已叠加会话信号）
    /// - Returns: 排序后的列表
    static func rank(_ items: [RecommendedVideoItem],
                     profile: FeaturedInterestProfile) -> [RecommendedVideoItem]
    {
        guard profile.sampleTier != .none else { return items }

        let windowSize = min(rankWindowSize, items.count)
        guard windowSize > 1 else { return items }

        let windowItems = Array(items.prefix(windowSize))
        let tail = Array(items.dropFirst(windowSize))

        // 1. 计算基础得分
        let scored = computeBaseScores(windowItems, profile: profile)

        // 2. stable sort by score descending
        let sorted = scored.sorted { a, b in
            if abs(a.score - b.score) > 1e-9 {
                return a.score > b.score
            }
            return a.sourceIndex < b.sourceIndex // 并列按原始顺序
        }

        // 3. 稳定化前缀
        let stabilized = stabilizePrefix(sorted)

        // 4. 同 owner 连续约束
        let deduplicated = enforceOwnerSpread(stabilized)

        return deduplicated.map(\.item) + tail
    }

    /// 对新追加的 batch 单独排序（不影响现有列表）
    static func rankBatch(_ batch: [RecommendedVideoItem],
                          profile: FeaturedInterestProfile) -> [RecommendedVideoItem]
    {
        guard profile.sampleTier != .none, batch.count > 1 else { return batch }
        let scored = computeBaseScores(batch, profile: profile)
        let sorted = scored.sorted { a, b in
            if abs(a.score - b.score) > 1e-9 {
                return a.score > b.score
            }
            return a.sourceIndex < b.sourceIndex
        }
        return sorted.map(\.item)
    }

    // MARK: - Scoring

    private struct ScoredItem {
        let item: RecommendedVideoItem
        let sourceIndex: Int
        var score: Double
        let ownerScore: Double
        let durationScore: Double
        let tokenScore: Double
        let clusterKey: String
    }

    private static func computeBaseScores(_ items: [RecommendedVideoItem],
                                          profile: FeaturedInterestProfile) -> [ScoredItem]
    {
        // 归一化辅助
        let maxOwnerWeight = profile.ownerWeights.values.max() ?? 1.0
        let maxDurationWeight = profile.durationBucketWeights.values.max() ?? 1.0
        let maxTokenWeight = profile.topicTokenWeights.values.max() ?? 1.0

        return items.enumerated().map { index, item in
            // source order: 越靠前越高
            let sourceScore = 1.0 - (Double(index) / max(1.0, Double(items.count - 1)))

            // owner match
            let rawOwner = profile.ownerWeights[item.ownerName] ?? 0
            let ownerScore = maxOwnerWeight > 0 ? rawOwner / maxOwnerWeight : 0

            // duration bucket match
            let bucket = DurationBucket.from(seconds: item.duration)
            let rawDuration = profile.durationBucketWeights[bucket] ?? 0
            let durationScore = maxDurationWeight > 0 ? rawDuration / maxDurationWeight : 0

            // topic token match (仅 full tier)
            var tokenScore = 0.0
            var bestTokenKey = ""
            if profile.sampleTier == .full, !profile.topicTokenWeights.isEmpty {
                let titleTokens = FeaturedTokenExtractor.extract(from: item.title)
                var bestMatch = 0.0
                for token in titleTokens {
                    let weight = profile.topicTokenWeights[token] ?? 0
                    if weight > bestMatch {
                        bestMatch = weight
                        bestTokenKey = token
                    }
                }
                tokenScore = maxTokenWeight > 0 ? bestMatch / maxTokenWeight : 0
            }

            // 兴趣簇 key 优先级: topic token > ownerName > duration bucket
            let clusterKey: String
            if !bestTokenKey.isEmpty, tokenScore > 0.3 {
                clusterKey = "token:\(bestTokenKey)"
            } else if ownerScore > 0.3 {
                clusterKey = "owner:\(item.ownerName)"
            } else {
                clusterKey = "duration:\(bucket.rawValue)"
            }

            let totalScore = sourceScore * sourceOrderWeight
                + ownerScore * ownerWeight
                + durationScore * durationBucketWeight
                + tokenScore * topicTokenWeight

            return ScoredItem(item: item,
                              sourceIndex: index,
                              score: totalScore,
                              ownerScore: ownerScore,
                              durationScore: durationScore,
                              tokenScore: tokenScore,
                              clusterKey: clusterKey)
        }
    }

    // MARK: - Stabilization

    private static func stabilizePrefix(_ sorted: [ScoredItem]) -> [ScoredItem] {
        let prefixSize = min(stabilizationPrefixSize, sorted.count)
        guard prefixSize > 1 else { return sorted }

        var prefix = Array(sorted.prefix(prefixSize))
        let suffix = Array(sorted.dropFirst(prefixSize))

        // 找 dominant clusters：累计得分最高的前 N 个兴趣簇
        var clusterScores = [String: Double]()
        for item in prefix {
            clusterScores[item.clusterKey, default: 0] += item.score
        }
        let dominantKeys = Set(
            clusterScores.sorted { $0.value > $1.value }
                .prefix(dominantClusterCount)
                .map(\.key)
        )

        // dominant cluster +0.12 bonus
        for i in prefix.indices {
            if dominantKeys.contains(prefix[i].clusterKey) {
                prefix[i].score += dominantClusterBonus
            }
        }

        // stable sort 前缀
        prefix.sort { a, b in
            if abs(a.score - b.score) > 1e-9 {
                return a.score > b.score
            }
            return a.sourceIndex < b.sourceIndex
        }

        return prefix + suffix
    }

    // MARK: - Owner Spread

    private static func enforceOwnerSpread(_ items: [ScoredItem]) -> [ScoredItem] {
        var result = items
        var i = 0
        while i < result.count {
            // 检查从 i 开始的连续同 owner
            var consecutiveCount = 1
            while i + consecutiveCount < result.count,
                  result[i + consecutiveCount].item.ownerName == result[i].item.ownerName
            {
                consecutiveCount += 1
            }

            if consecutiveCount > maxConsecutiveSameOwner {
                // 从第 maxConsecutiveSameOwner 个开始，把多余的和后面的不同 owner 交换
                let violatingIndex = i + maxConsecutiveSameOwner
                let ownerToBreak = result[i].item.ownerName

                // 找后面最近的不同 owner
                if let swapTarget = (violatingIndex + 1..<result.count)
                    .first(where: { result[$0].item.ownerName != ownerToBreak })
                {
                    result.swapAt(violatingIndex, swapTarget)
                }
            }
            i += max(1, consecutiveCount > maxConsecutiveSameOwner ? maxConsecutiveSameOwner : consecutiveCount)
        }
        return result
    }
}
