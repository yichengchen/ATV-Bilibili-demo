//
//  FeaturedInterestProfile.swift
//  BilibiliLive
//
//  Created on 2026/4/5.
//

import Foundation

// MARK: - Duration Bucket

enum DurationBucket: String, Codable, CaseIterable {
    case under60s
    case s60to180
    case s180to300
    case s300to600

    static func from(seconds: Int) -> DurationBucket {
        switch seconds {
        case ..<60: return .under60s
        case 60..<180: return .s60to180
        case 180..<300: return .s180to300
        default: return .s300to600
        }
    }
}

// MARK: - Sample Tier

enum InterestSampleTier {
    /// 0-2 条：不使用历史画像
    case none
    /// 3-7 条：只用 owner + duration bucket
    case partial
    /// 8+ 条：全三维
    case full

    static func from(sampleCount: Int) -> InterestSampleTier {
        switch sampleCount {
        case 0...2: return .none
        case 3...7: return .partial
        default: return .full
        }
    }
}

// MARK: - Interest Profile

struct FeaturedInterestProfile {
    let ownerWeights: [String: Double]
    let durationBucketWeights: [DurationBucket: Double]
    let topicTokenWeights: [String: Double]
    let sampleTier: InterestSampleTier
    let sampleCount: Int

    static let empty = FeaturedInterestProfile(
        ownerWeights: [:],
        durationBucketWeights: [:],
        topicTokenWeights: [:],
        sampleTier: .none,
        sampleCount: 0
    )

    /// 叠加会话内正向观看信号，返回增强后的画像
    func boosted(with sessionSignals: [(PlayInfo, Int)]) -> FeaturedInterestProfile {
        guard !sessionSignals.isEmpty else { return self }

        var boostedOwner = ownerWeights
        var boostedDuration = durationBucketWeights
        var boostedTokens = topicTokenWeights

        let boostMultiplier = 1.5

        for (info, _) in sessionSignals {
            if let name = info.ownerName, !name.isEmpty {
                boostedOwner[name, default: 0] += boostMultiplier
            }
            if let dur = info.duration, dur > 0 {
                let bucket = DurationBucket.from(seconds: dur)
                boostedDuration[bucket, default: 0] += boostMultiplier
            }
            if let title = info.title {
                let tokens = FeaturedTokenExtractor.extract(from: title)
                for token in tokens {
                    boostedTokens[token, default: 0] += boostMultiplier
                }
            }
        }

        let effectiveTier: InterestSampleTier
        if sampleTier == .none, !sessionSignals.isEmpty {
            effectiveTier = sessionSignals.count >= 3 ? .partial : .none
        } else {
            effectiveTier = sampleTier
        }

        return FeaturedInterestProfile(
            ownerWeights: boostedOwner,
            durationBucketWeights: boostedDuration,
            topicTokenWeights: boostedTokens,
            sampleTier: effectiveTier,
            sampleCount: sampleCount + sessionSignals.count
        )
    }
}

// MARK: - Profile Builder

enum FeaturedInterestProfileBuilder {
    /// 从历史记录构建兴趣画像
    static func build(from history: [HistoryData]) -> FeaturedInterestProfile {
        let tier = InterestSampleTier.from(sampleCount: history.count)
        guard tier != .none else {
            return FeaturedInterestProfile(
                ownerWeights: [:],
                durationBucketWeights: [:],
                topicTokenWeights: [:],
                sampleTier: .none,
                sampleCount: history.count
            )
        }

        // 按 view_at 降序排列（最近的在前），赋予时间衰减权重
        let sorted = history.sorted { $0.view_at > $1.view_at }

        // Owner 权重
        var ownerWeights = [String: Double]()
        for (index, item) in sorted.enumerated() {
            let name = item.ownerName
            guard !name.isEmpty else { continue }
            let recency = 1.0 / (1.0 + Double(index) * 0.1) // 越近权重越高
            ownerWeights[name, default: 0] += recency
        }

        // Duration bucket 权重
        var durationBucketWeights = [DurationBucket: Double]()
        for (index, item) in sorted.enumerated() {
            guard item.duration > 0 else { continue }
            let bucket = DurationBucket.from(seconds: item.duration)
            let recency = 1.0 / (1.0 + Double(index) * 0.1)
            durationBucketWeights[bucket, default: 0] += recency
        }

        // Topic token 权重（仅 full tier）
        var topicTokenWeights = [String: Double]()
        if tier == .full {
            var tokenFrequency = [String: Int]()
            var tokenRecencySum = [String: Double]()

            for (index, item) in sorted.enumerated() {
                let tokens = FeaturedTokenExtractor.extract(from: item.title)
                let recency = 1.0 / (1.0 + Double(index) * 0.1)
                for token in tokens {
                    tokenFrequency[token, default: 0] += 1
                    tokenRecencySum[token, default: 0] += recency
                }
            }

            // 只保留频次 >= 2 的 token
            for (token, freq) in tokenFrequency where freq >= 2 {
                topicTokenWeights[token] = tokenRecencySum[token] ?? 0
            }
        }

        return FeaturedInterestProfile(
            ownerWeights: ownerWeights,
            durationBucketWeights: durationBucketWeights,
            topicTokenWeights: topicTokenWeights,
            sampleTier: tier,
            sampleCount: history.count
        )
    }
}

