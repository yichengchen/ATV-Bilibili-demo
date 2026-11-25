//
//  StreamMenuFormatting.swift
//  BilibiliLive
//

import Foundation

enum StreamDynamicRange: Int, Comparable {
    case sdr = 0
    case hdr = 1
    case dolbyVision = 2

    static func < (lhs: StreamDynamicRange, rhs: StreamDynamicRange) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayTitle: String? {
        switch self {
        case .sdr:
            return nil
        case .hdr:
            return "HDR"
        case .dolbyVision:
            return "杜比视界"
        }
    }
}

typealias LiveDynamicRange = StreamDynamicRange

struct LiveStreamCandidate: Equatable {
    let formate: String?
    let url: String
    let current_qn: Int?
    let codec_name: String?
    let width: Int?
    let height: Int?
    let qnDesc: String?
    let frameRateTag: String?
    let dynamicRange: StreamDynamicRange
    let originalOrder: Int

    init(formate: String?,
         url: String,
         current_qn: Int?,
         codec_name: String?,
         width: Int? = nil,
         height: Int? = nil,
         qnDesc: String? = nil,
         frameRateTag: String? = nil,
         dynamicRange: StreamDynamicRange = .sdr,
         originalOrder: Int = 0)
    {
        self.formate = formate
        self.url = url
        self.current_qn = current_qn
        self.codec_name = codec_name
        self.width = width
        self.height = height
        self.qnDesc = qnDesc
        self.frameRateTag = frameRateTag
        self.dynamicRange = dynamicRange
        self.originalOrder = originalOrder
    }
}

typealias LivePlayUrlInfo = LiveStreamCandidate

struct VODStreamCandidate: Equatable {
    let id: Int
    let width: Int?
    let height: Int?
    let frameRate: String?
    let codecs: String
    let bandwidth: Int
    let fallbackDescription: String?
    let streamIndex: Int
}

struct LivePlayUrlPayload: Codable {
    let cid: Int?
    let g_qn_desc: [QnDesc]?
    let stream: [LiveStream]

    enum CodingKeys: String, CodingKey {
        case cid
        case g_qn_desc
        case stream
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cid = try? container.decodeIfPresent(Int.self, forKey: .cid)
        g_qn_desc = try? container.decodeIfPresent([QnDesc].self, forKey: .g_qn_desc)
        stream = (try? container.decodeIfPresent([LiveStream].self, forKey: .stream)) ?? []
    }

    struct QnDesc: Codable {
        let qn: Int
        let desc: String?
        let hdr_desc: String?
        let hdr_type: Int?
        let media_base_desc: MediaBaseDesc?

        struct MediaBaseDesc: Codable {
            let detail_desc: DetailDesc?
            let brief_desc: BriefDesc?

            struct DetailDesc: Codable {
                let desc: String?
                let tag: [String]?
            }

            struct BriefDesc: Codable {
                let desc: String?
            }
        }
    }

    func buildSortedCandidates() -> [LiveStreamCandidate] {
        var qnMap = [Int: QnDesc]()
        for item in g_qn_desc ?? [] {
            qnMap[item.qn] = item
        }

        var candidates = [LiveStreamCandidate]()
        var order = 0

        for streamItem in stream {
            for content in streamItem.format {
                let formatName = content.formatName
                for codec in content.codec {
                    let qn = codec.currentQn
                    let qnEntry = qnMap[qn]
                    let dynamicRange = Self.resolveDynamicRange(codec: codec, qnEntry: qnEntry)
                    let frameRateTag = Self.resolveFrameRateTag(codec: codec, qnEntry: qnEntry)
                    let qnDesc = Self.resolveQnDescription(qnEntry: qnEntry)

                    for urlInfo in codec.urlInfo {
                        let url = "\(urlInfo.host)\(codec.baseurl)\(urlInfo.extra)"
                        candidates.append(
                            LiveStreamCandidate(
                                formate: formatName,
                                url: url,
                                current_qn: qn,
                                codec_name: codec.codecName,
                                width: codec.mediaInfo?.width,
                                height: codec.mediaInfo?.height,
                                qnDesc: qnDesc,
                                frameRateTag: frameRateTag,
                                dynamicRange: dynamicRange,
                                originalOrder: order
                            )
                        )
                        order += 1
                    }
                }
            }
        }

        return StreamMenuFormatting.sortLiveCandidates(candidates)
    }

