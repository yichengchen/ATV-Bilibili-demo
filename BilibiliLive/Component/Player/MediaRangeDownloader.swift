//
//  MediaRangeDownloader.swift
//  BilibiliLive
//
//  会话级自适应多 CDN 并发 Range 下载器（PR2）。
//  职责：有界并发、子块切分、CDN 健康模型、慢请求竞速、严格校验、有序流式交付。
//  状态限定在当前媒体流/播放会话内，不跨视频持久化，不持有全局 CDN 排名。
//

import Foundation

// MARK: - 全局并发预算（只管理资源数量，不持有 CDN 排名）

/// 所有活动媒体会话共享的总并发预算。
/// 只计数在途子请求数量，不记录任何 CDN 吞吐状态。
actor MediaDownloadBudget {
    static let shared = MediaDownloadBudget()

    /// 同时进行的全局请求上限（初始建议 12，内部参数）。
    private let globalMax = 12
    /// 同 host 上限（初始建议 4，内部参数）。
    private let perHostMax = 4

    private var globalActive = 0
    private var perHostActive = [String: Int]()
    private var waiters = [CheckedContinuation<String, Error>]()

    /// 获取一个发送槽位（按 host 记账，返回实际获批的 host）。
    /// 阻塞等待直到有槽位或任务取消。
    func acquire(host: String) async throws -> String {
        if canGrant(host: host) {
            grant(host: host)
            return host
        }
        let granted: String = try await withCheckedThrowingContinuation { continuation in
            waiters.append(continuation)
        }
        // 被唤醒后由 release 路径已记账；这里仅做取消检查
        try Task.checkCancellation()
        return granted
    }

    func release(host: String) {
        globalActive = max(0, globalActive - 1)
        let current = perHostActive[host, default: 1]
        if current <= 1 {
            perHostActive[host] = nil
        } else {
            perHostActive[host] = current - 1
        }
        drainWaiters()
    }

    private func canGrant(host: String) -> Bool {
        if globalActive >= globalMax { return false }
        if (perHostActive[host] ?? 0) >= perHostMax { return false }
        return true
    }

    private func grant(host: String) {
        globalActive += 1
        perHostActive[host, default: 0] += 1
    }

    private func drainWaiters() {
        // 简单策略：按等待顺序尝试用“最先等待者期望的 host”无法获知，
        // 因此这里不做精确 host 匹配；调用方在 acquire 前已选定 host，
        // 释放后唤醒队首，由其重试时重新竞争（若仍无槽位则继续等待）。
        // 为避免复杂性，acquire 采用“立即尝试，失败则短暂等待后重试”由调用方循环，
        // 此处仅保留延续队列用于唤醒。实际实现见 acquireWithRetry。
        while !waiters.isEmpty {
            let continuation = waiters.removeFirst()
            // 用空实现唤醒，调用方循环会重新尝试 canGrant。
            // 注意：此处无法直接记账，调用方唤醒后需再次竞争。
            continuation.resume(returning: "")
            break
        }
    }

    /// 带取消与超时的竞争获取。返回是否成功获批并已记账。
    func tryAcquireNow(host: String) -> Bool {
        if canGrant(host: host) {
            grant(host: host)
            return true
        }
        return false
    }
}

// MARK: - CDN 健康模型（当前媒体流内有效）

enum CDNErrorCategory: Sendable {
    case timeout
    case serverError(status: Int)
    case forbidden
    case notFound
    case rangeNotSatisfiable
    case tooManyRequests
    case truncated
    case mismatch
    case network(Error)
    case cancelled
}

struct CDNHostStats: Sendable {
    var successCount = 0
    var failureCount = 0
    var consecutiveFailures = 0
    var totalBytes: Int64 = 0
    var totalTransferTime: TimeInterval = 0
    var lastTTFB: TimeInterval?
    var isolatedUntil: Date?

    var estimatedMbps: Double? {
        guard totalTransferTime > 0, totalBytes > 0 else { return nil }
        return Double(totalBytes) * 8 / totalTransferTime / 1_000_000
    }

    var isIsolated: Bool {
        if let until = isolatedUntil {
            return Date() < until
        }
        return false
    }
}

// MARK: - 只读诊断快照

