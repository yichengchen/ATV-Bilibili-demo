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
    private(set) var temporaryOverrides = [PlayInfo]()
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
        if let temporary = temporaryOverrides.last {
            return temporary
        }
        guard playSeq.indices.contains(currentIndex) else { return nil }
        return playSeq[currentIndex]
    }

    func setCurrentIndex(_ index: Int) {
        guard playSeq.indices.contains(index) else { return }
        clearTemporaryOverrides()
        currentIndex = index
    }

    func reset() {
        clearTemporaryOverrides()
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
        guard !playSeq.isEmpty else { return temporaryOverrides.uniqued() }
        let lower = max(0, currentIndex - radius)
        let upper = min(playSeq.count - 1, currentIndex + radius)
        return ([current()].compactMap { $0 } + Array(playSeq[lower...upper])).uniqued()
    }

    func pushTemporary(_ playInfo: PlayInfo) {
        temporaryOverrides.append(playInfo)
    }

    func clearTemporaryOverrides() {
        temporaryOverrides.removeAll()
    }

    func movePrevious() -> PlayInfo? {
        guard hasPrevious else { return nil }
        clearTemporaryOverrides()
        currentIndex -= 1
        return playSeq[currentIndex]
    }

    func moveNext() async -> PlayInfo? {
        await prefetchMoreIfNeeded()
        guard hasNext else { return nil }
        clearTemporaryOverrides()
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
    enum AutoTriggeredInfoAction: String {
        case previous
        case next

        init?(title: String) {
            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedTitle.contains("上一条") {
                self = .previous
            } else if trimmedTitle.contains("下一条") {
                self = .next
            } else {
                return nil
            }
        }
    }

    var data: VideoDetail?
    var sequenceProvider: VideoSequenceProvider?
    var onLoadFailure: ((String) -> Void)?
    var onPlaybackStarted: (() -> Void)?
    var onPlayInfoChanged: ((PlayInfo) -> Void)?
    var onDismissWithPlayInfo: ((PlayInfo) -> Void)?
    var onItemWatched: ((PlayInfo, Int) -> Void)?

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
    private var activeWatchSignalPlayInfo: PlayInfo?
    private var pendingAutoTriggeredInfoActionKey: String?

    init(playInfo: PlayInfo,
         playMode: VideoPlayerMode = .regular,
         playContextCache: PlayContextCache? = nil,
         mediaWarmupManager: PlayerMediaWarmupManager? = nil,
         previewMuted: Bool = true,
         startTimeOverride: Int? = nil)
    {
        self.playMode = playMode
        self.playContextCache = playContextCache
        self.mediaWarmupManager = mediaWarmupManager
        self.previewMuted = previewMuted
        viewModel = VideoPlayerViewModel(playInfo: playInfo,
                                         playMode: playMode,
                                         playContextCache: playContextCache,
                                         mediaWarmupManager: mediaWarmupManager,
                                         previewMuted: previewMuted,
                                         startTimeOverride: startTimeOverride)
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

    var currentPlayInfo: PlayInfo {
        viewModel.currentPlayInfo
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

        if playMode == .feedFlow {
            // 添加双击上方向键切回上一条视频的全局手势拦截 (作为面板“上一条”被折叠的补偿方案)
            let doubleUpTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleUpTap))
            doubleUpTap.allowedPressTypes = [NSNumber(value: UIPress.PressType.upArrow.rawValue)]
            doubleUpTap.numberOfTapsRequired = 2
            view.addGestureRecognizer(doubleUpTap)

            let doubleDownTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleDownTap))
            doubleDownTap.allowedPressTypes = [NSNumber(value: UIPress.PressType.downArrow.rawValue)]
            doubleDownTap.numberOfTapsRequired = 2
            view.addGestureRecognizer(doubleDownTap)

            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(handleInfoActionFocusedNotification(_:)),
                                                   name: UICollectionViewCell.infoActionFocusedNotification,
                                                   object: nil)
            if #available(tvOS 11.0, *) {
                NotificationCenter.default.addObserver(self,
                                                       selector: #selector(handleSystemFocusUpdate(_:)),
                                                       name: UIFocusSystem.didUpdateNotification,
                                                       object: nil)
            }
        }

        startLoad()
    }

    override func viewDidDisappear(_ animated: Bool) {
        let isExiting = isBeingDismissed || isMovingFromParent || navigationController?.isBeingDismissed == true
        let exitWatchSignal = isExiting ? consumeCurrentPlaybackWatchSignal() : nil
        let dismissPlayInfo = playMode == .feedFlow ? viewModel.currentPlayInfo : nil
        super.viewDidDisappear(animated)
        guard isExiting else { return }
        if playMode == .feedFlow {
            if let exitWatchSignal {
                onItemWatched?(exitWatchSignal.0, exitWatchSignal.1)
            }
            if let dismissPlayInfo {
                onDismissWithPlayInfo?(dismissPlayInfo)
            }
        }
        stopAsyncWork()
    }

    override func stopPlayback() {
        stopAsyncWork()
        super.stopPlayback()
    }

    override func playerDidStart(player: AVPlayer) {
        switch playMode {
        case .preview:
            onPlaybackStarted?()
        case .feedFlow:
            activeWatchSignalPlayInfo = viewModel.currentPlayInfo
        case .regular:
            break
        }
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
        if playMode == .feedFlow,
           let watchSignal = consumeCurrentPlaybackWatchSignal()
        {
            onItemWatched?(watchSignal.0, watchSignal.1)
        }
        if currentRetryKey != info.sequenceKey {
            currentRetryKey = info.sequenceKey
            hasRetriedCurrentItem = false
        }
        pendingAutoTriggeredInfoActionKey = nil
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
        activeWatchSignalPlayInfo = nil
        loadTask?.cancel()
        loadTask = nil
        cancelable.removeAll()
        Task { [mediaWarmupManager] in
            await mediaWarmupManager?.cancelAll()
        }
    }

    private func consumeCurrentPlaybackWatchSignal() -> (PlayInfo, Int)? {
        defer { activeWatchSignalPlayInfo = nil }
        guard let playInfo = activeWatchSignalPlayInfo,
              let watchedSeconds = currentPlaybackTimeInSeconds()
        else {
            return nil
        }
        return (playInfo, watchedSeconds)
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

    @objc private func handleDoubleUpTap() {
        guard playMode == .feedFlow else { return }
        Logger.debug("[FeedFlow] 捕获双击上键，准备切换至上一条")
        Task { [weak self] in
            guard let self else { return }
            _ = await self.viewModel.playPreviousFromSequence()
        }
    }

    @objc private func handleDoubleDownTap() {
        guard playMode == .feedFlow else { return }
        Logger.debug("[FeedFlow] 捕获双击下键，准备切换至下一条")
        Task { [weak self] in
            guard let self else { return }
            _ = await self.viewModel.playNextFromSequence()
        }
    }

    @available(tvOS 11.0, *)
    @objc private func handleSystemFocusUpdate(_ note: Notification) {
        guard playMode == .feedFlow,
              let context = note.userInfo?[UIFocusSystem.focusUpdateContextUserInfoKey] as? UIFocusUpdateContext,
              let nextView = context.nextFocusedView
        else { return }

        Logger.debug("[FocusDiag] 焦点落在了类: \(type(of: nextView))")
        let dumpResult = dumpViewHierarchy(nextView, depth: 0)
        Logger.debug("[FocusDiag] 子视图结构:\n\(dumpResult)")

        if let title = extractMatchingActionTitle(from: nextView) {
            handleFocusedInfoAction(title: title)
        }
    }

    private func dumpViewHierarchy(_ view: UIView, depth: Int) -> String {
        guard depth < 6 else { return "" }
        let indent = String(repeating: "  ", count: depth)
        var result = "\(indent)- \(type(of: view))"
        if let label = view as? UILabel {
            result += " text: '\(label.text ?? "")' attr: '\(label.attributedText?.string ?? "")'"
        } else if let btn = view as? UIButton {
            result += " title: '\(btn.title(for: .normal) ?? "")'"
        }
        result += "\n"
        for subview in view.subviews {
            result += dumpViewHierarchy(subview, depth: depth + 1)
        }
        return result
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        guard playMode == .feedFlow,
              let nextView = context.nextFocusedView
        else { return }

        // 从 focused view 的子视图树中查找匹配的 action 标题
        if let title = extractMatchingActionTitle(from: nextView) {
            Logger.debug("[FeedFlow] didUpdateFocus matched action: \(title)")
            handleFocusedInfoAction(title: title)
        }
    }

    private func extractMatchingActionTitle(from view: UIView) -> String? {
        if let accessLabel = view.accessibilityLabel, AutoTriggeredInfoAction(title: accessLabel) != nil {
            return accessLabel
        }
        for label in collectLabels(in: view, maxDepth: 4) {
            if let text = label.text, AutoTriggeredInfoAction(title: text) != nil {
                return text
            }
            if let attrText = label.attributedText?.string, AutoTriggeredInfoAction(title: attrText) != nil {
                return attrText
            }
        }
        return nil
    }

    private func collectLabels(in view: UIView, maxDepth: Int) -> [UILabel] {
        guard maxDepth > 0 else { return [] }
        var result = [UILabel]()
        for subview in view.subviews {
            if let label = subview as? UILabel {
                result.append(label)
            }
            result.append(contentsOf: collectLabels(in: subview, maxDepth: maxDepth - 1))
        }
        return result
    }

    @objc private func handleInfoActionFocusedNotification(_ note: Notification) {
        guard let title = note.userInfo?["title"] as? String else { return }
        handleFocusedInfoAction(title: title)
    }

    private func handleFocusedInfoAction(title: String) {
        guard playMode == .feedFlow,
              let action = AutoTriggeredInfoAction(title: title)
        else { return }

        let actionKey = "\(currentPlayInfo.sequenceKey)::\(action.rawValue)"
        guard pendingAutoTriggeredInfoActionKey != actionKey else { return }
        pendingAutoTriggeredInfoActionKey = actionKey

        Task { [weak self] in
            guard let self else { return }
            let didTrigger: Bool
            switch action {
            case .previous:
                didTrigger = await self.viewModel.playPreviousFromSequence()
            case .next:
                didTrigger = await self.viewModel.playNextFromSequence()
            }
            if !didTrigger, self.pendingAutoTriggeredInfoActionKey == actionKey {
                self.pendingAutoTriggeredInfoActionKey = nil
            }
        }
    }
}
