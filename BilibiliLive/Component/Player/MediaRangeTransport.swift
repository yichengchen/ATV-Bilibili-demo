//
//  MediaRangeTransport.swift
//  BilibiliLive
//
//  本地 loopback HTTP Range 传输基础层（PR1）。
//  职责：传输模式定义、不可变字节区间、Range/Content-Range 解析与响应头构造。
//  不涉及播放器、SIDX、HLS 分段逻辑；不持有跨视频状态。
//

import Foundation

/// 内部执行模式，不是用户设置。
/// - direct: 原路径，直连 CDN
/// - proxy: 单 CDN 代理测试
/// - accelerated: 多 CDN 并发加速
enum MediaTransportMode: Hashable, Sendable {
    case direct
    case proxy
    case accelerated
}

/// 不可变单区间 [start, end]（闭区间）。
struct MediaByteRange: Equatable, Hashable, Sendable {
    let start: Int64
    let end: Int64

    var length: Int64 {
        end - start + 1
    }

    init(start: Int64, end: Int64) throws {
        guard start >= 0 else { throw MediaRangeError.invalidRange }
        guard end >= start else { throw MediaRangeError.invalidRange }
        // end - start + 1 不得溢出
        guard end - start < Int64.max else { throw MediaRangeError.invalidRange }
        self.start = start
        self.end = end
    }

    /// Content-Range 响应头值。total 未知时按 RFC 使用 *。
    func contentRangeValue(totalLength: Int64?) -> String {
        if let totalLength {
            return "bytes \(start)-\(end)/\(totalLength)"
        } else {
            return "bytes \(start)-\(end)/*"
        }
    }
}

enum MediaRangeError: Error, Equatable, Sendable {
    case invalidRange
    case unsatisfiable(total: Int64?)
    case multiRangeUnsupported
    case needsTotalLengthUnbounded(kind: UnboundedKind)
    case upstream(status: Int)
    case truncated
    case mismatch
    case cancelled

    enum UnboundedKind: Sendable, Equatable {
        case openEnded(start: Int64)
        case suffix(length: Int64)
    }
}

/// Range 请求解析结果。
enum ParsedMediaRange: Equatable, Sendable {
    /// 已归一化的有界区间，可直接下载。
    case single(MediaByteRange)
    /// 缺少 Range 头（整文件请求）。调用方应走直连重定向降级，不伪造 206。
    case missing
    /// 多区间请求。不拼接为单个 206，由调用方返回 416。
    case multiUnsupported
    /// bytes=start-，需获知 total 后归一化。
    case openEnded(start: Int64)
    /// bytes=-suffix，需获知 total 后归一化。
    case suffix(length: Int64)
    /// 语法非法。
    case invalid
    /// 越界（已知 total 下 start >= total 等）。
    case unsatisfiable(total: Int64?)
}

