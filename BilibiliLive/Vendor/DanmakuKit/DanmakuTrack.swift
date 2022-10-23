//
//  DanmakuTrack.swift
//  DanmakuKit
//
//  Created by Q YiZhong on 2020/8/17.
//

import UIKit

let MAX_FLOAT_X = CGFloat.infinity / 2.0

// MARK: DanmakuTrack

protocol DanmakuTrack {
    var positionY: CGFloat { get set }

    var index: UInt { get set }

    var stopClosure: ((_ cell: DanmakuCell) -> Void)? { get set }

    var danmakuCount: Int { get }

    var isOverlap: Bool { get set }

    var playingSpeed: Float { get set }

    init(view: UIView)

    func shoot(danmaku: DanmakuCell)

    func canShoot(danmaku: DanmakuCellModel) -> Bool

    func play()

    func pause()

    func stop()

    func pause(_ danmaku: DanmakuCellModel) -> Bool

    func play(_ danmaku: DanmakuCellModel) -> Bool

    func sync(_ danmaku: DanmakuCell, at progress: Float)

    func syncAndPlay(_ danmaku: DanmakuCell, at progress: Float)

    func canSync(_ danmaku: DanmakuCellModel, at progress: Float) -> Bool

    func clean()
}

let FLOATING_ANIMATION_KEY = "FLOATING_ANIMATION_KEY"
let TOP_ANIMATION_KEY = "TOP_ANIMATION_KEY"
let DANMAKU_CELL_KEY = "DANMAKU_CELL_KEY"

// MARK: DanmakuFloatingTrack

class DanmakuFloatingTrack: NSObject, DanmakuTrack, CAAnimationDelegate {
    var positionY: CGFloat = 0 {
        didSet {
            cells.forEach {
                $0.layer.position.y = positionY
            }
        }
    }

    var index: UInt = 0

    var stopClosure: ((_ cell: DanmakuCell) -> Void)?

    var isOverlap: Bool = false

    var danmakuCount: Int {
        return cells.count
    }

    var playingSpeed: Float = 1.0

    private var cells: [DanmakuCell] = []

    private weak var view: UIView?

    required init(view: UIView) {
        self.view = view
    }

    func shoot(danmaku: DanmakuCell) {
        cells.append(danmaku)
        danmaku.layer.position = CGPoint(x: view!.bounds.width + danmaku.bounds.width / 2.0, y: positionY)
        danmaku.model?.track = index
        prepare(danmaku: danmaku)
        addAnimation(to: danmaku)
    }

    func canShoot(danmaku: DanmakuCellModel) -> Bool {
        guard !isOverlap else { return true }
        // 初中数学的追击问题
        guard let cell = cells.last else { return true }
        guard let cellModel = cell.model else { return true }

        // 1. 获取前一个cell剩余的运动时间
        let preWidth = view!.bounds.width + cell.frame.width
        let nextWidth = view!.bounds.width + danmaku.size.width
        let preRight = max(cell.realFrame.maxX, 0)
        let preCellTime = min(preRight / preWidth * CGFloat(cellModel.displayTime), CGFloat(cellModel.displayTime))
        // 2. 计算出路程差，减10防止刚好追上
        let distance = view!.bounds.width - preRight - 10
        guard distance >= 0 else {
            // 路程小于0说明当前轨道有一条弹幕刚发送
            return false
        }
        let preV = preWidth / CGFloat(cellModel.displayTime)
        let nextV = nextWidth / CGFloat(danmaku.displayTime)
        // 3. 计算出速度差
        if nextV - preV <= 0 {
            // 速度差小于等于0说明永远也追不上
            return true
        }
        // 4. 计算出追击时间
        let time = (distance / (nextV - preV))

        if time < preCellTime {
            // 弹幕会追击到前一个
            return false
        }

        return true
    }

    func play() {
        cells.forEach {
            addAnimation(to: $0)
        }
    }

    func play(_ danmaku: DanmakuCellModel) -> Bool {
        guard let findCell = cells.first(where: { c -> Bool in
            return c.model?.isEqual(to: danmaku) ?? false
        }) else { return false }
        addAnimation(to: findCell)
        return true
    }

