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
/// 许可与释放通过 BudgetPermit token 一一绑定：一次获取最多释放一次，
/// 未持许可的请求不得发送，避免绕过上限或重复释放破坏计数。
actor MediaDownloadBudget {
    static let shared = MediaDownloadBudget()

    /// 同时进行的全局请求上限（内部参数，实测调整）。
    private let globalMax = 12
    /// 同 host 上限（内部参数，实测调整）。
    private let perHostMax = 4

    /// 已发出的有效许可集合；释放时必须持有对应 token，否则忽略。
    private var outstanding = Set<BudgetPermit>()
    private var perHostActive = [String: Int]()

    /// 立即尝试获取许可；无槽位时返回 nil（由调用方有界等待后重试）。
    func tryAcquireNow(host: String) -> BudgetPermit? {
        guard outstanding.count < globalMax,
              (perHostActive[host] ?? 0) < perHostMax
        else { return nil }
        let permit = BudgetPermit(host: host)
        outstanding.insert(permit)
        perHostActive[host, default: 0] += 1
        return permit
    }

    /// 释放许可。同一 token 只生效一次；未知 token 直接忽略。
    func release(_ permit: BudgetPermit) {
        guard outstanding.remove(permit) != nil else { return }
        let host = permit.host
        if let current = perHostActive[host] {
            if current <= 1 {
                perHostActive[host] = nil
            } else {
                perHostActive[host] = current - 1
            }
        }
    }
}