    private static func resolveDynamicRange(codec: LiveStream.Format.Codec, qnEntry: QnDesc?) -> StreamDynamicRange {
        let metadataTypes = (codec.videoColorInfo?.metadataTypes ?? []).map { $0.lowercased() }
        let colorspace = codec.videoColorInfo?.colorspace?.lowercased() ?? ""
        let qnDescText = qnEntry?.desc ?? ""
        let hdrDescText = qnEntry?.hdr_desc ?? ""

        if (codec.dolbyType ?? 0) > 0
            || codec.currentQn == 30000
            || qnDescText.contains("杜比")
            || metadataTypes.contains(where: { $0.contains("dolby") })
        {
            return .dolbyVision
        }

        let matchesHdrQn = (codec.hdrQn ?? 0) > 0 && codec.hdrQn == codec.currentQn
        if (codec.hdrType ?? 0) > 0
            || matchesHdrQn
            || (qnEntry?.hdr_type ?? 0) > 0
            || !hdrDescText.isEmpty
            || colorspace == "bt2020"
            || metadataTypes.contains(where: { $0.contains("hdr") || $0.contains("hlg") || $0.contains("pq") })
        {
            return .hdr
        }

        return .sdr
    }

    private static func resolveFrameRateTag(codec: LiveStream.Format.Codec, qnEntry: QnDesc?) -> String? {
        if let fps = codec.mediaInfo?.fps, let formatted = StreamMenuFormatting.formatFrameRate(fps) {
            return formatted
        }
        let tags = qnEntry?.media_base_desc?.detail_desc?.tag ?? []
        return tags.first { tag in
            tag.contains("帧") || tag.lowercased().contains("fps")
        }
    }

    private static func resolveQnDescription(qnEntry: QnDesc?) -> String? {
        let candidates = [
            qnEntry?.media_base_desc?.brief_desc?.desc,
            qnEntry?.media_base_desc?.detail_desc?.desc,
            qnEntry?.desc,
        ]
        return candidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }
}

struct LiveStream: Codable {
    let format: [Format]
    let protocol_name: String

    struct Format: Codable {
        let formatName: String
        let codec: [Codec]
        let masterurl: String?

        enum CodingKeys: String, CodingKey {
            case formatName = "format_name"
            case codec
            case masterurl = "master_url"
        }

        struct Codec: Codable {
            let urlInfo: [URLInfo]
            let codecName: String
            let currentQn: Int
            let baseurl: String
            let hdrQn: Int?
            let dolbyType: Int?
            let hdrType: Int?
            let videoColorInfo: VideoColorInfo?
            let mediaInfo: MediaInfo?

            enum CodingKeys: String, CodingKey {
                case urlInfo = "url_info"
                case codecName = "codec_name"
                case currentQn = "current_qn"
                case baseurl = "base_url"
                case hdrQn = "hdr_qn"
                case dolbyType = "dolby_type"
                case hdrType = "hdr_type"
                case videoColorInfo = "video_color_info"
                case mediaInfo = "media_info"
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                urlInfo = try container.decode([URLInfo].self, forKey: .urlInfo)
                codecName = try container.decode(String.self, forKey: .codecName)
                currentQn = try container.decode(Int.self, forKey: .currentQn)
                baseurl = try container.decode(String.self, forKey: .baseurl)
                hdrQn = try? container.decodeIfPresent(Int.self, forKey: .hdrQn)
                dolbyType = try? container.decodeIfPresent(Int.self, forKey: .dolbyType)
                hdrType = try? container.decodeIfPresent(Int.self, forKey: .hdrType)
                videoColorInfo = try? container.decodeIfPresent(VideoColorInfo.self, forKey: .videoColorInfo)
                mediaInfo = try? container.decodeIfPresent(MediaInfo.self, forKey: .mediaInfo)
            }

            struct URLInfo: Codable {
                let host: String
                let extra: String
            }

            struct VideoColorInfo: Codable {
                let colorspace: String?
                let metadataTypes: [String]?

                enum CodingKeys: String, CodingKey {
                    case colorspace
                    case metadataTypes = "metadata_types"
                }
            }

            struct MediaInfo: Codable {
                let width: Int?
                let height: Int?
                let fps: Double?

                enum CodingKeys: String, CodingKey {
                    case width
                    case height
                    case fps
                }

                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    width = try? container.decodeIfPresent(Int.self, forKey: .width)
                    height = try? container.decodeIfPresent(Int.self, forKey: .height)
                    if let numericFPS = try? container.decodeIfPresent(Double.self, forKey: .fps) {
                        fps = numericFPS
                    } else if let stringFPS = try? container.decodeIfPresent(String.self, forKey: .fps) {
                        fps = Double(stringFPS.trimmingCharacters(in: .whitespacesAndNewlines))
                    } else {
                        fps = nil
                    }
                }
            }
        }
    }
}

enum StreamMenuFormatting {
    static func formatFrameRate(_ value: Double) -> String? {
        guard value.isFinite, value > 0 else { return nil }
        let rounded = Int(value.rounded())
        guard rounded > 0 else { return nil }
        return "\(rounded)fps"
    }