enum MediaRangeParsing {
    /// 解析 HTTP Range 请求头。
    /// - Parameters:
    ///   - header: request.headers["range"]（已小写 key，值大小写不敏感）
    ///   - fileLength: 已知文件总长；未知传 nil
    static func parse(header: String?, fileLength: Int64?) -> ParsedMediaRange {
        guard let header = header?.trimmingCharacters(in: .whitespacesAndNewlines), !header.isEmpty else {
            return .missing
        }
        // 仅支持 bytes 单位
        let lower = header.lowercased()
        guard lower.hasPrefix("bytes=") else { return .invalid }
        let spec = String(header.dropFirst("bytes=".count)).trimmingCharacters(in: .whitespaces)
        guard !spec.isEmpty else { return .invalid }
        // 多个范围请求：不擅自拼接
        if spec.contains(",") {
            return .multiUnsupported
        }
        // 期望 start-end / start- / -suffix 三种形态
        if spec.hasPrefix("-") {
            let suffixStr = String(spec.dropFirst()).trimmingCharacters(in: .whitespaces)
            guard let suffix = parseNonNegativeInt64(suffixStr), suffix > 0 else { return .invalid }
            guard let fileLength else { return .suffix(length: suffix) }
            guard fileLength > 0 else { return .unsatisfiable(total: fileLength) }
            let take = min(suffix, fileLength)
            let start = fileLength - take
            let end = fileLength - 1
            guard let range = try? MediaByteRange(start: start, end: end) else { return .invalid }
            return .single(range)
        }
        let parts = spec.split(separator: "-", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 2 else { return .invalid }
        let startStr = parts[0].trimmingCharacters(in: .whitespaces)
        let endStr = parts[1].trimmingCharacters(in: .whitespaces)
        guard let start = parseNonNegativeInt64(startStr) else { return .invalid }
        if endStr.isEmpty {
            // bytes=start-
            if let fileLength {
                guard fileLength > 0 else { return .unsatisfiable(total: fileLength) }
                guard start < fileLength else { return .unsatisfiable(total: fileLength) }
                guard let range = try? MediaByteRange(start: start, end: fileLength - 1) else { return .invalid }
                return .single(range)
            } else {
                return .openEnded(start: start)
            }
        } else {
            guard let end = parseNonNegativeInt64(endStr) else { return .invalid }
            guard let range = try? MediaByteRange(start: start, end: end) else { return .invalid }
            if let fileLength {
                // 越界检查：起点超出或区间超出总长
                guard fileLength > 0 else { return .unsatisfiable(total: fileLength) }
                guard start < fileLength else { return .unsatisfiable(total: fileLength) }
                guard end < fileLength else { return .unsatisfiable(total: fileLength) }
            }
            return .single(range)
        }
    }

    /// 在获知 total 后，将 openEnded/suffix 归一化为有界区间。
    static func normalizeUnbounded(_ parsed: ParsedMediaRange, fileLength: Int64) -> ParsedMediaRange {
        switch parsed {
        case let .openEnded(start):
            return parse(header: "bytes=\(start)-", fileLength: fileLength)
        case let .suffix(length):
            return parse(header: "bytes=-\(length)", fileLength: fileLength)
        default:
            return parsed
        }
    }

    /// 解析上游 Content-Range，如 "bytes 0-1023/4096" 或 "bytes 0-1023/*"。
    static func parseContentRange(_ value: String) -> (range: MediaByteRange, total: Int64?)? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmed.hasPrefix("bytes ") else { return nil }
        let remainder = String(trimmed.dropFirst("bytes ".count)).trimmingCharacters(in: .whitespaces)
        let slashParts = remainder.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard slashParts.count == 2 else { return nil }
        let rangePart = slashParts[0].trimmingCharacters(in: .whitespaces)
        let totalPart = slashParts[1].trimmingCharacters(in: .whitespaces)
        let dashParts = rangePart.split(separator: "-", omittingEmptySubsequences: false).map(String.init)
        guard dashParts.count == 2,
              let start = parseNonNegativeInt64(dashParts[0].trimmingCharacters(in: .whitespaces)),
              let end = parseNonNegativeInt64(dashParts[1].trimmingCharacters(in: .whitespaces)),
              let range = try? MediaByteRange(start: start, end: end)
        else { return nil }
        let total: Int64?
        if totalPart == "*" {
            total = nil
        } else {
            guard let t = parseNonNegativeInt64(totalPart) else { return nil }
            total = t
        }
        return (range, total)
    }

    static func parseNonNegativeInt64(_ s: String) -> Int64? {
        guard !s.isEmpty else { return nil }
        // 拒绝非数字、前导 +/空格已在外层处理
        guard s.allSatisfy({ $0.isNumber }) else { return nil }
        // Int64 无溢出
        return Int64(s)
    }
}

enum MediaRangeResponseHeaders {
    /// 206 响应头。Swifter 的 .raw 不会自动推算 Content-Length，必须显式设置。
    static func partialContent(range: MediaByteRange, totalLength: Int64?) -> [String: String] {
        [
            "Content-Range": range.contentRangeValue(totalLength: totalLength),
            "Content-Length": "\(range.length)",
            "Accept-Ranges": "bytes",
            "Content-Type": "video/mp4",
        ]
    }

    /// HEAD 响应头（无 body）。
    static func head(totalLength: Int64?) -> [String: String] {
        var headers = ["Accept-Ranges": "bytes"]
        if let totalLength {
            headers["Content-Length"] = "\(totalLength)"
            headers["Content-Type"] = "video/mp4"
        } else {
            headers["Content-Type"] = "video/mp4"
        }
        return headers
    }

    /// 416 响应头。total 已知时必须带 Content-Range: bytes */total。
    static func rangeNotSatisfiable(totalLength: Int64?) -> [String: String] {
        if let totalLength {
            return ["Content-Range": "bytes */\(totalLength)"]
        } else {
            return [:]
        }
    }
}