/// 并发预算许可 token。一次获取、最多释放一次，不可伪造（仅预算 actor 可创建）。
struct BudgetPermit: Hashable, Sendable {
    /// 内部记账用的 host（URL host 小写形式）。
    let host: String
    private let id: UUID
    /// 仅 MediaDownloadBudget 可创建。
    fileprivate init(host: String) {
        self.host = host
        id = UUID()
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
    private var hedgedCount = 0
    private var activeSubrequests = 0
    /// 当前实际在途的子请求按 host 计数（诊断用，与累计统计 hostStats.keys 区分）。
    private var activeHostCounts = [String: Int]()
    private var downgradedToDirect = false
    /// AIMD 自适应并发上限：成功且无竞速/失败时 +1，失败时减半；
    /// 范围 [1, maxConcurrentPerMedia]，初始 2。仅调节并发数，不共享 CDN 排名。
    private var adaptiveConcurrency = 2

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
        // activeHosts 必须是当前实际在途的 host 数，而非累计出现过的 host 数。
        let activeHosts = activeHostCounts.count
        // 有效总吞吐按各 host 实测吞吐求和：多 host 并行时体现聚合，
        // 单 host 串行时退化为该 host 的实测值。累计字节/累计时间之比会低估并行吞吐。
        let mbps = hostStats.values.compactMap(\.estimatedMbps).reduce(0, +)
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

    //
    //  单一 TaskGroup 协调器：子区间下载工作以内联子任务形式运行，
    //  group.next() 即真正的 first-completion 通知。选出首个完成即交付或继续，
    //  落选者在 cancelAll 后因工作内联、可取消而迅速退出——不存在只取消
    //  Task.value 等待者、底层下载继续跑的情况。

    private func streamConcurrent(parentRange: MediaByteRange, subranges: [MediaByteRange], to pipe: MediaBytePipe) async {
        // 有序交付状态（仅本请求内有效）
        var pending = [Int: Data]()
        var pendingBytes: Int64 = 0
        var nextToDeliver = 0
        var nextToStart = 0
        // 本次 stream 的 outcome 快照（AIMD 用）：开始前记录，结束后比较
        let failuresBefore = failureCount
        let hedgesBefore = hedgedCount

        // 子区间初始分配按 host 轮转：无统计时各子区间即分散到不同 CDN，
        // 而非全部挤在首选 host 上等 Hedging 救援。统计出现后 orderedHosts 本身已排序。
        // AIMD 当前上限快照（本请求内固定，避免中途抖动）
        let concurrencyLimit = max(1, min(maxConcurrentPerMedia, adaptiveConcurrency))
        do {
            try await withThrowingTaskGroup(of: (Int, Data).self) { group in
                // 初始填充
                while nextToStart < subranges.count, activeSubrequests < concurrencyLimit {
                    if pendingBytes >= maxBufferedBytes { break }
                    let index = nextToStart
                    let sub = subranges[index]
                    let hosts = hostsForSubrange(index)
                    nextToStart += 1
                    activeSubrequests += 1
                    group.addTask {
                        defer { Task { await self.noteSubrequestDone() } }
                        let data = try await self.fetchSubrangeWithHedging(sub, allowHedging: true, candidateHosts: hosts)
                        return (index, data)
                    }
                }
                while nextToDeliver < subranges.count {
                    if Task.isCancelled {
                        group.cancelAll()
                        throw CancellationError()
                    }
                    // 优先交付已就绪的最早分块（播放截止时间优先）
                    if let ready = pending[nextToDeliver] {
                        do {
                            try await pipe.write(ready)
                        } catch {
                            group.cancelAll()
                            throw error
                        }
                        deliveredBytes += Int64(ready.count)
                        pendingBytes -= Int64(ready.count)
                        pending[nextToDeliver] = nil
                        nextToDeliver += 1
                        // 背压释放后补充新任务
                        while nextToStart < subranges.count, activeSubrequests < concurrencyLimit {
                            if pendingBytes >= maxBufferedBytes { break }
                            let index = nextToStart
                            let sub = subranges[index]
                            let hosts = hostsForSubrange(index)
                            nextToStart += 1
                            activeSubrequests += 1
                            group.addTask {
                                defer { Task { await self.noteSubrequestDone() } }
                                let data = try await self.fetchSubrangeWithHedging(sub, allowHedging: true, candidateHosts: hosts)
                                return (index, data)
                            }
                        }
                        continue
                    }
                    // first-completion：工作内联，取消即作用于下载本身
                    guard let (index, data) = try await group.next() else {
                        throw MediaRangeError.truncated
                    }
                    // 长度校验：必须是请求子区间的准确长度
                    guard Int64(data.count) == subranges[index].length else {
                        group.cancelAll()
                        throw MediaRangeError.truncated
                    }
                    pending[index] = data
                    pendingBytes += Int64(data.count)
                }
            }
            // 完整覆盖校验
            guard nextToDeliver == subranges.count else {
                pipe.fail(MediaRangeError.truncated)
                adjustConcurrencyAfterStream(failuresBefore: failuresBefore, hedgesBefore: hedgesBefore, succeeded: false)
                return
            }
            adjustConcurrencyAfterStream(failuresBefore: failuresBefore, hedgesBefore: hedgesBefore, succeeded: true)
            pipe.close()
        } catch is CancellationError {
            adjustConcurrencyAfterStream(failuresBefore: failuresBefore, hedgesBefore: hedgesBefore, succeeded: false)
            pipe.fail(MediaRangeError.cancelled)
        } catch {
            if (error as? MediaRangeError) != .budgetExhausted {
                failureCount += 1
            }
            adjustConcurrencyAfterStream(failuresBefore: failuresBefore, hedgesBefore: hedgesBefore, succeeded: false)
            pipe.fail(error)
        }
    }

    private func noteSubrequestDone() {
        activeSubrequests = max(0, activeSubrequests - 1)
    }

    /// 子区间首选 host 轮转：把第 index 个子区间优先分配给第 (index % hosts) 个 host，
    /// 使首轮并发即分散到不同 CDN，实现聚合；之后按实测统计排序。
    private func hostsForSubrange(_ index: Int) -> [String] {
        let base = orderedHosts()
        guard base.count > 1 else { return base }
        let r = index % base.count
        return Array(base[r...] + base[..<r])
    }

    /// AIMD：干净成功（无新增失败、无竞速）则 +1 试探；失败则减半。
    /// 缓冲背压（pendingBytes 上限暂停新任务）独立于该调节，始终生效。
    private func adjustConcurrencyAfterStream(failuresBefore: Int, hedgesBefore: Int, succeeded: Bool) {
        if succeeded, failureCount == failuresBefore, hedgedCount == hedgesBefore {
            adaptiveConcurrency = min(maxConcurrentPerMedia, adaptiveConcurrency + 1)
        } else if !succeeded {
            adaptiveConcurrency = max(1, adaptiveConcurrency / 2)
        }
        // 成功但发生过竞速/失败：保持当前上限不变
    }

    // MARK: 子区间获取（含竞速与重试）

    //
    //  单一 TaskGroup 协调器：主路与备路的下载工作以内联子任务运行，
    //  group.next() 即真正的 first-completion 通知。胜者选出后 cancelAll
    //  直接取消落选者的下载工作（fetch 内各处检查取消并使用可取消的
    //  URLSession 异步接口），不存在只取消 Task.value 等待者的情况。

    private enum HedgeLane: Sendable {
        case primary
        case secondary
    }

    private enum HedgeOutcome: Sendable {
        case data(lane: HedgeLane, data: Data)
        case failed(lane: HedgeLane)
        case hedgeTimer
        case compareTimer
    }

    /// 跨 Task 传递子任务的原始错误（TaskGroup 元素须 Sendable，Error 不是）。
    /// 每个 hedging 操作独占一个 box，不存在并发操作间的串扰。
    private final class HedgeErrorBox: @unchecked Sendable {
        private let lock = NSLock()
        private var errors = [HedgeLane: Error]()
        func set(_ error: Error, for lane: HedgeLane) {
            lock.lock()
            errors[lane] = error
            lock.unlock()
        }

        func error(for lane: HedgeLane) -> Error? {
            lock.lock()
            defer { lock.unlock() }
            return errors[lane]
        }
    }

    private func fetchSubrangeWithHedging(
        _ subrange: MediaByteRange,
        allowHedging: Bool,
        candidateHosts: [String]? = nil
    ) async throws -> Data {
        try Task.checkCancellation()
        // candidateHosts 由调用方按轮转/统计排好序，原样采用，不再二次排序，
        // 保证初始分配即分散；nil 时回退到当前统计排序。
        let hosts = candidateHosts ?? orderedHosts()
        guard !hosts.isEmpty else { throw MediaRangeError.unsatisfiable(total: knownTotalLength) }
        if !allowHedging || hosts.count == 1 || subrange.length < subrangeMinBytes {
            return try await fetchSubrangeWithRetry(subrange, hosts: hosts)
        }
        // Slow-Request Hedging：主请求慢时在另一 CDN 启动竞争。
        // 触发考虑 TTFB、已接收字节/吞吐、剩余字节与播放紧迫度（此处用固定 1s 延迟
        // + 剩余长度门限近似；首字节与吞吐在 fetchAttempt 内实测并记入统计）。
        let alternate = alternateHosts(excludingFirstOf: hosts)
        let errorBox = HedgeErrorBox()
        return try await withThrowingTaskGroup(of: HedgeOutcome.self) { group in
            group.addTask {
                do {
                    let data = try await self.fetchSubrangeWithRetry(subrange, hosts: hosts)
                    return .data(lane: .primary, data: data)
                } catch is CancellationError {
                    // 外部取消或组取消：向上传播，保证及时退出；
                    // 计时哨兵不走此路径（sleep 封装在独立子任务内）。
                    if Task.isCancelled { throw CancellationError() }
                    errorBox.set(CancellationError(), for: .primary)
                    return .failed(lane: .primary)
                } catch {
                    errorBox.set(error, for: .primary)
                    return .failed(lane: .primary)
                }
            }
            group.addTask {
                do {
                    try await Task.sleep(nanoseconds: self.hedgingDelayNanoseconds)
                    return .hedgeTimer
                } catch {
                    if Task.isCancelled { throw CancellationError() }
                    // 极少见：sleep 非取消失败，视为计时到期处理
                    return .hedgeTimer
                }
            }
            var secondaryStarted = false
            var primaryFailed = false
            var secondaryFailed = false
            var winnerLane: HedgeLane?
            var winnerData: Data?
            while let outcome = try await group.next() {
                switch outcome {
                case let .data(lane, data):
                    if winnerData == nil {
                        winnerLane = lane
                        winnerData = data
                        if secondaryStarted {
                            // 备路已启动：给落选者短宽限以完成并做字节级比较
                            group.addTask {
                                do {
                                    try await Task.sleep(nanoseconds: 100_000_000)
                                    return .compareTimer
                                } catch {
                                    if Task.isCancelled { throw CancellationError() }
                                    return .compareTimer
                                }
                            }
                        } else {
                            // 备路尚未启动：直接采用，无冗余
                            group.cancelAll()
                            return data
                        }
                    } else {
                        // 落选者在宽限内完成：必须来自另一 lane，与胜者逐字节比较
                        if lane == winnerLane {
                            group.cancelAll()
                            return winnerData!
                        }
                        if data != winnerData {
                            isolateHosts(hosts, reason: "overlap-mismatch")
                            throw MediaRangeError.mismatch
                        }
                        addExtra(Int64(data.count))
                        group.cancelAll()
                        return winnerData!
                    }
                case let .failed(lane):
                    if winnerData != nil {
                        // 胜者已定，落选者失败可忽略
                        group.cancelAll()
                        return winnerData!
                    }
                    if lane == .primary {
                        primaryFailed = true
                    } else {
                        secondaryFailed = true
                    }
                    if !secondaryStarted {
                        // 主路在备路启动前即失败：重试已在 fetchSubrangeWithRetry 内耗尽，
                        // 直接传播原始错误，不等待计时器
                        group.cancelAll()
                        throw errorBox.error(for: lane) ?? MediaRangeError.truncated
                    }
                    if primaryFailed, secondaryFailed {
                        group.cancelAll()
                        throw errorBox.error(for: .primary) ?? MediaRangeError.truncated
                    }
                // 另一路仍在跑，继续等待
                case .hedgeTimer:
                    if winnerData != nil {
                        continue
                    }
                    if !secondaryStarted {
                        secondaryStarted = true
                        retryCount += 1
                        hedgedCount += 1
                        // 第二路：排除首选 host，优先不同 host
                        group.addTask {
                            do {
                                let data = try await self.fetchSubrangeWithRetry(subrange, hosts: alternate)
                                return .data(lane: .secondary, data: data)
                            } catch is CancellationError {
                                if Task.isCancelled { throw CancellationError() }
                                errorBox.set(CancellationError(), for: .secondary)
                                return .failed(lane: .secondary)
                            } catch {
                                errorBox.set(error, for: .secondary)
                                return .failed(lane: .secondary)
                            }
                        }
                    }
                case .compareTimer:
                    // 比较宽限到期：落选者未完成，直接采用胜者
                    // （落选者被 cancelAll 中止，已传输的部分字节已在其中止路径计入 extra）
                    group.cancelAll()
                    if let winnerData {
                        return winnerData
                    }
                    continue
                }
            }
            // 组耗尽仍无结果（理论不可达）：按失败处理
            if let winnerData {
                return winnerData
            }
            throw errorBox.error(for: .primary) ?? MediaRangeError.truncated
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
        // 全局预算：许可 token 一一绑定，defer 恰好释放一次。
        // 有界等待超时直接抛 budgetExhausted，绝不无许可发送。
        let permit: BudgetPermit
        if let acquired = await MediaDownloadBudget.shared.tryAcquireNow(host: host) {
            permit = acquired
        } else {
            permit = try await waitForBudget(host: host)
        }
        // 诊断用实际在途 host 计数（与累计统计区分），退出时配对扣减
        activeHostCounts[host, default: 0] += 1
        defer {
            if let current = self.activeHostCounts[host] {
                self.activeHostCounts[host] = current > 1 ? current - 1 : nil
            }
            let permit = permit
            Task { await MediaDownloadBudget.shared.release(permit) }
        }

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
            // 被取消前已传输的字节计入 extra（上游流量真实发生但未交付），
            // 保证诊断的冗余比例可信；取消本身不计入 CDN 健康失败。
            addExtra(Int64(data.count))
            throw CancellationError()
        } catch {
            // 传输中断前已读取的部分同样计入 extra（未交付的上游流量）
            addExtra(Int64(data.count))
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

    /// 有界等待预算许可。超时不再无许可通行，而是抛 budgetExhausted，
    /// 由上层按失败传播（播放器级恢复做有预算的降级），并保持 release 配对。
    private func waitForBudget(host: String) async throws -> BudgetPermit {
        // 有界等待：最多 10s，每 50ms 重试一次，可取消
        let deadline = Date().addingTimeInterval(10)
        while true {
            try Task.checkCancellation()
            if let permit = await MediaDownloadBudget.shared.tryAcquireNow(host: host) {
                return permit
            }
            if Date() > deadline {
                throw MediaRangeError.budgetExhausted
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
