//
//  PlayContextCache.swift
//  BilibiliLive
//
//  Created by OpenAI on 2026/4/4.
//

import Foundation

struct PlayContextKey: Hashable {
    let aid: Int
    let cid: Int
    let epid: Int
    let seasonId: Int
}

struct PlayContextSnapshot {
    let cid: Int
    let playerInfo: PlayerInfo?
    let videoPlayURLInfo: VideoPlayURLInfo
    var detail: VideoDetail?
}

enum PlayContextMode: String, Hashable {
    case preview
    case regular

    var includeDetail: Bool {
        switch self {
        case .preview:
            return false
        case .regular:
            return true
        }
    }

    var requestOptions: PlayURLRequestOptions {
        switch self {
        case .preview:
            return .featuredPreview
        case .regular:
            return .regular
        }
    }
}

private struct PlayContextEntryKey: Hashable {
    let contextKey: PlayContextKey
    let mode: PlayContextMode
}

actor PlayContextCache {
    private struct InFlightEntry {
        let token: UUID
        let task: Task<PlayContextSnapshot, Error>
    }

    private let maxEntries = 12
    private let recentEntriesToKeep = 4
    private var entries = [PlayContextEntryKey: PlayContextSnapshot]()
    private var inFlightTasks = [PlayContextEntryKey: InFlightEntry]()
    private var accessOrder = [PlayContextEntryKey]()

    func preload(playInfo: PlayInfo, mode: PlayContextMode) async {
        _ = try? await context(for: playInfo, mode: mode)
    }

    func context(for playInfo: PlayInfo, mode: PlayContextMode) async throws -> PlayContextSnapshot {
        let resolvedPlayInfo = try await PlayInfoResolver.resolve(playInfo)
        let entryKey = PlayContextEntryKey(contextKey: resolvedPlayInfo.contextKey, mode: mode)

        if var cached = entries[entryKey] {
            touch(entryKey)
            if mode.includeDetail, cached.detail == nil {
                cached.detail = try? await WebRequest.requestDetailVideo(aid: resolvedPlayInfo.aid)
                entries[entryKey] = cached
            }
            return cached
        }

        if let entry = inFlightTasks[entryKey] {
            var snapshot = try await entry.task.value
            touch(entryKey)
            if mode.includeDetail, snapshot.detail == nil {
                snapshot.detail = try? await WebRequest.requestDetailVideo(aid: resolvedPlayInfo.aid)
                entries[entryKey] = snapshot
            }
            return snapshot
        }

        let token = UUID()
        let task = Task<PlayContextSnapshot, Error> {
            try Task.checkCancellation()
            async let playerInfoReq = try? WebRequest.requestPlayerInfo(aid: resolvedPlayInfo.aid, cid: resolvedPlayInfo.cid ?? 0)
            async let detailReq = mode.includeDetail ? (try? WebRequest.requestDetailVideo(aid: resolvedPlayInfo.aid)) : nil

            let playURLInfo: VideoPlayURLInfo
            if resolvedPlayInfo.isBangumi {
                playURLInfo = try await WebRequest.requestPcgPlayUrl(aid: resolvedPlayInfo.aid,
                                                                     cid: resolvedPlayInfo.cid ?? 0,
                                                                     options: mode.requestOptions)
            } else {
                playURLInfo = try await WebRequest.requestPlayUrl(aid: resolvedPlayInfo.aid,
                                                                  cid: resolvedPlayInfo.cid ?? 0,
                                                                  options: mode.requestOptions)
            }
            try Task.checkCancellation()

            return PlayContextSnapshot(cid: resolvedPlayInfo.cid ?? 0,
                                       playerInfo: await playerInfoReq,
                                       videoPlayURLInfo: playURLInfo,
                                       detail: await detailReq)
        }

        let entry = InFlightEntry(token: token, task: task)
        inFlightTasks[entryKey] = entry
        return try await resolve(entry, for: entryKey)
    }

    func trim(keeping playInfos: [PlayInfo]) {
        let baseKeysToKeep = Set(playInfos.compactMap { info -> PlayContextKey? in
            guard let cid = info.cid, cid > 0 else { return nil }
            return PlayContextKey(aid: info.aid,
                                  cid: cid,
                                  epid: info.epid ?? 0,
                                  seasonId: info.seasonId ?? 0)
        })
        let recentKeys = Array(accessOrder.reversed().prefix(recentEntriesToKeep))
        let entryKeysToKeep = Set((Array(entries.keys) + Array(inFlightTasks.keys)).filter {
            baseKeysToKeep.contains($0.contextKey)
        } + recentKeys)
        for key in inFlightTasks.keys.filter({ !entryKeysToKeep.contains($0) }) {
            inFlightTasks[key]?.task.cancel()
            inFlightTasks[key] = nil
        }
        entries = entries.filter { entryKeysToKeep.contains($0.key) }
        accessOrder.removeAll { !entryKeysToKeep.contains($0) }
    }

    private func resolve(_ entry: InFlightEntry, for key: PlayContextEntryKey) async throws -> PlayContextSnapshot {
        do {
            let snapshot = try await entry.task.value
            guard inFlightTasks[key]?.token == entry.token else {
                throw CancellationError()
            }
            inFlightTasks[key] = nil
            entries[key] = snapshot
            touch(key)
            trimToMaxEntryCount()
            return snapshot
        } catch {
            if inFlightTasks[key]?.token == entry.token {
                inFlightTasks[key] = nil
            }
            throw error
        }
    }

    private func touch(_ key: PlayContextEntryKey) {
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
    }

    private func trimToMaxEntryCount() {
        guard entries.count > maxEntries else { return }
        var removableKeys = accessOrder
        while entries.count > maxEntries, let key = removableKeys.first {
            removableKeys.removeFirst()
            accessOrder.removeAll { $0 == key }
            entries[key] = nil
        }
    }
}
