//
//  DanmakuView.swift
//  DanmakuKit
//
//  Created by Q YiZhong on 2020/8/16.
//

import UIKit

public protocol DanmakuViewDelegate: AnyObject {
    /// A  danmaku is about to be reused and cellModel is set for you before calling this method.
    /// - Parameters:
    ///   - danmakuView: view of the danmaku
    ///   - danmaku: danmaku
    func danmakuView(_ danmakuView: DanmakuView, dequeueReusable danmaku: DanmakuCell)

    ///  This method is called when the danmaku has no space to display.
    /// - Parameters:
    ///   - danmakuView: view of the danmaku
    ///   - danmaku:  cellModel of danmaku
    func danmakuView(_ danmakuView: DanmakuView, noSpaceShoot danmaku: DanmakuCellModel)

    ///  This method is called when the danmaku is about to be displayed.
    /// - Parameters:
    ///   - danmakuView: view of the danmaku
    ///   - danmaku:  danmaku
    func danmakuView(_ danmakuView: DanmakuView, willDisplay danmaku: DanmakuCell)

    /// This method is called when the danmaku is about to end.
    /// - Parameters:
    ///   - danmakuView: view of the danmaku
    ///   - danmaku: danmaku
    func danmakuView(_ danmakuView: DanmakuView, didEndDisplaying danmaku: DanmakuCell)

    /// This method is called when danmaku is tapped.
    /// - Parameters:
    ///   - danmakuView: view of the danmaku
    ///   - danmaku: danmaku
    func danmakuView(_ danmakuView: DanmakuView, didTapped danmaku: DanmakuCell)

    ///  This method is called when the danmaku has no space to sync display.
    /// - Parameters:
    ///   - danmakuView: view of the danmaku
    ///   - danmaku:  cellModel of danmaku
    func danmakuView(_ danmakuView: DanmakuView, noSpaceSync danmaku: DanmakuCellModel)
}

public extension DanmakuViewDelegate {
    func danmakuView(_ danmakuView: DanmakuView, dequeueReusable danmaku: DanmakuCell) {}

    func danmakuView(_ danmakuView: DanmakuView, noSpaceShoot danmaku: DanmakuCellModel) {}

    func danmakuView(_ danmakuView: DanmakuView, willDisplay danmaku: DanmakuCell) {}

    func danmakuView(_ danmakuView: DanmakuView, didEndDisplaying danmaku: DanmakuCell) {}

    func danmakuView(_ danmakuView: DanmakuView, didTapped danmaku: DanmakuCell) {}

    func danmakuView(_ danmakuView: DanmakuView, noSpaceSync danmaku: DanmakuCellModel) {}
}

public enum DanmakuStatus {
    case play
    case pause
    case stop
}

/// The number of queues to draw the danmaku. If you want to change it, you must do so before the danmakuView is first created.
public var DRAW_DANMAKU_QUEUE_COUNT = 16

public class DanmakuView: UIView {
    public weak var delegate: DanmakuViewDelegate?

    /// If this property is false, the danmaku will not be reused and danmakuView(_:dequeueReusable danmaku:) methods will not be called.
    public var enableCellReusable = true

    /// Each danmaku is in one track and the number of tracks in the view depends on the height of the track.
    public var trackHeight: CGFloat = 20 {
        didSet {
            guard oldValue != trackHeight else { return }
            recaculateTracks()
        }
    }

    /// Padding of top area, the actual offset of the top danmaku will refer to this property.
    public var paddingTop: CGFloat = 0 {
        didSet {
            guard oldValue != paddingTop else { return }
            recaculateTracks()
        }
    }

    /// Padding of bottom area, the actual offset of the bottom danmaku will refer to this property.
    public var paddingBottom: CGFloat = 0 {
        didSet {
            guard oldValue != paddingBottom else { return }
            recaculateTracks()
        }
    }

    /// State of play,  The danmaku can only be sent in play status.
    public private(set) var status: DanmakuStatus = .stop

    /// The display area of the danmaku is set between 0 and 1. Setting this property will affect the number of danmaku tracks.
    public var displayArea: CGFloat = 1.0 {
        willSet {
            assert(newValue >= 0 && newValue <= 1, "Danmaku display area must be between [0, 1].")
        }
        didSet {
            guard oldValue != displayArea else { return }
            recaculateTracks()
        }
    }

