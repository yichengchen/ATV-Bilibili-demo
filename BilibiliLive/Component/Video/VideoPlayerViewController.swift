//
//  VideoPlayerViewController.swift
//  BilibiliLive
//
//  Created by yicheng on 2024/5/23.
//

import AVKit
import Combine
import UIKit

struct PlayInfo: Hashable {
    let aid: Int
    var cid: Int? = 0
    var epid: Int? = 0 // 港澳台解锁需要
    var seasonId: Int? = 0 // 番剧 season_id
    var ctime: Int? = 0
    var subType: Int? = nil // 0: 普通视频 1：番剧 2：电影 3：纪录片 4：国创 5：电视剧 7：综艺
    var lastPlayCid: Int?
    var playTimeInSecond: Int?
    var title: String?
    var ownerName: String?
    var coverURL: URL?
    var duration: Int?

    var isCidVaild: Bool {
        return cid ?? 0 > 0
    }

    var isBangumi: Bool {
        return epid ?? 0 > 0 || seasonId ?? 0 > 0
    }

    var sequenceKey: String {
        "\(aid)-\(cid ?? 0)-\(epid ?? 0)-\(seasonId ?? 0)"
    }

    var contextKey: PlayContextKey {
        PlayContextKey(aid: aid,
                       cid: cid ?? 0,
                       epid: epid ?? 0,
                       seasonId: seasonId ?? 0)
    }
}

enum VideoPlayerMode {
    case regular
    case preview
    case feedFlow
}

@MainActor
final class VideoSequenceProvider {
    private(set) var playSeq: [PlayInfo]
    private(set) var currentIndex: Int
    private let preloadThreshold: Int
    var onNeedMore: (() async -> Void)?

    init(seq: [PlayInfo], currentIndex: Int = 0, preloadThreshold: Int = 8) {
        playSeq = seq.uniqued()
        self.currentIndex = max(0, min(currentIndex, max(playSeq.count - 1, 0)))
        self.preloadThreshold = preloadThreshold
    }

    var count: Int {
        playSeq.count
    }

    var hasPrevious: Bool {
        currentIndex > 0
    }

    var hasNext: Bool {
        currentIndex + 1 < playSeq.count
    }

    func current() -> PlayInfo? {
        guard playSeq.indices.contains(currentIndex) else { return nil }
        return playSeq[currentIndex]
    }

    func setCurrentIndex(_ index: Int) {
        guard playSeq.indices.contains(index) else { return }
        currentIndex = index
    }

    func reset() {
        currentIndex = 0
    }

    func append(_ seq: [PlayInfo]) {
        let existing = Set(playSeq.map(\.sequenceKey))
        let newItems = seq.filter { !existing.contains($0.sequenceKey) }
        playSeq.append(contentsOf: newItems)
    }

    func peekPrevious() -> PlayInfo? {
        guard hasPrevious else { return nil }
        return playSeq[currentIndex - 1]
    }

    func peekNext() -> PlayInfo? {
        guard hasNext else { return nil }
        return playSeq[currentIndex + 1]
    }

    func neighborItems(radius: Int) -> [PlayInfo] {
        guard !playSeq.isEmpty else { return [] }
        let lower = max(0, currentIndex - radius)
        let upper = min(playSeq.count - 1, currentIndex + radius)
        return Array(playSeq[lower...upper])
    }

    func movePrevious() -> PlayInfo? {
        guard hasPrevious else { return nil }
        currentIndex -= 1
        return playSeq[currentIndex]
    }

    func moveNext() async -> PlayInfo? {
        await prefetchMoreIfNeeded()
        guard hasNext else { return nil }
        currentIndex += 1
        await prefetchMoreIfNeeded()
        return playSeq[currentIndex]
    }

    func prefetchMoreIfNeeded() async {
        guard count - currentIndex - 1 < preloadThreshold else { return }
        await onNeedMore?()
    }
}

class VideoPlayerViewController: CommonPlayerViewController {
    var data: VideoDetail?
    var sequenceProvider: VideoSequenceProvider?
    var onLoadFailure: ((String) -> Void)?
    var onPlaybackStarted: (() -> Void)?
    var onPlayInfoChanged: ((PlayInfo) -> Void)?
    var onDismissWithPlayInfo: ((PlayInfo) -> Void)?

    private let playMode: VideoPlayerMode
    private let playContextCache: PlayContextCache?
    private let mediaWarmupManager: PlayerMediaWarmupManager?
    private let previewMuted: Bool
    private let viewModel: VideoPlayerViewModel
    private var cancelable = Set<AnyCancellable>()
    private var loadTask: Task<Void, Never>?
    private var currentRetryKey: String
    private var hasRetriedCurrentItem = false
    private var isStopping = false

