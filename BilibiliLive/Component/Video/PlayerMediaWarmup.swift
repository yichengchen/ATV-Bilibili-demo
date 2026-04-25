//
//  PlayerMediaWarmup.swift
//  BilibiliLive
//
//  Created by OpenAI on 2026/4/4.
//

import AVFoundation
import Foundation

final class PreparedPlayerMedia: @unchecked Sendable {
    let asset: AVURLAsset
    let delegate: BilibiliVideoResourceLoaderDelegate

    init(asset: AVURLAsset, delegate: BilibiliVideoResourceLoaderDelegate) {
        self.asset = asset
        self.delegate = delegate
    }
}

enum PlayerMediaFactory {
    static func prepare(aid: Int,
                        urlInfo: VideoPlayURLInfo,
                        playerInfo: PlayerInfo?,
                        maxQuality: Int? = nil,
                        streamIndex: Int? = nil) async throws -> PreparedPlayerMedia
    {
        let playURL = URL(string: BilibiliVideoResourceLoaderDelegate.URLs.play)!
        let headers: [String: String] = [
            "User-Agent": Keys.userAgent,
            "Referer": Keys.referer(for: aid),
        ]
        let asset = AVURLAsset(url: playURL, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        let delegate = BilibiliVideoResourceLoaderDelegate()
        delegate.setBilibili(info: urlInfo,
                             subtitles: playerInfo?.subtitle?.subtitles ?? [],
                             aid: aid,
                             maxQuality: maxQuality,
                             streamIndex: streamIndex)
        asset.resourceLoader.setDelegate(delegate, queue: DispatchQueue(label: "loader.\(aid).\(UUID().uuidString)"))
        let playable = try await asset.load(.isPlayable)
        guard playable else {
            throw "加载资源失败"
        }
        await delegate.prewarmPrimaryVideoIndex()
        return PreparedPlayerMedia(asset: asset, delegate: delegate)
    }
}

actor PlayerMediaWarmupManager {
    private let maxPreparedEntries = 4
    private let playContextCache: PlayContextCache
    private var prepared = [String: PreparedPlayerMedia]()
    private var inFlight = [String: Task<PreparedPlayerMedia, Error>]()
    private var accessOrder = [String]()

    init(playContextCache: PlayContextCache) {
        self.playContextCache = playContextCache
    }

    func preload(playInfo: PlayInfo) async {
        _ = try? await preparedMedia(for: playInfo)
    }

    func preparedMedia(for playInfo: PlayInfo) async throws -> PreparedPlayerMedia {
        let key = playInfo.sequenceKey
        if let cached = prepared[key] {
            touch(key)
            return cached
        }
        if let task = inFlight[key] {
            let cached = try await task.value
            touch(key)
            return cached
        }

        let task = Task<PreparedPlayerMedia, Error> {
            let snapshot = try await playContextCache.context(for: playInfo, mode: .regular)
            return try await PlayerMediaFactory.prepare(aid: playInfo.aid,
                                                        urlInfo: snapshot.videoPlayURLInfo,
                                                        playerInfo: snapshot.playerInfo)
        }

        inFlight[key] = task
        defer {
            inFlight[key] = nil
        }

        let cached = try await task.value
        prepared[key] = cached
        touch(key)
        trimToCapacity()
        return cached
    }

    func retain(playInfos: [PlayInfo]) {
        let allowedKeys = Set(playInfos.map(\.sequenceKey))
        for (key, task) in inFlight where !allowedKeys.contains(key) {
            task.cancel()
            inFlight[key] = nil
        }
        prepared = prepared.filter { allowedKeys.contains($0.key) }
        accessOrder.removeAll { !allowedKeys.contains($0) }
    }

    func cancelAll() {
        inFlight.values.forEach { $0.cancel() }
        inFlight.removeAll()
        prepared.removeAll()
        accessOrder.removeAll()
    }

    private func touch(_ key: String) {
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
    }

    private func trimToCapacity() {
        while prepared.count > maxPreparedEntries, let key = accessOrder.first {
            accessOrder.removeFirst()
            prepared[key] = nil
        }
    }
}
