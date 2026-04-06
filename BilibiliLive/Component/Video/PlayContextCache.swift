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
    private let maxEntries = 12
    private let recentEntriesToKeep = 4
    private var entries = [PlayContextEntryKey: PlayContextSnapshot]()
    private var inFlightTasks = [PlayContextEntryKey: Task<PlayContextSnapshot, Error>]()
    private var accessOrder = [PlayContextEntryKey]()

    func preload(playInfo: PlayInfo, mode: PlayContextMode) async {
        _ = try? await context(for: playInfo, mode: mode)
    }

    func context(for playInfo: PlayInfo, mode: PlayContextMode) async throws -> PlayContextSnapshot {
        let resolvedPlayInfo = try await resolvePlayInfo(playInfo)
        let entryKey = PlayContextEntryKey(contextKey: resolvedPlayInfo.contextKey, mode: mode)

        if var cached = entries[entryKey] {
            touch(entryKey)
            if mode.includeDetail, cached.detail == nil {
                cached.detail = try? await WebRequest.requestDetailVideo(aid: resolvedPlayInfo.aid)
                entries[entryKey] = cached
            }
            return cached
        }

        if let task = inFlightTasks[entryKey] {
            var snapshot = try await task.value
            touch(entryKey)
            if mode.includeDetail, snapshot.detail == nil {
                snapshot.detail = try? await WebRequest.requestDetailVideo(aid: resolvedPlayInfo.aid)
                entries[entryKey] = snapshot
            }
            return snapshot
        }

        let task = Task<PlayContextSnapshot, Error> {
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

            return PlayContextSnapshot(cid: resolvedPlayInfo.cid ?? 0,
                                       playerInfo: await playerInfoReq,
                                       videoPlayURLInfo: playURLInfo,
                                       detail: await detailReq)
        }

        inFlightTasks[entryKey] = task
        defer {
            inFlightTasks[entryKey] = nil
        }

        let snapshot = try await task.value
        entries[entryKey] = snapshot
        touch(entryKey)
        trimToMaxEntryCount()
        return snapshot
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
        let entryKeysToKeep = Set(entries.keys.filter { baseKeysToKeep.contains($0.contextKey) } + recentKeys)
        entries = entries.filter { entryKeysToKeep.contains($0.key) }
        accessOrder.removeAll { !entryKeysToKeep.contains($0) }
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

    private func resolvePlayInfo(_ playInfo: PlayInfo) async throws -> PlayInfo {
        try await PlayInfoResolver.resolve(playInfo)
    }
}