    static func formatFrameRate(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        if trimmed.contains("/") {
            let parts = trimmed.split(separator: "/", omittingEmptySubsequences: true)
            guard parts.count == 2,
                  let numerator = Double(parts[0]),
                  let denominator = Double(parts[1]),
                  denominator != 0
            else {
                return nil
            }
            return formatFrameRate(numerator / denominator)
        }
        guard let numeric = Double(trimmed) else { return nil }
        return formatFrameRate(numeric)
    }

    static func vodDynamicRange(id: Int, codecs: String) -> StreamDynamicRange {
        let lower = codecs.lowercased()
        if id == 126 || lower.hasPrefix("dvh1") || lower.hasPrefix("dvhe") {
            return .dolbyVision
        }
        if id == 125 {
            return .hdr
        }
        return .sdr
    }

    static func vodCodecLabel(_ codecs: String) -> String {
        let lower = codecs.lowercased()
        if lower.hasPrefix("avc") {
            return "AVC"
        }
        if lower.hasPrefix("hev") || lower.hasPrefix("hvc") {
            return "HEVC"
        }
        if lower.hasPrefix("dvh1") || lower.hasPrefix("dvhe") {
            return "DVH1"
        }
        if lower.hasPrefix("av01") {
            return "AV1"
        }
        return String(codecs.prefix(4)).uppercased()
    }

    static func formatVODStreamTitle(_ stream: VODStreamCandidate) -> String {
        let dynamicRange = vodDynamicRange(id: stream.id, codecs: stream.codecs)
        let resolution = resolveDisplayResolution(
            width: stream.width,
            height: stream.height,
            fallback: stream.fallbackDescription,
            dynamicRange: dynamicRange,
            defaultIfSDR: "画质 \(stream.id)"
        )
        let fps = formatFrameRate(stream.frameRate)
        let specParts = [resolution, fps, dynamicRange.displayTitle].compactMap { $0 }.filter { !$0.isEmpty }

        let mbps = Double(stream.bandwidth) / 1_000_000.0
        let codecBitrate = String(format: "%@, %.1f Mbps", vodCodecLabel(stream.codecs), mbps)

        if specParts.isEmpty {
            return codecBitrate
        }
        return "\(specParts.joined(separator: " ")) · \(codecBitrate)"
    }

    static func vodCodecRank(_ codecs: String, preferAvc: Bool = false) -> Int {
        let lower = codecs.lowercased()
        if preferAvc {
            if lower.hasPrefix("avc") {
                return 3
            }
            if lower.hasPrefix("dvh1") || lower.hasPrefix("dvhe") || lower.hasPrefix("hev") || lower.hasPrefix("hvc") {
                return 2
            }
            if lower.hasPrefix("av01") {
                return 0
            }
            return 1
        } else {
            if lower.hasPrefix("dvh1") || lower.hasPrefix("dvhe") {
                return 3
            }
            if lower.hasPrefix("hev") || lower.hasPrefix("hvc") {
                return 2
            }
            if lower.hasPrefix("avc") {
                return 1
            }
            return 0
        }
    }

    static func isPreferredVODStream(
        lhsId: Int,
        lhsCodecs: String,
        lhsBandwidth: Int,
        rhsId: Int,
        rhsCodecs: String,
        rhsBandwidth: Int,
        preferAvc: Bool = false
    ) -> Bool {
        if lhsId != rhsId {
            return lhsId > rhsId
        }
        let lhsCodec = vodCodecRank(lhsCodecs, preferAvc: preferAvc)
        let rhsCodec = vodCodecRank(rhsCodecs, preferAvc: preferAvc)
        if lhsCodec != rhsCodec {
            return lhsCodec > rhsCodec
        }
        return lhsBandwidth > rhsBandwidth
    }

    static func sortVODStreams(_ streams: [VODStreamCandidate], preferAvc: Bool = false) -> [VODStreamCandidate] {
        streams.sorted { lhs, rhs in
            if lhs.id != rhs.id || vodCodecRank(lhs.codecs, preferAvc: preferAvc) != vodCodecRank(rhs.codecs, preferAvc: preferAvc) || lhs.bandwidth != rhs.bandwidth {
                return isPreferredVODStream(
                    lhsId: lhs.id,
                    lhsCodecs: lhs.codecs,
                    lhsBandwidth: lhs.bandwidth,
                    rhsId: rhs.id,
                    rhsCodecs: rhs.codecs,
                    rhsBandwidth: rhs.bandwidth,
                    preferAvc: preferAvc
                )
            }
            return lhs.streamIndex < rhs.streamIndex
        }
    }