    func pause() {
        cells.forEach {
            $0.center = CGPoint(x: $0.realFrame.midX, y: $0.realFrame.midY)
            $0.layer.removeAllAnimations()
        }
    }

    func pause(_ danmaku: DanmakuCellModel) -> Bool {
        guard let findCell = cells.first(where: { c -> Bool in
            return c.model?.isEqual(to: danmaku) ?? false
        }) else { return false }
        findCell.center = CGPoint(x: findCell.realFrame.midX, y: findCell.realFrame.midY)
        findCell.layer.removeAllAnimations()
        return true
    }

    func stop() {
        cells.forEach {
            $0.removeFromSuperview()
            $0.layer.removeAllAnimations()
        }
        cells.removeAll()
    }

    func sync(_ danmaku: DanmakuCell, at progress: Float) {
        guard let model = danmaku.model else { return }
        let totalWidth = view!.frame.width + danmaku.bounds.width
        let syncFrame = CGRect(x: view!.frame.width - totalWidth * CGFloat(progress), y: positionY - danmaku.bounds.height / 2.0, width: danmaku.bounds.width, height: danmaku.bounds.height)
        cells.append(danmaku)
        danmaku.layer.opacity = 1
        danmaku.frame = syncFrame
        danmaku.model?.track = index
        danmaku.animationTime = model.displayTime * Double(progress)
    }

    func syncAndPlay(_ danmaku: DanmakuCell, at progress: Float) {
        sync(danmaku, at: progress)
        addAnimation(to: danmaku)
    }

    func canSync(_ danmaku: DanmakuCellModel, at progress: Float) -> Bool {
        let totalWidth = view!.frame.width + danmaku.size.width
        let syncFrame = CGRect(x: view!.frame.width - totalWidth * CGFloat(progress), y: positionY - danmaku.size.height / 2.0, width: danmaku.size.width, height: danmaku.size.height)
        return cells.first(where: { cell -> Bool in
            // realFrame是presentationLayer的frame，只有坐标是可靠的，size并不可靠，因此这里要使用cell设置size
            let cellRealyFrame = CGRect(x: cell.realFrame.midX - cell.bounds.width / 2.0, y: cell.realFrame.midY - cell.bounds.height / 2.0, width: cell.bounds.width, height: cell.bounds.height)
            return cellRealyFrame.intersects(syncFrame)
        }) == nil
    }

    func clean() {
        stop()
    }

    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        guard let danmaku = anim.value(forKey: DANMAKU_CELL_KEY) as? DanmakuCell else { return }
        danmaku.animationTime += (CFAbsoluteTimeGetCurrent() - danmaku.animationBeginTime) * Double(playingSpeed)
        if flag {
            var findCell: DanmakuCell?
            cells.removeAll { cell -> Bool in
                let flag = cell == danmaku
                if flag {
                    findCell = cell
                }
                return flag
            }
            if let cell = findCell {
                danmaku.layer.removeAllAnimations()
                danmaku.frame.origin.x = MAX_FLOAT_X
                stopClosure?(cell)
            }
        }
    }

    private func addAnimation(to danmaku: DanmakuCell) {
        guard let cellModel = danmaku.model else { return }
        danmaku.animationBeginTime = CFAbsoluteTimeGetCurrent()
        let rate = max(danmaku.frame.maxX / (view!.bounds.width + danmaku.frame.width), 0)
        let animation = CABasicAnimation(keyPath: "position.x")
        animation.beginTime = CACurrentMediaTime()
        animation.duration = (cellModel.displayTime * Double(rate)) / Double(playingSpeed)
        animation.delegate = self
        animation.fromValue = NSNumber(value: Float(danmaku.layer.position.x))
        animation.toValue = NSNumber(value: Float(-danmaku.bounds.width / 2.0))
        animation.isRemovedOnCompletion = false
        animation.fillMode = .forwards
        animation.setValue(danmaku, forKey: DANMAKU_CELL_KEY)
        danmaku.layer.add(animation, forKey: FLOATING_ANIMATION_KEY)
    }
}

// MARK: DanmakuVerticalTrack