    /// If this property is true, the danmaku supports overlapping launches. Default is false.
    public var isOverlap: Bool = false {
        didSet {
            for i in 0..<floatingTracks.count {
                floatingTracks[i].isOverlap = isOverlap
            }
            for i in 0..<topTracks.count {
                topTracks[i].isOverlap = isOverlap
            }
            for i in 0..<bottomTracks.count {
                bottomTracks[i].isOverlap = isOverlap
            }
        }
    }

    /// All floating danmaku are removed immediately after set false, and it won't be launched again. Default is true.
    public var enableFloatingDanmaku: Bool = true {
        didSet {
            if !enableFloatingDanmaku {
                floatingTracks.forEach {
                    $0.stop()
                }
            }
        }
    }

    /// All top danmaku are removed immediately after set false, and it won't be launched again. Default is true.
    public var enableTopDanmaku: Bool = true {
        didSet {
            if !enableTopDanmaku {
                topTracks.forEach {
                    $0.stop()
                }
            }
        }
    }

    /// All bottom danmaku are removed immediately after set false, and it won't be launched again. Default is true.
    public var enableBottomDanmaku: Bool = true {
        didSet {
            if !enableBottomDanmaku {
                bottomTracks.forEach {
                    $0.stop()
                }
            }
        }
    }

    public var playingSpeed: Float = 1.0 {
        willSet {
            assert(newValue > 0, "Danmaku playing speed must be over 0.")
        }
        didSet {
            update {
                for i in 0..<floatingTracks.count {
                    var track = floatingTracks[i]
                    track.playingSpeed = playingSpeed
                }
                for i in 0..<topTracks.count {
                    var track = topTracks[i]
                    track.playingSpeed = playingSpeed
                }
                for i in 0..<bottomTracks.count {
                    var track = bottomTracks[i]
                    track.playingSpeed = playingSpeed
                }
            }
        }
    }

    private var danmakuPool: [String: [DanmakuCell]] = [:]

    private var floatingTracks: [DanmakuTrack] = []

    private var topTracks: [DanmakuTrack] = []

    private var bottomTracks: [DanmakuTrack] = []

    private var viewHeight: CGFloat {
        return bounds.height * displayArea
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        createPoolIfNeed()
        recaculateTracks()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard self.point(inside: point, with: event) else { return nil }

        for i in (0..<subviews.count).reversed() {
            let subView = subviews[i]
            if subView.layer.animationKeys() != nil, let presentationLayer = subView.layer.presentation() {
                let newPoint = layer.convert(point, to: presentationLayer)
                if presentationLayer.contains(newPoint) {
                    return subView
                }
            } else {
                let newPoint = convert(point, to: subView)
                if let findView = subView.hitTest(newPoint, with: event) {
                    return findView
                }
            }
        }
        return nil
    }
}

public extension DanmakuView {
    func shoot(danmaku: DanmakuCellModel) {
        guard status == .play else { return }
        switch danmaku.type {
        case .floating:
            guard enableFloatingDanmaku else { return }
            guard !floatingTracks.isEmpty else { return }
        case .top:
            guard enableTopDanmaku else { return }
            guard !topTracks.isEmpty else { return }
        case .bottom:
            guard enableBottomDanmaku else { return }
            guard !bottomTracks.isEmpty else { return }
        }

        guard let cell = obtainCell(with: danmaku) else { return }

        let shootTrack: DanmakuTrack
        if isOverlap {
            shootTrack = findLeastNumberDanmakuTrack(for: danmaku)
        } else {
            guard let t = findSuitableTrack(for: danmaku) else {
                delegate?.danmakuView(self, noSpaceShoot: danmaku)
                return
            }
            shootTrack = t
        }

        if cell.superview == nil {
            addSubview(cell)
        }

        delegate?.danmakuView(self, willDisplay: cell)
        cell.layer.setNeedsDisplay()
        shootTrack.shoot(danmaku: cell)
    }