    static func formatLiveCandidateTitle(index: Int, candidate: LiveStreamCandidate, measuredFPS: Double? = nil) -> String {
        let resolution = resolveDisplayResolution(
            width: candidate.width,
            height: candidate.height,
            fallback: candidate.qnDesc,
            dynamicRange: candidate.dynamicRange,
            defaultIfSDR: nil
        )
        let fpsText = measuredFPS.flatMap(formatFrameRate) ?? candidate.frameRateTag
        let specParts = [resolution, fpsText, candidate.dynamicRange.displayTitle]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let codecPart = [candidate.formate, candidate.codec_name]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")

        let specString = specParts.joined(separator: " ")
        switch (specString.isEmpty, codecPart.isEmpty) {
        case (true, true):
            return "#\(index + 1)"
        case (true, false):
            return "#\(index + 1) \(codecPart)"
        case (false, true):
            return "#\(index + 1) \(specString)"
        case (false, false):
            return "#\(index + 1) \(specString) · \(codecPart)"
        }
    }

    static func sortLiveCandidates(_ candidates: [LiveStreamCandidate]) -> [LiveStreamCandidate] {
        candidates.sorted { lhs, rhs in
            let lhsFormat = liveFormatRank(lhs.formate)
            let rhsFormat = liveFormatRank(rhs.formate)
            if lhsFormat != rhsFormat {
                return lhsFormat > rhsFormat
            }

            let lhsQn = lhs.current_qn ?? 0
            let rhsQn = rhs.current_qn ?? 0
            if lhsQn != rhsQn {
                return lhsQn > rhsQn
            }

            if lhs.dynamicRange != rhs.dynamicRange {
                return lhs.dynamicRange > rhs.dynamicRange
            }

            let lhsCodec = liveCodecRank(lhs.codec_name)
            let rhsCodec = liveCodecRank(rhs.codec_name)
            if lhsCodec != rhsCodec {
                return lhsCodec > rhsCodec
            }

            return lhs.originalOrder < rhs.originalOrder
        }
    }

    static func compactResolutionLabel(width: Int, height: Int) -> String {
        let longSide = max(width, height)
        let shortSide = min(width, height)

        if longSide >= 7000 || shortSide >= 4000 {
            return "8K"
        }
        if longSide >= 3500 || shortSide >= 2000 {
            return "4K"
        }
        if longSide >= 2400 || shortSide >= 1350 {
            return "2K"
        }
        if longSide >= 1800 || shortSide >= 1000 {
            return "1080p"
        }
        if longSide >= 1200 || shortSide >= 680 {
            return "720p"
        }
        if longSide >= 800 || shortSide >= 450 {
            return "480p"
        }
        if longSide >= 600 || shortSide >= 320 {
            return "360p"
        }
        return "\(shortSide)p"
    }

    private static func matchedResolutionTier(in text: String) -> String? {
        let upper = text.uppercased()
        if upper.contains("8K") || upper.contains("4320") {
            return "8K"
        }
        if upper.contains("4K") || upper.contains("2160") {
            return "4K"
        }
        if upper.contains("2K") || upper.contains("1440") {
            return "2K"
        }
        if upper.contains("1080") {
            return "1080p"
        }
        if upper.contains("720") {
            return "720p"
        }
        if upper.contains("480") {
            return "480p"
        }
        if upper.contains("360") {
            return "360p"
        }
        if upper.contains("240") {
            return "240p"
        }
        return nil
    }

    private static func resolveDisplayResolution(
        width: Int?,
        height: Int?,
        fallback: String?,
        dynamicRange: StreamDynamicRange,
        defaultIfSDR: String?
    ) -> String? {
        if let width, let height, width > 0, height > 0 {
            return compactResolutionLabel(width: width, height: height)
        }
        if let trimmed = fallback?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty {
            if let tier = matchedResolutionTier(in: trimmed) {
                return tier
            }
            if dynamicRange == .dolbyVision, trimmed.contains("杜比") {
                return nil
            }
            if dynamicRange == .hdr, trimmed.uppercased().contains("HDR") {
                return nil
            }
            return trimmed
        }
        return dynamicRange == .sdr ? defaultIfSDR : nil
    }

    private static func liveFormatRank(_ format: String?) -> Int {
        switch format?.lowercased() {
        case "fmp4":
            return 2
        case "ts":
            return 1
        default:
            return 0
        }
    }

    private static func liveCodecRank(_ codec: String?) -> Int {
        guard let lower = codec?.lowercased() else { return 0 }
        if lower.contains("hevc") || lower.hasPrefix("hev") || lower.hasPrefix("hvc") {
            return 2
        }
        if lower.contains("avc") || lower.contains("264") {
            return 1
        }
        return 0
    }
}
