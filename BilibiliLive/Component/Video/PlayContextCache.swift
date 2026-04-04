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

actor PlayContextCache {
    private var entries = [PlayContextKey: PlayContextSnapshot]()
    private var inFlightTasks = [PlayContextKey: Task<PlayContextSnapshot, Error>]()

    func preload(playInfo: PlayInfo, includeDetail: Bool = false) async {
        _ = try? await context(for: playInfo, includeDetail: includeDetail)
    }

    func context(for playInfo: PlayInfo, includeDetail: Bool = false) async throws -> PlayContextSnapshot {
        let resolvedPlayInfo = try await resolvePlayInfo(playInfo)
        let key = resolvedPlayInfo.contextKey

        if var cached = entries[key] {
            if includeDetail, cached.detail == nil {
                cached.detail = try? await WebRequest.requestDetailVideo(aid: resolvedPlayInfo.aid)
                entries[key] = cached
            }
            return cached
        }

        if let task = inFlightTasks[key] {
            var snapshot = try await task.value
            if includeDetail, snapshot.detail == nil {
                snapshot.detail = try? await WebRequest.requestDetailVideo(aid: resolvedPlayInfo.aid)
                entries[key] = snapshot
            }
            return snapshot
        }

        let task = Task<PlayContextSnapshot, Error> {
            async let playerInfoReq = try? WebRequest.requestPlayerInfo(aid: resolvedPlayInfo.aid, cid: resolvedPlayInfo.cid ?? 0)
            async let detailReq = includeDetail ? (try? WebRequest.requestDetailVideo(aid: resolvedPlayInfo.aid)) : nil

            let playURLInfo: VideoPlayURLInfo
            if resolvedPlayInfo.isBangumi {
                playURLInfo = try await WebRequest.requestPcgPlayUrl(aid: resolvedPlayInfo.aid, cid: resolvedPlayInfo.cid ?? 0)
            } else {
                playURLInfo = try await WebRequest.requestPlayUrl(aid: resolvedPlayInfo.aid, cid: resolvedPlayInfo.cid ?? 0)
            }

            return PlayContextSnapshot(cid: resolvedPlayInfo.cid ?? 0,
                                       playerInfo: await playerInfoReq,
                                       videoPlayURLInfo: playURLInfo,
                                       detail: await detailReq)
        }

        inFlightTasks[key] = task
        defer {
            inFlightTasks[key] = nil
        }

        let snapshot = try await task.value
        entries[key] = snapshot
        return snapshot
    }

    func trim(keeping playInfos: [PlayInfo]) {
        let keysToKeep = Set(playInfos.compactMap { info -> PlayContextKey? in
            guard let cid = info.cid, cid > 0 else { return nil }
            return PlayContextKey(aid: info.aid,
                                  cid: cid,
                                  epid: info.epid ?? 0,
                                  seasonId: info.seasonId ?? 0)
        })
        entries = entries.filter { keysToKeep.contains($0.key) }
    }

    private func resolvePlayInfo(_ playInfo: PlayInfo) async throws -> PlayInfo {
        guard !playInfo.isCidVaild else { return playInfo }
        var resolved = playInfo
        resolved.cid = try await WebRequest.requestCid(aid: playInfo.aid)
        return resolved
    }
}