    func canShoot(danmaku: DanmakuCellModel) -> Bool {
        guard status == .play else { return false }
        switch danmaku.type {
        case .floating:
            guard enableFloatingDanmaku else { return false }
            return (floatingTracks.first { t -> Bool in
                return t.canShoot(danmaku: danmaku)
            }) != nil
        case .top:
            guard enableTopDanmaku else { return false }
            return (topTracks.first { t -> Bool in
                return t.canShoot(danmaku: danmaku)
            }) != nil
        case .bottom:
            guard enableBottomDanmaku else { return false }
            return (bottomTracks.first { t -> Bool in
                return t.canShoot(danmaku: danmaku)
            }) != nil
        }
    }

    /// You can call this method when you need to change the size of the danmakuView.
    func recaculateTracks() {
        recaculateFloatingTracks()
        recaculateTopTracks()
        recaculateBottomTracks()
    }

    func play() {
        guard status != .play else { return }
        floatingTracks.forEach {
            $0.play()
        }
        topTracks.forEach {
            $0.play()
        }
        bottomTracks.forEach {
            $0.play()
        }
        status = .play
    }

    func pause() {
        guard status != .pause else { return }
        floatingTracks.forEach {
            $0.pause()
        }
        topTracks.forEach {
            $0.pause()
        }
        bottomTracks.forEach {
            $0.pause()
        }
        status = .pause
    }

    func stop() {
        guard status != .stop else { return }
        floatingTracks.forEach {
            $0.stop()
        }
        topTracks.forEach {
            $0.stop()
        }
        bottomTracks.forEach {
            $0.stop()
        }
        status = .stop
    }

    @discardableResult
    func play(_ danmaku: DanmakuCellModel) -> Bool {
        var track = floatingTracks.first { t -> Bool in
            return t.play(danmaku)
        }
        if track == nil {
            track = topTracks.first(where: { t -> Bool in
                return t.play(danmaku)
            })
        }
        if track == nil {
            track = bottomTracks.first(where: { t -> Bool in
                return t.play(danmaku)
            })
        }
        return track != nil
    }

    @discardableResult
    func pause(_ danmaku: DanmakuCellModel) -> Bool {
        var track = floatingTracks.first { t -> Bool in
            return t.pause(danmaku)
        }
        if track == nil {
            track = topTracks.first(where: { t -> Bool in
                return t.pause(danmaku)
            })
        }
        if track == nil {
            track = bottomTracks.first(where: { t -> Bool in
                return t.pause(danmaku)
            })
        }
        return track != nil
    }

    /// Display a danmaku synchronously according to the progress. If the status is stop, it will not work.
    /// - Parameters:
    ///   - danmaku: danmakuCellModel
    ///   - progress: progress of danmaku display
    func sync(danmaku: DanmakuCellModel, at progress: Float) {
        guard status != .stop else { return }
        assert(progress <= 1.0, "Cannot sync danmaku at progress \(progress).")
        switch danmaku.type {
        case .floating:
            guard enableFloatingDanmaku else { return }
            guard !floatingTracks.isEmpty else { return }
        case .top:
            guard enableTopDanmaku else { return }
            guard !topTracks.isEmpty else { return }
        case .bottom:
            guard enableBottomDanmaku else { return }
            guard !bottomTracks.isEmpty else { return }
        }
        guard let cell = obtainCell(with: danmaku) else { return }

        let syncTrack: DanmakuTrack
        if isOverlap {
            syncTrack = findLeastNumberDanmakuTrack(for: danmaku)
        } else {
            guard let t = findSuitableSyncTrack(for: danmaku, at: progress) else {
                delegate?.danmakuView(self, noSpaceSync: danmaku)
                return
            }
            syncTrack = t
        }

        if cell.superview == nil {
            addSubview(cell)
        }

        delegate?.danmakuView(self, willDisplay: cell)
        cell.layer.setNeedsDisplay()
        if status == .play {
            syncTrack.syncAndPlay(cell, at: progress)
        } else {
            syncTrack.sync(cell, at: progress)
        }
    }

    /// Clean all the currently displayed danmaku.
    func clean() {
        floatingTracks.forEach { $0.clean() }
        bottomTracks.forEach { $0.clean() }
        topTracks.forEach { $0.clean() }
    }

