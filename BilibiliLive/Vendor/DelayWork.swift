//
//  DelayWork.swift
//  BilibiliLive
//
//  Created on 2025/11/27.
//

import Foundation

/// 延迟执行任务的工具类
/// 当有新任务时会自动取消前一个未完成的任务
@MainActor
class DelayWork {
    private var task: Task<Void, Never>?
    private let delay: TimeInterval

    /// 初始化延迟任务执行器
    /// - Parameter delay: 延迟时间 (秒)，默认 1 秒
    init(delay: TimeInterval = 1.0) {
        self.delay = delay
    }

    /// 提交一个延迟任务
    /// - Parameter work: 要执行的异步任务
    func submit(_ work: @escaping @MainActor () async throws -> Void) {
        // 取消前一个未完成的任务
        task?.cancel()

        task = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                try await work()
            } catch {}
        }
    }

    /// 取消当前任务
    func cancel() {
        task?.cancel()
        task = nil
    }

    deinit {
        task?.cancel()
    }
}