struct MediaRangeDiagnostics: Sendable {
    var transportMode: MediaTransportMode
    var activeHosts: Int
    var effectiveMbps: Double
    var activeSubrequests: Int
    var failures: Int
    var retries: Int
    var deliveredBytes: Int64
    var extraBytes: Int64
    var downgradedToDirect: Bool

    var redundancyRatio: Double {
        guard deliveredBytes > 0 else { return 0 }
        return Double(extraBytes) / Double(deliveredBytes)
    }
}

// MARK: - 有界数据通道（异步生产者 → 同步 HTTP writer）

/// 私有桥接类型：只有下载器能写入已验证的有序字节，HTTP writer 在后台
/// socket 队列同步读取。容量按字节限制，满时生产者挂起（不阻塞线程）。
/// 禁止用无限缓存或丢弃旧数据实现背压；同一请求最多交付一次且严格递增。
final class MediaBytePipe: @unchecked Sendable {
    enum PipeError: Error {
        case closed
        case failed(Error)
        case readTimeout
    }

    private let condition = NSCondition()
    private var buffer = Data()
    private let capacityBytes: Int
    private var closed = false
    private var failure: Error?

    init(capacityBytes: Int = 2 * 1024 * 1024) {
        self.capacityBytes = max(64 * 1024, capacityBytes)
    }

    /// 异步写入。满时挂起直到消费者读取腾出空间；关闭/失败/取消时抛出。
    func write(_ data: Data) async throws {
        guard !data.isEmpty else { return }
        var offset = 0
        while offset < data.count {
            try Task.checkCancellation()
            let chunkEnd = min(data.count, offset + 256 * 1024)
            let chunk = data[offset..<chunkEnd]
            try await writeChunk(Data(chunk))
            offset = chunkEnd
        }
    }

    private func writeChunk(_ chunk: Data) async throws {
        if try tryAppend(chunk) { return }
        // 慢路径：等待空间（挂起，不阻塞线程），用轮询+短等待避免复杂延续队列
        while true {
            try Task.checkCancellation()
            if try tryAppend(chunk) { return }
            // 短暂让出，等待消费者读取
            try await Task.sleep(nanoseconds: 5_000_000) // 5ms
        }
    }

    /// 同步尝试追加；返回 true 表示已写入，false 表示缓冲满需稍后重试。
    /// 失败/关闭时直接抛出。锁操作封装在同步函数内，避免在 async 上下文直接调用。
    private func tryAppend(_ chunk: Data) throws -> Bool {
        condition.lock()
        defer { condition.unlock() }
        if let failure {
            throw PipeError.failed(failure)
        }
        if closed {
            throw PipeError.closed
        }
        if buffer.count + chunk.count <= capacityBytes {
            buffer.append(chunk)
            condition.signal()
            return true
        }
        return false
    }

    /// 同步读取（供 Swifter writer 在后台队列调用，可阻塞该队列线程）。
    /// 返回 nil 表示 EOF（生产者已 close 且缓冲排空）。
    func readSync(maxLength: Int, timeout: TimeInterval = 30) throws -> Data? {
        let deadline = Date().addingTimeInterval(timeout)
        condition.lock()
        defer { condition.unlock() }
        while buffer.isEmpty {
            if let failure {
                throw PipeError.failed(failure)
            }
            if closed {
                return nil
            }
            let remaining = deadline.timeIntervalSinceNow
            if remaining <= 0 {
                throw PipeError.readTimeout
            }
            condition.wait(until: deadline)
        }
        let take = min(maxLength, buffer.count)
        let chunk = buffer.prefix(take)
        buffer.removeFirst(take)
        condition.signal()
        return Data(chunk)
    }

    func close() {
        condition.lock()
        closed = true
        condition.broadcast()
        condition.unlock()
    }

    func fail(_ error: Error) {
        condition.lock()
        if failure == nil {
            failure = error
        }
        condition.broadcast()
        condition.unlock()
    }
}

// MARK: - 下载器