    /// When you change some properties of the danmakuView or cellModel that might affect the danmaku, you must make changes in the closure of this method.
    /// E.g.This method will be used when you change the displayTime property in the cellModel.
    /// - Parameter closure: update closure
    func update(_ closure: () -> Void) {
        pause()
        closure()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            self.play()
        }
    }
}

private extension DanmakuView {
    func recaculateFloatingTracks() {
        if viewHeight == 0 { return }
        let trackCount = Int(floorf(Float((viewHeight - paddingTop - paddingBottom) / trackHeight)))
        let offsetY = max(0, (viewHeight - CGFloat(trackCount) * trackHeight) / 2.0)
        let diffFloatingTrackCount = trackCount - floatingTracks.count
        if diffFloatingTrackCount > 0 {
            for _ in 0..<diffFloatingTrackCount {
                floatingTracks.append(DanmakuFloatingTrack(view: self))
            }
        } else if diffFloatingTrackCount < 0 {
            for i in max(0, floatingTracks.count + diffFloatingTrackCount)..<floatingTracks.count {
                floatingTracks[i].stop()
            }
            floatingTracks.removeLast(Int(abs(diffFloatingTrackCount)))
        }
        for i in 0..<floatingTracks.count {
            var track = floatingTracks[i]
            track.stopClosure = { [weak self] cell in
                guard let strongSelf = self else { return }
                strongSelf.cellPlayingStop(cell)
            }
            track.index = UInt(i)
            track.positionY = CGFloat(i) * trackHeight + trackHeight / 2.0 + paddingTop + offsetY
        }
    }

    func recaculateTopTracks() {
        if viewHeight == 0 { return }
        let trackCount = Int(floorf(Float((viewHeight - paddingTop - paddingBottom) / trackHeight)))
        let offsetY = max(0, (viewHeight - CGFloat(trackCount) * trackHeight) / 2.0)
        let diffFloatingTrackCount = trackCount - topTracks.count
        if diffFloatingTrackCount > 0 {
            for _ in 0..<diffFloatingTrackCount {
                topTracks.append(DanmakuVerticalTrack(view: self))
            }
        } else if diffFloatingTrackCount < 0 {
            for i in max(0, topTracks.count + diffFloatingTrackCount)..<topTracks.count {
                topTracks[i].stop()
            }
            topTracks.removeLast(Int(abs(diffFloatingTrackCount)))
        }
        for i in 0..<topTracks.count {
            var track = topTracks[i]
            track.stopClosure = { [weak self] cell in
                guard let strongSelf = self else { return }
                strongSelf.cellPlayingStop(cell)
            }
            track.index = UInt(i)
            track.positionY = CGFloat(i) * trackHeight + trackHeight / 2.0 + paddingTop + offsetY
        }
    }

    func recaculateBottomTracks() {
        if viewHeight == 0 { return }
        let trackCount = Int(floorf(Float((viewHeight - paddingTop - paddingBottom) / trackHeight)))
        let offsetY = max(0, (viewHeight - CGFloat(trackCount) * trackHeight) / 2.0)
        let diffFloatingTrackCount = trackCount - bottomTracks.count
        if diffFloatingTrackCount > 0 {
            for _ in 0..<diffFloatingTrackCount {
                bottomTracks.insert(DanmakuVerticalTrack(view: self), at: 0)
            }
        } else if diffFloatingTrackCount < 0 {
            for i in 0..<min(bottomTracks.count, abs(diffFloatingTrackCount)) {
                bottomTracks[i].stop()
            }
            bottomTracks.removeFirst(Int(abs(diffFloatingTrackCount)))
        }
        for i in (0..<bottomTracks.count).reversed() {
            var track = bottomTracks[i]
            track.stopClosure = { [weak self] cell in
                guard let strongSelf = self else { return }
                strongSelf.cellPlayingStop(cell)
            }
            let index = bottomTracks.count - i - 1
            track.index = UInt(index)
            track.positionY = bounds.height - CGFloat(index) * trackHeight - trackHeight / 2.0 - paddingTop - offsetY
        }
    }