class DanmakuVerticalTrack: NSObject, DanmakuTrack, CAAnimationDelegate {
    var positionY: CGFloat = 0 {
        didSet {
            cells.forEach {
                $0.layer.position = CGPoint(x: view!.bounds.width / 2.0, y: positionY)
            }
        }
    }

    var index: UInt = 0

    var stopClosure: ((_ cell: DanmakuCell) -> Void)?

    var isOverlap: Bool = false

    var danmakuCount: Int {
        return cells.count
    }

    var cells: [DanmakuCell] = []

    var playingSpeed: Float = 1.0

    private weak var view: UIView?

    required init(view: UIView) {
        self.view = view
    }

    func shoot(danmaku: DanmakuCell) {
        cells.append(danmaku)
        danmaku.layer.position = CGPoint(x: view!.bounds.width / 2.0, y: positionY)
        danmaku.model?.track = index
        prepare(danmaku: danmaku)
        addAnimation(to: danmaku)
    }

    func canShoot(danmaku: DanmakuCellModel) -> Bool {
        return isOverlap ? true : cells.count == 0
    }

    func play() {
        cells.forEach {
            addAnimation(to: $0)
        }
    }

    func play(_ danmaku: DanmakuCellModel) -> Bool {
        guard let findCell = cells.first(where: { c -> Bool in
            return c.model?.isEqual(to: danmaku) ?? false
        }) else { return false }
        addAnimation(to: findCell)
        return true
    }

    func pause() {
        cells.forEach {
            $0.layer.removeAllAnimations()
        }
    }

    func pause(_ danmaku: DanmakuCellModel) -> Bool {
        guard let findCell = cells.first(where: { c -> Bool in
            return c.model?.isEqual(to: danmaku) ?? false
        }) else { return false }
        findCell.layer.removeAllAnimations()
        return true
    }

    func stop() {
        cells.forEach {
            $0.removeFromSuperview()
            $0.layer.removeAllAnimations()
        }
        cells.removeAll()
    }

    func sync(_ danmaku: DanmakuCell, at progress: Float) {
        guard let model = danmaku.model else { return }
        cells.append(danmaku)
        danmaku.animationTime = model.displayTime * Double(progress)
        danmaku.model?.track = index
        danmaku.layer.position = CGPoint(x: view!.bounds.width / 2.0, y: positionY)
        danmaku.layer.opacity = 1
    }

    func syncAndPlay(_ danmaku: DanmakuCell, at progress: Float) {
        sync(danmaku, at: progress)
        addAnimation(to: danmaku)
    }

    func canSync(_ danmaku: DanmakuCellModel, at progress: Float) -> Bool {
        return cells.isEmpty
    }

    func clean() {
        stop()
    }

    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        guard let danmaku = anim.value(forKey: DANMAKU_CELL_KEY) as? DanmakuCell else { return }
        danmaku.animationTime += (CFAbsoluteTimeGetCurrent() - danmaku.animationBeginTime) * Double(playingSpeed)
        if flag {
            var findCell: DanmakuCell?
            cells.removeAll { cell -> Bool in
                let flag = cell == danmaku
                if flag {
                    findCell = cell
                }
                return flag
            }
            if let cell = findCell {
                danmaku.layer.removeAllAnimations()
                danmaku.frame.origin.x = MAX_FLOAT_X
                stopClosure?(cell)
            }
        }
    }

    private func addAnimation(to danmaku: DanmakuCell) {
        guard let cellModel = danmaku.model else { return }
        danmaku.animationBeginTime = CFAbsoluteTimeGetCurrent()
        let rate = cellModel.displayTime == 0 ? 0 : (1 - danmaku.animationTime / cellModel.displayTime)
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.beginTime = CACurrentMediaTime() + cellModel.displayTime * rate / Double(playingSpeed)
        animation.duration = 0
        animation.delegate = self
        animation.fromValue = 1
        animation.toValue = 0
        animation.isRemovedOnCompletion = false
        animation.fillMode = .forwards
        animation.setValue(danmaku, forKey: DANMAKU_CELL_KEY)
        danmaku.layer.add(animation, forKey: TOP_ANIMATION_KEY)
    }
}

func prepare(danmaku: DanmakuCell) {
    danmaku.animationTime = 0
    danmaku.animationBeginTime = 0
    danmaku.layer.opacity = 1
}