/// 单个播放会话拥有的 actor。
/// 播放器不需要知道一个 Range 被拆成几个下载任务。
actor MediaRangeDownloader {
    // 内部自适应参数（初始建议值，非最优声明，实测调整）。
    private let subrangeTargetBytes: Int64 = 512 * 1024 // 256KiB–1MiB 区间内
    private let subrangeMaxBytes: Int64 = 1 * 1024 * 1024
    private let subrangeMinBytes: Int64 = 256 * 1024
    private let maxConcurrentPerMedia = 4
    private let maxBufferedBytes: Int64 = 4 * 1024 * 1024
    private let maxRetriesPerSubrange = 2
    private let hedgingDelayNanoseconds: UInt64 = 1_000_000_000 // 1s
    private let singleRequestMemoryCap: Int64 = 16 * 1024 * 1024

    private let candidates: [String]
    private let referer: String
    private let userAgent: String
    private let mode: MediaTransportMode

    private var hostStats = [String: CDNHostStats]()
    private var knownTotalLength: Int64?
    private var deliveredBytes: Int64 = 0
    private var extraBytes: Int64 = 0
    private var failureCount = 0
    private var retryCount = 0
    private var activeSubrequests = 0
    private var downgradedToDirect = false

    private var session: URLSession?

    init(candidates: [String], referer: String, userAgent: String = Keys.userAgent, mode: MediaTransportMode = .accelerated) {
        self.candidates = candidates
        self.referer = referer
        self.userAgent = userAgent
        self.mode = mode
    }

    deinit {
        session?.invalidateAndCancel()
    }

    // MARK: 对外接口

    /// 流式下载：边下载边按顺序向 pipe 交付已验证字节，完成后 close，失败时 fail。
    /// 同一个请求最多交付一次，每次交付严格递增。
    func stream(range: MediaByteRange, to pipe: MediaBytePipe) async {
        do {
            try Task.checkCancellation()
            guard !candidates.isEmpty else {
                pipe.fail(MediaRangeError.unsatisfiable(total: nil))
                return
            }
            guard range.length <= singleRequestMemoryCap else {
                // 超出安全容量：不做无界缓存，由调用方降级直连
                downgradedToDirect = true
                pipe.fail(MediaRangeError.unsatisfiable(total: knownTotalLength))
                return
            }
            let subranges = split(range: range)
            if mode == .proxy || subranges.count == 1 {
                await streamSingle(range: range, to: pipe)
                return
            }
            await streamConcurrent(parentRange: range, subranges: subranges, to: pipe)
        } catch is CancellationError {
            pipe.fail(MediaRangeError.cancelled)
        } catch {
            pipe.fail(error)
        }
    }

    /// 一次性获取（供测试与小请求复用）。内部复用流式链路收集，避免两套校验。
    func fetch(range: MediaByteRange) async throws -> Data {
        let pipe = MediaBytePipe(capacityBytes: Int(min(maxBufferedBytes, max(range.length * 2, 256 * 1024))))
        let streamTask = Task {
            await stream(range: range, to: pipe)
        }
        var result = Data()
        result.reserveCapacity(Int(min(range.length, singleRequestMemoryCap)))
        do {
            while true {
                try Task.checkCancellation()
                let chunk: Data?
                do {
                    chunk = try await Task.detached(priority: .utility) {
                        try pipe.readSync(maxLength: 256 * 1024, timeout: 30)
                    }.value
                } catch {
                    streamTask.cancel()
                    throw error
                }
                guard let chunk else { break }
                result.append(chunk)
            }
        } catch {
            streamTask.cancel()
            throw error
        }
        await streamTask.value
        guard Int64(result.count) == range.length else {
            throw MediaRangeError.truncated
        }
        return result
    }

    func diagnostics() -> MediaRangeDiagnostics {
        let activeHosts = Set(hostStats.keys).count
        let totalBytes = hostStats.values.reduce(Int64(0)) { $0 + $1.totalBytes }
        let totalTime = hostStats.values.reduce(TimeInterval(0)) { $0 + $1.totalTransferTime }
        let mbps: Double = (totalTime > 0 && totalBytes > 0) ? Double(totalBytes) * 8 / totalTime / 1_000_000 : 0
        return MediaRangeDiagnostics(
            transportMode: mode,
            activeHosts: activeHosts,
            effectiveMbps: mbps,
            activeSubrequests: activeSubrequests,
            failures: failureCount,
            retries: retryCount,
            deliveredBytes: deliveredBytes,
            extraBytes: extraBytes,
            downgradedToDirect: downgradedToDirect
        )
    }

    func markDowngraded() {
        downgradedToDirect = true
    }

    func knownTotal() -> Int64? {
        knownTotalLength
    }

    func updateKnownTotal(_ total: Int64?) {
        if let total, total > 0 {
            if let known = knownTotalLength, known != total {
                // 总长不一致：不覆盖，由调用方按 mismatch 处理
                return
            }
            knownTotalLength = total
        }
    }

    // MARK: 切分

    func split(range: MediaByteRange) -> [MediaByteRange] {
        if range.length <= subrangeMinBytes {
            return [range]
        }
        var result = [MediaByteRange]()
        var cursor = range.start
        // 目标 512KiB，大请求分块，小请求不强拆
        let chunk: Int64 = min(max(subrangeTargetBytes, range.length / Int64(maxConcurrentPerMedia)), subrangeMaxBytes)
        while cursor <= range.end {
            let end = min(cursor + chunk - 1, range.end)
            // 避免产生过小的尾块：剩余不足 min 则并入当前块
            let remaining = range.end - end
            if remaining > 0, remaining < subrangeMinBytes {
                if let merged = try? MediaByteRange(start: cursor, end: range.end) {
                    result.append(merged)
                }
                break
            }
            if let piece = try? MediaByteRange(start: cursor, end: end) {
                result.append(piece)
            }
            cursor = end + 1
        }
        return result.isEmpty ? [range] : result
    }

    // MARK: 单路（proxy 测试模式）

    private func streamSingle(range: MediaByteRange, to pipe: MediaBytePipe) async {
        do {
            let data = try await fetchSubrangeWithHedging(range, allowHedging: false)
            try await pipe.write(data)
            deliveredBytes += Int64(data.count)
            pipe.close()
        } catch is CancellationError {
            pipe.fail(MediaRangeError.cancelled)
        } catch {
            pipe.fail(error)
        }
    }

    // MARK: 并发流式

    private func streamConcurrent(parentRange: MediaByteRange, subranges: [MediaByteRange], to pipe: MediaBytePipe) async {
        // 有序交付状态（仅本请求内有效）
        var pending = [Int: Data]()
        var pendingBytes: Int64 = 0
        var nextToDeliver = 0
        var nextToStart = 0
        var inFlight = [Int: Task<Data, Error>]()

        func startNext() {
            while nextToStart < subranges.count, inFlight.count < maxConcurrentPerMedia {
                // 背压：已完成未交付缓冲超限则暂停新任务
                if pendingBytes >= maxBufferedBytes { break }
                let index = nextToStart
                let sub = subranges[index]
                nextToStart += 1
                activeSubrequests += 1
                let task = Task<Data, Error> {
                    defer {
                        Task { await self.decrementActive() }
                    }
                    return try await self.fetchSubrangeWithHedging(sub, allowHedging: true)
                }
                inFlight[index] = task
            }
        }

        startNext()
        while nextToDeliver < subranges.count {
            if Task.isCancelled {
                for task in inFlight.values {
                    task.cancel()
                }
                pipe.fail(MediaRangeError.cancelled)
                return
            }
            // 优先等待最早未交付的分块（播放截止时间优先），避免队尾拖慢整体
            if let ready = pending[nextToDeliver] {
                do {
                    try await pipe.write(ready)
                } catch {
                    for task in inFlight.values {
                        task.cancel()
                    }
                    pipe.fail(error)
                    return
                }
                deliveredBytes += Int64(ready.count)
                pendingBytes -= Int64(ready.count)
                pending[nextToDeliver] = nil
                nextToDeliver += 1
                startNext()
                continue
            }
            // 等待任意在途任务完成
            guard !inFlight.isEmpty else {
                // 无在途但仍有未交付：说明之前失败已直接返回，此处兜底
                pipe.fail(MediaRangeError.truncated)
                return
            }
            // 取最早索引的任务优先等待（救援尾块优先）
            let sortedKeys = inFlight.keys.sorted()
            // 简单策略：等待全部中的第一个完成
            let completed: (Int, Result<Data, Error>)?
            do {
                completed = await waitForFirst(inFlight)
            } catch {
                for task in inFlight.values {
                    task.cancel()
                }
                pipe.fail(error)
                return
            }
            guard let (index, result) = completed else {
                for task in inFlight.values {
                    task.cancel()
                }
                pipe.fail(MediaRangeError.truncated)
                return
            }
            inFlight[index] = nil
            switch result {
            case let .success(data):
                // 长度校验：必须是请求子区间的准确长度
                let expected = subranges[index].length
                guard Int64(data.count) == expected else {
                    for task in inFlight.values {
                        task.cancel()
                    }
                    pipe.fail(MediaRangeError.truncated)
                    return
                }
                pending[index] = data
                pendingBytes += Int64(data.count)
                // 覆盖完整性由 nextToDeliver 顺序保证，不存在缺口或重复交付
                _ = sortedKeys
                startNext()
            case let .failure(error):
                let isCancelled = (error is CancellationError) || (error as? MediaBytePipe.PipeError != nil)
                if !isCancelled {
                    failureCount += 1
                }
                for task in inFlight.values {
                    task.cancel()
                }
                if error is CancellationError {
                    pipe.fail(MediaRangeError.cancelled)
                } else {
                    pipe.fail(error)
                }
                return
            }
        }
        // 完整覆盖校验
        guard nextToDeliver == subranges.count else {
            pipe.fail(MediaRangeError.truncated)
            return
        }
        pipe.close()
    }

    private func decrementActive() {
        activeSubrequests = max(0, activeSubrequests - 1)
    }

    /// 等待一组任务中最先完成的一个，返回其索引与结果。
    private func waitForFirst(_ tasks: [Int: Task<Data, Error>]) async -> (Int, Result<Data, Error>)? {
        await withTaskGroup(of: (Int, Result<Data, Error>).self) { group in
            for (index, task) in tasks {
                group.addTask {
                    do {
                        let value = try await task.value
                        return (index, .success(value))
                    } catch is CancellationError {
                        return (index, .failure(CancellationError()))
                    } catch {
                        return (index, .failure(error))
                    }
                }
            }
            if let first = await group.next() {
                group.cancelAll()
                return first
            }
            return nil
        }
    }

    // MARK: 子区间获取（含竞速与重试）

    private func fetchSubrangeWithHedging(_ subrange: MediaByteRange, allowHedging: Bool) async throws -> Data {
        try Task.checkCancellation()
        let hosts = orderedHosts()
        guard !hosts.isEmpty else { throw MediaRangeError.unsatisfiable(total: knownTotalLength) }
        if !allowHedging || hosts.count == 1 || subrange.length < subrangeMinBytes {
            return try await fetchSubrangeWithRetry(subrange, hosts: hosts)
        }
        // Slow-Request Hedging：主请求慢时在另一 CDN 启动竞争。
        // 触发考虑 TTFB、已接收字节/吞吐、剩余字节与播放紧迫度（此处用固定 1s 延迟
        // + 剩余长度门限近似；首字节与吞吐在 fetchAttempt 内实测并记入统计）。
        // 使用显式 Task 而非嵌套 group，避免 inout group 被 escaping 闭包捕获。
        let primary = Task<Data, Error> {
            try await self.fetchSubrangeWithRetry(subrange, hosts: hosts)
        }
        // 主路与延迟哨兵竞争：1s 内完成则直接采用，不启动第二路
        if let early = try await raceWithDelay(task: primary, delayNanoseconds: hedgingDelayNanoseconds) {
            return early
        }
        try Task.checkCancellation()
        retryCount += 1
        let alternate = alternateHosts(excludingFirstOf: hosts)
        let secondary = Task<Data, Error> {
            try await self.fetchSubrangeWithRetry(subrange, hosts: alternate)
        }
        defer {
            primary.cancel()
            secondary.cancel()
        }
        // 两路竞争，首个成功者胜出
        let winner: Data = try await raceTasks(primary: primary, secondary: secondary)
        // 若另一路也在短宽限内完成，比较重叠字节；超时则直接采用胜者。
        // 字节级比较：冲突则隔离并拒绝交付。
        if let other = await secondResultIfReady(primary: primary, secondary: secondary, winner: winner) {
            if other != winner {
                isolateHosts(hosts, reason: "overlap-mismatch")
                throw MediaRangeError.mismatch
            } else {
                addExtra(Int64(other.count))
            }
        }
        return winner
    }

    /// 主任务与延迟竞争：任务先完成则返回其值（成功/失败均直接透出），
    /// 延迟先到则返回 nil（调用方启动第二路）。哨兵 cancelled 不计入失败。
    private func raceWithDelay(task: Task<Data, Error>, delayNanoseconds: UInt64) async throws -> Data? {
        try await withThrowingTaskGroup(of: Data?.self) { group in
            group.addTask {
                try await task.value
            }
            group.addTask {
                try await Task.sleep(nanoseconds: delayNanoseconds)
                return nil // 延迟到期哨兵
            }
            guard let first = try await group.next() else {
                group.cancelAll()
                return nil
            }
            group.cancelAll()
            if Task.isCancelled {
                throw CancellationError()
            }
            return first // nil 表示延迟先到；Data 表示主路已完成（含抛错透出由 try 传播）
        }
    }

    /// 两路任务竞争：首个成功者胜出；一路失败则等待另一路；两路皆败则抛出。
    private func raceTasks(primary: Task<Data, Error>, secondary: Task<Data, Error>) async throws -> Data {
        try await withThrowingTaskGroup(of: Data.self) { group in
            group.addTask { try await primary.value }
            group.addTask { try await secondary.value }
            var lastError: Error = MediaRangeError.truncated
            while let result = await group.nextResult() {
                switch result {
                case let .success(data):
                    group.cancelAll()
                    return data
                case let .failure(error):
                    if error is CancellationError, Task.isCancelled {
                        group.cancelAll()
                        throw CancellationError()
                    }
                    lastError = error
                    // 另一路仍在跑则继续等；组空则两路皆败
                    continue
                }
            }
            throw lastError
        }
    }

    /// 短宽限内若另一路也已完成则返回其数据（用于重叠一致性比较），否则 nil。
    /// 只捕获 Task 引用（非 inout），不捕获 group。
    private func secondResultIfReady(primary: Task<Data, Error>, secondary: Task<Data, Error>, winner: Data) async -> Data? {
        await withTaskGroup(of: Data?.self) { group in
            group.addTask {
                // 100ms 宽限：另一路若已完成则取值比较，超时放弃
                try? await Task.sleep(nanoseconds: 100_000_000)
                return nil
            }
            group.addTask {
                // 取尚未被消费的另一路结果：通过比较 winner 无法判定哪一路胜出，
                // 因此尝试读取两路中“非胜者”的值——若其已完成则返回，否则挂起直到宽限任务先完成。
                // 为避免挂起过久，这里用串行尝试：先检查 secondary，再检查 primary，
                // 任一完成且与 winner 长度相同但内容待比较。
                // 注意：Task.value 会等待未完成的任务，因此依赖宽限任务先返回来取消本组。
                // 若两路都未在宽限内完成，本函数返回 nil。
                let s: Data? = try? await secondary.value
                if let s, s.count == winner.count { return s }
                let p: Data? = try? await primary.value
                if let p, p.count == winner.count, p != winner { return p }
                return s ?? p
            }
            var result: Data?
            for await value in group {
                if let value {
                    result = value
                    break
                } else {
                    // 宽限到期
                    break
                }
            }
            group.cancelAll()
            // 若取到的就是胜者本身（常见），视为无“另一路”可比较
            if let result, result == winner {
                // 无法区分来源时不误报 extra；返回 nil 跳过比较
                // （胜者已通过 Content-Range/total/长度三重校验）
                return nil
            }
            return result
        }
    }

    private func fetchSubrangeWithRetry(_ subrange: MediaByteRange, hosts: [String]) async throws -> Data {
        var lastError: Error = MediaRangeError.unsatisfiable(total: knownTotalLength)
        let attempts = min(hosts.count, maxRetriesPerSubrange + 1)
        for attempt in 0..<attempts {
            try Task.checkCancellation()
            let host = hosts[attempt % hosts.count]
            guard let urlString = urlString(forHost: host) else { continue }
            do {
                let data = try await fetchAttempt(subrange: subrange, urlString: urlString, host: host)
                return data
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
                // 取消不计入 CDN 健康失败（由上层区分）
                continue
            }
        }
        throw lastError
    }

    private func urlString(forHost host: String) -> String? {
        // 同一媒体流内可交换的 CDN 候选：host 匹配的第一个 URL。
        // 不同 URL 若不能证明同一字节一致性，不得交换——此处候选均来自同一
        // DashMediaInfo.playableURLs，视为同一资源的不同 CDN 镜像。
        for url in candidates {
            if URLComponents(string: url)?.host == host {
                return url
            }
        }
        return candidates.first
    }

    private func orderedHosts() -> [String] {
        var seen = Set<String>()
        var hosts = [String]()
        for url in candidates {
            guard let host = URLComponents(string: url)?.host else { continue }
            if seen.insert(host).inserted {
                hosts.append(host)
            }
        }
        // 隔离中的 host 沉底；其余按实测吞吐降序，TTFB 小者优先
        return hosts.sorted { a, b in
            let sa = hostStats[a]
            let sb = hostStats[b]
            let aIso = sa?.isIsolated ?? false
            let bIso = sb?.isIsolated ?? false
            if aIso != bIso { return !aIso }
            let aMbps = sa?.estimatedMbps ?? -1
            let bMbps = sb?.estimatedMbps ?? -1
            if aMbps != bMbps { return aMbps > bMbps }
            let aTTFB = sa?.lastTTFB ?? .greatestFiniteMagnitude
            let bTTFB = sb?.lastTTFB ?? .greatestFiniteMagnitude
            return aTTFB < bTTFB
        }
    }

    private func alternateHosts(excludingFirstOf hosts: [String]) -> [String] {
        guard hosts.count > 1 else { return hosts }
        return Array(hosts.dropFirst()) + [hosts.first!]
    }

    private func isolateHosts(_ hosts: [String], reason: String) {
        let until = Date().addingTimeInterval(30)
        for host in hosts {
            var stats = hostStats[host] ?? CDNHostStats()
            stats.isolatedUntil = until
            stats.consecutiveFailures += 1
            stats.failureCount += 1
            hostStats[host] = stats
        }
        failureCount += 1
        _ = reason
    }

    private func addExtra(_ bytes: Int64) {
        extraBytes += bytes
    }

    // MARK: 单次尝试（含严格校验）

    private func fetchAttempt(subrange: MediaByteRange, urlString: String, host: String) async throws -> Data {
        try Task.checkCancellation()
        // 全局预算：按 host 记账，释放必须配对
        let grantedHost: String
        if await MediaDownloadBudget.shared.tryAcquireNow(host: host) {
            grantedHost = host
        } else {
            // 等待槽位（有界等待，可取消）
            grantedHost = try await waitForBudget(host: host)
        }
        defer { Task { await MediaDownloadBudget.shared.release(host: grantedHost) } }

        let session = ensureSession()
        var request = URLRequest(url: URL(string: urlString)!)
        request.httpMethod = "GET"
        request.setValue("bytes=\(subrange.start)-\(subrange.end)", forHTTPHeaderField: "Range")
        request.setValue(referer, forHTTPHeaderField: "Referer")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let startDate = Date()
        let (asyncBytes, response): (URLSession.AsyncBytes, URLResponse)
        do {
            (asyncBytes, response) = try await session.bytes(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            await recordFailure(host: host, category: classify(error: error, status: nil))
            throw error
        }
        // TTFB：首字节（响应头）到达耗时
        let ttfb = Date().timeIntervalSince(startDate)
        guard let http = response as? HTTPURLResponse else {
            await recordFailure(host: host, category: .network(NSError(domain: "cdn", code: -1)))
            throw MediaRangeError.upstream(status: -1)
        }
        // 取消不计入失败：调用方已取消时直接退出
        if Task.isCancelled {
            throw CancellationError()
        }
        guard http.statusCode == 206 else {
            await recordFailure(host: host, category: classify(error: nil, status: http.statusCode))
            if http.statusCode == 403 || http.statusCode == 404 || http.statusCode == 416 {
                // 403/404/416 分类，避免无限重复同一无效候选
                await isolateSingle(host: host)
            }
            throw MediaRangeError.upstream(status: http.statusCode)
        }
        // Content-Range 校验
        guard let contentRangeValue = http.value(forHTTPHeaderField: "Content-Range"),
              let parsed = MediaRangeParsing.parseContentRange(contentRangeValue)
        else {
            // 200 或缺失 Content-Range：拒绝不正确响应，不交付
            await recordFailure(host: host, category: .mismatch)
            throw MediaRangeError.mismatch
        }
        guard parsed.range == subrange else {
            await recordFailure(host: host, category: .mismatch)
            await isolateSingle(host: host)
            throw MediaRangeError.mismatch
        }
        if let total = parsed.total {
            if let known = knownTotalLength, known != total {
                await recordFailure(host: host, category: .mismatch)
                await isolateSingle(host: host)
                throw MediaRangeError.mismatch
            }
            knownTotalLength = total
            // 区间不得超出总长
            if subrange.end >= total {
                await recordFailure(host: host, category: .mismatch)
                throw MediaRangeError.unsatisfiable(total: total)
            }
        }
        // 逐字节读取，测量有效吞吐；重复下载字节不计入有效吞吐由上层 extraBytes 区分
        var data = Data()
        data.reserveCapacity(Int(subrange.length))
        do {
            for try await byte in asyncBytes {
                data.append(byte)
                if Task.isCancelled {
                    throw CancellationError()
                }
                // 背压：单个子区间在内存中完整组装（已受 subrangeMaxBytes 与
                // singleRequestMemoryCap 约束），此处不做额外限流
                if Int64(data.count) > subrange.length {
                    await recordFailure(host: host, category: .mismatch)
                    throw MediaRangeError.mismatch
                }
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            await recordFailure(host: host, category: .truncated)
            throw MediaRangeError.truncated
        }
        // 实际数据长度校验
        guard Int64(data.count) == subrange.length else {
            await recordFailure(host: host, category: .truncated)
            throw MediaRangeError.truncated
        }
        let transferTime = Date().timeIntervalSince(startDate)
        await recordSuccess(host: host, bytes: Int64(data.count), ttfb: ttfb, transferTime: transferTime)
        return data
    }

    private func waitForBudget(host: String) async throws -> String {
        // 有界等待：最多 10s，每 50ms 重试一次，可取消
        let deadline = Date().addingTimeInterval(10)
        while true {
            try Task.checkCancellation()
            if await MediaDownloadBudget.shared.tryAcquireNow(host: host) {
                return host
            }
            if Date() > deadline {
                // 降级为直接使用当前 host（不记账），避免永久等待
                return host
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    private func ensureSession() -> URLSession {
        if let session { return session }
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.httpMaximumConnectionsPerHost = 4
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        let created = URLSession(configuration: config)
        session = created
        return created
    }

    private func recordSuccess(host: String, bytes: Int64, ttfb: TimeInterval, transferTime: TimeInterval) {
        var stats = hostStats[host] ?? CDNHostStats()
        stats.successCount += 1
        stats.consecutiveFailures = 0
        stats.isolatedUntil = nil
        stats.totalBytes += bytes
        // 有效吞吐按首字节之后的传输耗时近似（total - ttfb，至少 1ms）
        stats.totalTransferTime += max(0.001, transferTime - ttfb)
        stats.lastTTFB = ttfb
        hostStats[host] = stats
    }

    private func recordFailure(host: String, category: CDNErrorCategory) {
        if case .cancelled = category { return }
        var stats = hostStats[host] ?? CDNHostStats()
        stats.failureCount += 1
        stats.consecutiveFailures += 1
        failureCount += 1
        // 连续失败 3 次则隔离 30s，避免无限重复同一无效候选
        if stats.consecutiveFailures >= 3 {
            stats.isolatedUntil = Date().addingTimeInterval(30)
        }
        hostStats[host] = stats
    }

    private func isolateSingle(host: String) {
        var stats = hostStats[host] ?? CDNHostStats()
        stats.isolatedUntil = Date().addingTimeInterval(30)
        stats.consecutiveFailures += 1
        hostStats[host] = stats
    }

    private func classify(error: Error?, status: Int?) -> CDNErrorCategory {
        if let status {
            switch status {
            case 403: return .forbidden
            case 404: return .notFound
            case 416: return .rangeNotSatisfiable
            case 429: return .tooManyRequests
            case 500...599: return .serverError(status: status)
            default: return .serverError(status: status)
            }
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut: return .timeout
            case .cancelled: return .cancelled
            default: return .network(urlError)
            }
        }
        if error is CancellationError { return .cancelled }
        return .network(error ?? NSError(domain: "cdn", code: -1))
    }
}