    func findLeastNumberDanmakuTrack(for danmaku: DanmakuCellModel) -> DanmakuTrack {
        func findLeastNumberDanmaku(from tracks: [DanmakuTrack]) -> DanmakuTrack {
            // Find a track with the minimum danmaku number
            var index = 0
            var value = Int.max
            for i in 0..<tracks.count {
                let track = tracks[i]
                if track.danmakuCount < value {
                    value = track.danmakuCount
                    index = i
                }
            }
            return tracks[index]
        }
        switch danmaku.type {
        case .floating:
            return findLeastNumberDanmaku(from: floatingTracks)
        case .top:
            return findLeastNumberDanmaku(from: topTracks)
        case .bottom:
            return findLeastNumberDanmaku(from: bottomTracks)
        }
    }

    func findSuitableTrack(for danmaku: DanmakuCellModel) -> DanmakuTrack? {
        switch danmaku.type {
        case .floating:
            guard let track = floatingTracks.first(where: { t -> Bool in
                return t.canShoot(danmaku: danmaku)
            }) else {
                return nil
            }
            return track
        case .top:
            guard let track = topTracks.first(where: { t -> Bool in
                return t.canShoot(danmaku: danmaku)
            }) else {
                return nil
            }
            return track
        case .bottom:
            guard let track = bottomTracks.last(where: { t -> Bool in
                return t.canShoot(danmaku: danmaku)
            }) else {
                return nil
            }
            return track
        }
    }

    func findSuitableSyncTrack(for danmaku: DanmakuCellModel, at progress: Float) -> DanmakuTrack? {
        switch danmaku.type {
        case .floating:
            guard let track = floatingTracks.first(where: { t -> Bool in
                return t.canSync(danmaku, at: progress)
            }) else {
                return nil
            }
            return track
        case .top:
            guard let track = topTracks.first(where: { t -> Bool in
                return t.canSync(danmaku, at: progress)
            }) else {
                return nil
            }
            return track
        case .bottom:
            guard let track = bottomTracks.last(where: { t -> Bool in
                return t.canSync(danmaku, at: progress)
            }) else {
                return nil
            }
            return track
        }
    }

    func obtainCell(with danmaku: DanmakuCellModel) -> DanmakuCell? {
        var cell: DanmakuCell?
        if enableCellReusable {
            var cells = danmakuPool[NSStringFromClass(danmaku.cellClass)]
            if cells == nil {
                cells = []
            }
            cell = (cells?.count ?? 0) > 0 ? cells?.removeFirst() : nil
            danmakuPool[NSStringFromClass(danmaku.cellClass)] = cells
        }

        let frame = CGRect(x: bounds.width, y: 0, width: danmaku.size.width, height: danmaku.size.height)
        if cell == nil {
            guard let cls = NSClassFromString(NSStringFromClass(danmaku.cellClass)) as? DanmakuCell.Type else {
                assertionFailure("Launched Danmaku must inherit from DanmakuCell!")
                return nil
            }
            cell = cls.init(frame: frame)
            cell?.model = danmaku
            let tap = UITapGestureRecognizer(target: self, action: #selector(danmakuDidTap(_:)))
            cell?.addGestureRecognizer(tap)
        } else {
            cell?.frame = frame
            cell?.model = danmaku
            delegate?.danmakuView(self, dequeueReusable: cell!)
        }
        return cell
    }

    func cellPlayingStop(_ cell: DanmakuCell) {
        guard enableCellReusable else { return }
        guard let cs = cell.model?.cellClass else { return }
        delegate?.danmakuView(self, didEndDisplaying: cell)
        guard var array = danmakuPool[NSStringFromClass(cs)] else { return }
        array.append(cell)
        danmakuPool[NSStringFromClass(cs)] = array
    }

    @objc
    func danmakuDidTap(_ tap: UITapGestureRecognizer) {
        guard let view = tap.view as? DanmakuCell else { return }
        delegate?.danmakuView(self, didTapped: view)
    }

    func createPoolIfNeed() {
        guard pool == nil else { return }
        pool = DanmakuQueuePool(name: "com.DanmakuKit.DanmakuAsynclayer", queueCount: DRAW_DANMAKU_QUEUE_COUNT, qos: .userInteractive)
    }
}
