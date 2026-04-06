//
//  FeaturedContentSafetyFilter.swift
//  BilibiliLive
//
//  Created by OpenAI on 2026/4/6.
//

import Foundation

enum FeaturedContentSafetyFilter {
    struct Rule {
        let rawValue: String
        let normalizedValue: String
    }

    static let version = 4

    private static let rawKeywords = [
        "擦边",
        "纯欲",
        "甜欲",
        "纯御",
        "御姐",
        "姐感",
        "妻感",
        "钓系",
        "辣妹",
        "魅魔",
        "小妈",
        "女仆",
        "兔女郎",
        "黑丝",
        "白丝",
        "灰丝",
        "肉丝",
        "油丝",
        "厚黑",
        "厚白",
        "亮丝",
        "丝袜",
        "网袜",
        "连裤袜",
        "过膝袜",
        "吊带袜",
        "渔网袜",
        "美腿",
        "腿控",
        "玉足",
        "足控",
        "包臀",
        "超短裙",
        "低胸",
        "深v",
        "抹胸",
        "露腰",
        "露背",
        "泳装",
        "比基尼",
        "写真",
        "私房",
        "热舞",
        "扭胯",
        "扭臀",
        "抖臀",
        "摇臀",
        "口腔音",
        "舔耳",
        "掏耳",
        "耳骚",
        "吸吮",
        "娇喘",
        "喘息",
        "哄睡",
        "电子女友",
        "女秘书",
    ]

    private static let rules: [Rule] = rawKeywords.compactMap { keyword in
        let normalizedValue = normalize(keyword)
        guard !normalizedValue.isEmpty else { return nil }
        return Rule(rawValue: keyword, normalizedValue: normalizedValue)
    }

    private static let stylePackagingRules = makeRules([
        "试穿",
        "休息区",
        "养眼",
        "纯享",
        "放松一下眼睛",
    ])

    private static let personaRules = makeRules([
        "甜妹",
        "纯欲",
        "甜欲",
        "纯御",
        "御姐",
        "学姐",
        "姐姐",
        "姐感",
        "妻感",
        "钓系",
        "电子女友",
        "女秘书",
        "秘书",
        "女仆",
        "兔女郎",
        "猫娘",
        "小妈",
        "辣妹",
        "jk",
        "制服",
    ])

    private static let clothingRules = makeRules([
        "黑丝",
        "白丝",
        "灰丝",
        "肉丝",
        "油丝",
        "厚黑",
        "厚白",
        "亮丝",
        "丝袜",
        "网袜",
        "连裤袜",
        "过膝袜",
        "吊带袜",
        "渔网袜",
        "红底高跟",
        "透明高跟",
        "细高跟",
        "包臀",
        "包臀裙",
        "超短裙",
        "露腰",
        "露背",
        "微透",
        "比基尼",
        "泳装",
        "写真",
        "私房",
        "美腿",
        "玉足",
    ])

    static func allows(feedItem: ApiRequest.FeedResp.Items) -> Bool {
        let texts = [
            feedItem.title,
            feedItem.ownerName,
            feedItem.desc,
            feedItem.top_rcmd_reason,
            feedItem.bottom_rcmd_reason,
        ]
        return matchedRule(in: texts) == nil && matchedCombination(in: texts) == nil
    }

    static func allows(cachedItem: CachedRecommendedVideoItem) -> Bool {
        let texts = [
            cachedItem.title,
            cachedItem.ownerName,
            cachedItem.reasonText,
        ]
        return matchedRule(in: texts) == nil && matchedCombination(in: texts) == nil
    }

    private static func matchedRule(in texts: [String?]) -> Rule? {
        for text in texts {
            let normalizedText = normalize(text)
            guard !normalizedText.isEmpty else { continue }
            if let matchedRule = rules.first(where: { normalizedText.contains($0.normalizedValue) }) {
                return matchedRule
            }
        }
        return nil
    }

    private static func matchedCombination(in texts: [String?]) -> String? {
        let normalizedTexts = texts.map(normalize).filter { !$0.isEmpty }
        guard !normalizedTexts.isEmpty else { return nil }

        let hasStylePackaging = containsAny(normalizedTexts, rules: stylePackagingRules)
        let hasPersona = containsAny(normalizedTexts, rules: personaRules)
        let hasClothing = containsAny(normalizedTexts, rules: clothingRules)

        if hasStylePackaging && hasClothing {
            return "style+clothing"
        }
        if hasPersona && hasClothing {
            return "persona+clothing"
        }
        return nil
    }

    private static func containsAny(_ texts: [String], rules: [Rule]) -> Bool {
        texts.contains { text in
            rules.contains { text.contains($0.normalizedValue) }
        }
    }

    private static func makeRules(_ keywords: [String]) -> [Rule] {
        keywords.compactMap { keyword in
            let normalizedValue = normalize(keyword)
            guard !normalizedValue.isEmpty else { return nil }
            return Rule(rawValue: keyword, normalizedValue: normalizedValue)
        }
    }

    private static func normalize(_ text: String?) -> String {
        guard let text else { return "" }
        let withoutHTML = text.removingHTMLTags()
        let halfWidth = withoutHTML.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? withoutHTML
        let lowered = halfWidth.lowercased()
        let filteredScalars = lowered.unicodeScalars.filter { scalar in
            !CharacterSet.whitespacesAndNewlines.contains(scalar) &&
                !CharacterSet.punctuationCharacters.contains(scalar) &&
                !CharacterSet.symbols.contains(scalar) &&
                !CharacterSet.controlCharacters.contains(scalar)
        }
        return String(String.UnicodeScalarView(filteredScalars))
    }
}