// MARK: - Token Extractor

enum FeaturedTokenExtractor {
    private static let stopWords: Set<String> = [
        // 中文常见停用词
        "这个", "那个", "什么", "怎么", "如何", "为什么", "可以", "就是",
        "不是", "没有", "已经", "但是", "而且", "所以", "因为", "如果",
        "虽然", "或者", "还是", "只是", "其实", "真的", "一个", "的话",
        "时候", "知道", "觉得", "应该", "需要", "出来", "起来", "下来",
        "上去", "回来", "过来", "自己", "大家", "他们", "我们", "你们",
        // 英文常见停用词
        "the", "and", "for", "are", "but", "not", "you", "all",
        "can", "had", "her", "was", "one", "our", "out", "has",
        "have", "been", "from", "this", "that", "with", "they",
        "will", "what", "when", "make", "just", "know", "take",
        "people", "into", "year", "your", "good", "some", "could",
        "them", "than", "other", "time", "very", "also", "more",
    ]

    /// 从标题中提取有效 token，每个标题最多返回前 3 个
    static func extract(from title: String) -> [String] {
        var tokens = [String]()

        // 1. 提取 ASCII 单词（长度 >= 3）
        let asciiPattern = try? NSRegularExpression(pattern: "[a-zA-Z]{3,}", options: [])
        let nsTitle = title as NSString
        let asciiMatches = asciiPattern?.matches(in: title, options: [], range: NSRange(location: 0, length: nsTitle.length)) ?? []
        for match in asciiMatches {
            let word = nsTitle.substring(with: match.range).lowercased()
            if !stopWords.contains(word), !word.allSatisfy(\.isNumber) {
                tokens.append(word)
            }
        }

        // 2. 提取 CJK 连续子串（长度 2-4）
        let cjkRuns = extractCJKRuns(from: title)
        for run in cjkRuns {
            let chars = Array(run)
            for length in 2...min(4, chars.count) {
                for start in 0...chars.count - length {
                    let sub = String(chars[start..<start + length])
                    if !stopWords.contains(sub), !sub.allSatisfy(\.isNumber) {
                        tokens.append(sub)
                    }
                }
            }
        }

        // 去重并限制最多 3 个
        var seen = Set<String>()
        var result = [String]()
        for token in tokens {
            if seen.insert(token).inserted {
                result.append(token)
                if result.count >= 3 { break }
            }
        }
        return result
    }

    /// 提取连续 CJK 字符组成的 run
    private static func extractCJKRuns(from text: String) -> [String] {
        var runs = [String]()
        var current = ""

        for scalar in text.unicodeScalars {
            if isCJK(scalar) {
                current.unicodeScalars.append(scalar)
            } else {
                if current.count >= 2 {
                    runs.append(current)
                }
                current = ""
            }
        }
        if current.count >= 2 {
            runs.append(current)
        }
        return runs
    }

    private static func isCJK(_ scalar: Unicode.Scalar) -> Bool {
        let value = scalar.value
        // CJK Unified Ideographs
        if value >= 0x4E00, value <= 0x9FFF { return true }
        // CJK Extension A
        if value >= 0x3400, value <= 0x4DBF { return true }
        // CJK Extension B
        if value >= 0x20000, value <= 0x2A6DF { return true }
        // CJK Compatibility Ideographs
        if value >= 0xF900, value <= 0xFAFF { return true }
        return false
    }
}
