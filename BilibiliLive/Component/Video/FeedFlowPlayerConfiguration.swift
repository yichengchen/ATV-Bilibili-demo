//
//  FeedFlowPlayerConfiguration.swift
//  BilibiliLive
//
//  Created by OpenAI on 2026/4/6.
//

import Foundation

struct FeedFlowPluginContext {
    let detail: VideoDetail?
    let currentPlayInfo: PlayInfo
    let sequenceProvider: VideoSequenceProvider?
    let playTemporaryOverride: (PlayInfo) -> Void
}

struct FeedFlowPlayerConfiguration {
    let makeAdditionalPlugins: (FeedFlowPluginContext) -> [CommonPlayerPlugin]

    init(makeAdditionalPlugins: @escaping (FeedFlowPluginContext) -> [CommonPlayerPlugin] = { _ in [] }) {
        self.makeAdditionalPlugins = makeAdditionalPlugins
    }

    static let empty = FeedFlowPlayerConfiguration()
}
