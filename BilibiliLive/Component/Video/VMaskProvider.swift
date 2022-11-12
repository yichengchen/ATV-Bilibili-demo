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
    lazy var layer = CALayer()
    func getMask(for time: CMTime, frame: CGRect, onGet: @escaping (CALayer) -> Void) {
        queue.async {
            if self.processing == true { return }
            self.processing = true
            let image = self.bodyDetect(time: time)
            DispatchQueue.main.sync {
                self.layer.contents = image
                onGet(self.layer)
            }
            self.processing = false
        }
    }

    func needVideoOutput() -> Bool {
        return true
    }

    func setVideoOutout(ouput: AVPlayerItemVideoOutput) {
        videoOutput = ouput
    }

    func bodyDetect(time: CMTime) -> CGImage? {
        guard let videoOutput else { return nil }
        guard videoOutput.hasNewPixelBuffer(forItemTime: time),
              let pixelBuffer = videoOutput.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil) else { return nil }

        do {
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
            let request = VNGeneratePersonSegmentationRequest()
            try handler.perform([request])
            guard let mask = request.results?.first else { return nil }
            let maskImage = CIImage(cvPixelBuffer: mask.pixelBuffer)
            let context = CIContext(options: nil)
            if let cgImage = context.createCGImage(maskImage, from: maskImage.extent) {
                return cgImage
            }
            return nil
        } catch {
            print("Vision error: \(error.localizedDescription)")
            return nil
        }
    }
}
