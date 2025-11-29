//
//  DanmakuAsyncLayer.swift
//  DanmakuKit
//
//  Created by Q YiZhong on 2020/8/16.
//

import UIKit

class Sentinel {
    private var value: Int32 = 0

    public func getValue() -> Int32 {
        return value
    }

    public func increase() {
        value += 1
    }
}

var pool: DanmakuQueuePool?

class DanmakuAsyncLayer: CALayer {
    /// When true, it is drawn asynchronously and is ture by default.
    public var displayAsync = true

    public var willDisplay: ((_ layer: DanmakuAsyncLayer) -> Void)?

    public var displaying: ((_ context: CGContext, _ size: CGSize, _ isCancelled: () -> Bool) -> Void)?

    public var didDisplay: ((_ layer: DanmakuAsyncLayer, _ finished: Bool) -> Void)?

    private let sentinel = Sentinel()

    override init() {
        super.init()
        contentsScale = UIScreen.main.scale
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    deinit {
        sentinel.increase()
    }

    override func setNeedsDisplay() {
        // 1. Cancel the last drawing
        sentinel.increase()
        // 2. call super
        super.setNeedsDisplay()
    }

    override func display() {
        display(async: displayAsync)
    }

    private func display(async: Bool) {
        guard displaying != nil else {
            willDisplay?(self)
            contents = nil
            didDisplay?(self, true)
            return
        }

        if async {
            willDisplay?(self)
            let value = sentinel.getValue()
            let isCancelled = { () -> Bool in
                return value != self.sentinel.getValue()
            }
            let size = bounds.size
            let scale = contentsScale
            let opaque = isOpaque
            let backgroundColor = (opaque && self.backgroundColor != nil) ? self.backgroundColor : nil
            pool?.queue.async {
                guard !isCancelled() else { return }
                let format = UIGraphicsImageRendererFormat.preferred()
                format.opaque = opaque
                format.scale = scale
                let render = UIGraphicsImageRenderer(size: size)
                let image = render.image { rendererContext in
                    if opaque {
                        rendererContext.cgContext.saveGState()
                        if backgroundColor == nil || (backgroundColor?.alpha ?? 0) < 1 {
                            UIColor.white.setFill()
                            rendererContext.fill(CGRect(x: 0, y: 0, width: size.width * scale, height: size.height * scale))
                        }
                        if let backgroundColor = backgroundColor {
                            UIColor(cgColor: backgroundColor).setFill()
                            rendererContext.fill(CGRect(x: 0, y: 0, width: size.width * scale, height: size.height * scale))
                        }
                        rendererContext.cgContext.restoreGState()
                    }
                    self.displaying?(rendererContext.cgContext, size, isCancelled)
                }
                if isCancelled() {
                    DispatchQueue.main.async {
                        self.didDisplay?(self, false)
                    }
                    return
                }
                DispatchQueue.main.async {
                    if isCancelled() {
                        self.didDisplay?(self, false)
                    } else {
                        self.contents = image.cgImage
                        self.didDisplay?(self, true)
                    }
                }
            }

        } else {
            sentinel.increase()
            willDisplay?(self)
            let format = UIGraphicsImageRendererFormat.preferred()
            format.opaque = isOpaque
            format.scale = contentsScale
            let render = UIGraphicsImageRenderer(size: bounds.size)
            let image = render.image { rendererContext in
                displaying?(rendererContext.cgContext, bounds.size, { () -> Bool in return false })
            }
            contents = image.cgImage
            didDisplay?(self, true)
        }
    }
}
