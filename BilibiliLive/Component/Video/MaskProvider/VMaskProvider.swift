//
//  VMaskProvider.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/11/12.
//

import AVFoundation
import UIKit
import Vision

class VMaskProvider: MaskProvider {
    let queue = DispatchQueue(label: "bodydetect")
    weak var videoOutput: AVPlayerItemVideoOutput?
    var processing = false
    lazy var context: CIContext = {
        return CIContext(options: [.useSoftwareRenderer: false,
                                   .cacheIntermediates: false,
                                   .name: "vn"])
    }()

    private let requestHandler = VNSequenceRequestHandler()
    private lazy var segmentationRequest: VNGeneratePersonSegmentationRequest = {
        let segmentation = VNGeneratePersonSegmentationRequest()
        segmentation.qualityLevel = .balanced
        segmentation.outputPixelFormat = kCVPixelFormatType_OneComponent8
        return segmentation
    }()

    var videoSize: CGSize?
    lazy var layer = CALayer()
    lazy var maskLayer = CALayer()

    func getMask(for time: CMTime, frame: CGRect, onGet: @escaping (CALayer) -> Void) {
        guard !processing else {
            Logger.debug("drop frame")
            return
        }
        guard let videoOutput else {
            return
        }
        processing = true
        guard videoOutput.hasNewPixelBuffer(forItemTime: time),
              let pixelBuffer = videoOutput.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil)
        else {
            Logger.debug("no video buff")
            processing = false
            return
        }

        if videoSize == nil {
            let width = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
            let height = CGFloat(CVPixelBufferGetHeight(pixelBuffer))

            let size = frame.size
            let videoSize = CGSize.aspectFit(aspectRatio: CGSize(width: width, height: height), boundingSize: size)
            self.videoSize = videoSize
            let x = (size.width - videoSize.width) / 2.0
            let y = (size.height - videoSize.height) / 2.0

            var paddingPaths = [UIBezierPath]()
            if x > 0 {
                paddingPaths.append(UIBezierPath(rect: CGRect(x: 0, y: 0, width: x, height: size.height)))
                paddingPaths.append(UIBezierPath(rect: CGRect(x: size.width - x, y: 0, width: x, height: size.height)))
            } else if y > 0 {
                paddingPaths.append(UIBezierPath(rect: CGRect(x: 0, y: 0, width: size.width, height: y)))
                paddingPaths.append(UIBezierPath(rect: CGRect(x: 0, y: size.height - y, width: size.width, height: y)))
            }
            maskLayer.frame = CGRect(origin: CGPoint(x: x, y: y), size: videoSize)
            layer.insertSublayer(maskLayer, at: 0)
            paddingPaths.map({
                let layer = CAShapeLayer()
                layer.fillColor = UIColor.white.cgColor
                layer.strokeColor = UIColor.white.cgColor
                layer.path = $0.cgPath
                layer.frame = frame
                return layer
            }).forEach { layer.insertSublayer($0, at: 0) }
        }

        let ciImage = CIImage(cvImageBuffer: pixelBuffer)
        queue.async {
            guard let image = self.bodyDetect(buffer: ciImage, videoSize: self.videoSize!) else {
                self.processing = false
                return
            }
            DispatchQueue.main.async {
                self.maskLayer.contents = image
                self.layer.frame = frame
                onGet(self.layer)
                self.processing = false
            }
        }
    }

    func needVideoOutput() -> Bool {
        return true
    }

    func setVideoOutout(ouput: AVPlayerItemVideoOutput) {
        videoOutput = ouput
    }

    func preferFPS() -> Int {
        return 10
    }

    func bodyDetect(buffer: CIImage, videoSize: CGSize) -> CGImage? {
        do {
            try requestHandler.perform([segmentationRequest], on: buffer)
            guard let mask = segmentationRequest.results?.first else { return nil }
            var maskImage = CIImage(cvPixelBuffer: mask.pixelBuffer)
            maskImage = maskImage.applyingFilter("CIColorInvert").applyingFilter("CIMaskToAlpha")
            maskImage = maskImage.transformed(by: CGAffineTransform(scaleX: videoSize.width / maskImage.extent.width + 0.2, y: videoSize.height / maskImage.extent.height + 0.2))

            let xInset = (maskImage.extent.width - videoSize.width) / 2.0
            let yInset = (maskImage.extent.height - videoSize.height) / 2.0

            if let cgImage = context.createCGImage(maskImage, from: CGRect(origin: CGPoint(x: xInset, y: yInset), size: videoSize)) {
                return cgImage
            }
            return nil
        } catch {
            Logger.warn("Vision error: \(error.localizedDescription)")
            return nil
        }
    }
}