    init(playInfo: PlayInfo,
         playMode: VideoPlayerMode = .regular,
         playContextCache: PlayContextCache? = nil,
         mediaWarmupManager: PlayerMediaWarmupManager? = nil,
         previewMuted: Bool = true)
    {
        self.playMode = playMode
        self.playContextCache = playContextCache
        self.mediaWarmupManager = mediaWarmupManager
        self.previewMuted = previewMuted
        viewModel = VideoPlayerViewModel(playInfo: playInfo,
                                         playMode: playMode,
                                         playContextCache: playContextCache,
                                         mediaWarmupManager: mediaWarmupManager,
                                         previewMuted: previewMuted)
        currentRetryKey = playInfo.sequenceKey
        super.init(nibName: nil, bundle: nil)
        if playMode == .preview {
            showsPlaybackControls = false
            allowsPictureInPicturePlayback = false
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.sequenceProvider = sequenceProvider
        viewModel.onPlayInfoChanged = { [weak self] info in
            self?.handlePlayInfoChanged(info)
        }
        viewModel.onShowDetail = { [weak self] info in
            self?.showDetail(for: info)
        }
        viewModel.onPluginReady.receive(on: DispatchQueue.main).sink { [weak self] completion in
            switch completion {
            case let .failure(err):
                self?.handleLoadFailure(message: err)
            default:
                break
            }
        } receiveValue: { [weak self] plugins in
            self?.removeAllPlugins()
            plugins.forEach { self?.addPlugin(plugin: $0) }
            Task { [weak self] in
                await self?.viewModel.preloadNeighborsIfNeeded()
            }
        }.store(in: &cancelable)

        if playMode == .regular {
            viewModel.onExit = { [weak self] in
                self?.dismiss(animated: true)
            }
        }

        startLoad()
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard playMode == .feedFlow, let buttonPress = presses.first?.type else {
            super.pressesEnded(presses, with: event)
            return
        }

        switch buttonPress {
        case .upArrow:
            Task { [weak self] in
                _ = await self?.viewModel.playPreviousFromSequence()
            }
        case .downArrow:
            Task { [weak self] in
                _ = await self?.viewModel.playNextFromSequence()
            }
        default:
            super.pressesEnded(presses, with: event)
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        let isExiting = isBeingDismissed || isMovingFromParent || navigationController?.isBeingDismissed == true
        guard isExiting else { return }
        if playMode == .feedFlow {
            onDismissWithPlayInfo?(viewModel.currentPlayInfo)
        }
        stopAsyncWork()
    }

    override func stopPlayback() {
        stopAsyncWork()
        super.stopPlayback()
    }

    override func playerDidStart(player: AVPlayer) {
        guard playMode == .preview else { return }
        onPlaybackStarted?()
    }

    override func playerDidStall(player: AVPlayer) {
        guard playMode == .feedFlow else { return }
        attemptRetryOrShowRecovery(message: "播放卡住了，请选择重试或切换下一条。")
    }

    override func playerDidFail(player: AVPlayer) {
        guard playMode == .feedFlow else {
            super.playerDidFail(player: player)
            return
        }
        attemptRetryOrShowRecovery(message: "当前视频加载失败，请选择重试或切换下一条。")
    }

    private func handlePlayInfoChanged(_ info: PlayInfo) {
        if currentRetryKey != info.sequenceKey {
            currentRetryKey = info.sequenceKey
            hasRetriedCurrentItem = false
        }
        onPlayInfoChanged?(info)
    }

    private func startLoad() {
        loadTask?.cancel()
        guard !isStopping else { return }
        loadTask = Task { [weak self] in
            await self?.viewModel.load()
        }
    }

    private func stopAsyncWork() {
        guard !isStopping else { return }
        isStopping = true
        loadTask?.cancel()
        loadTask = nil
        cancelable.removeAll()
        Task { [mediaWarmupManager] in
            await mediaWarmupManager?.cancelAll()
        }
    }

    private func handleLoadFailure(message: String) {
        switch playMode {
        case .preview:
            onLoadFailure?(message)
        case .feedFlow:
            attemptRetryOrShowRecovery(message: message)
        case .regular:
            showErrorAlertAndExit(message: message)
        }
    }

    private func attemptRetryOrShowRecovery(message: String) {
        guard !hasRetriedCurrentItem else {
            showFeedFlowRecoveryAlert(message: message)
            return
        }
        hasRetriedCurrentItem = true
        Task { [weak self] in
            await self?.viewModel.retryCurrent()
        }
    }

    private func showFeedFlowRecoveryAlert(message: String) {
        let alert = UIAlertController(title: "播放异常", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "重试", style: .default) { [weak self] _ in
            self?.hasRetriedCurrentItem = true
            Task { [weak self] in
                await self?.viewModel.retryCurrent()
            }
        })
        alert.addAction(UIAlertAction(title: "下一条", style: .default) { [weak self] _ in
            Task { [weak self] in
                if await self?.viewModel.playNextFromSequence() == false {
                    self?.dismiss(animated: true)
                }
            }
        })
        alert.addAction(UIAlertAction(title: "关闭", style: .cancel))
        present(alert, animated: true)
    }

    private func showDetail(for info: PlayInfo) {
        guard playMode != .preview else { return }
        let detailVC = VideoDetailViewController.create(aid: info.aid, cid: info.cid)
        detailVC.present(from: self, direatlyEnterVideo: false)
    }
}
