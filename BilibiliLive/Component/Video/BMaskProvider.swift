//
//  BMaskProvider.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/11/9.
//

import Alamofire
import Foundation
import PocketSVG
import UIKit

class BMaskProvider {
    let info: PlayerInfo.MaskInfo
    let videoSize: CGSize
    var svgs = [[UIBezierPath]]()

    private var lastTime: TimeInterval = 0
    private var duration: Int
    init(info: PlayerInfo.MaskInfo, videoSize: CGSize, duration: Int) {
        self.info = info
        self.videoSize = videoSize
        self.duration = duration
        Task.detached {
            try? await self.download()
        }
    }

    private func download() async throws {
        guard let url = info.mask_url?.addSchemeIfNeed() else { return }
        var lastTime: UInt32?
        let data = try await AF.request(url).serializingData().value
        let header = WebMaskInfoHeader.decode(data: data.prefix(16))
        let segments = header.segments
        var segmentsData = [SegmentData]()
        var buffer = data
        for _ in 0..<segments {
            buffer = buffer.subdata(in: 16..<buffer.count)
            let start = buffer[0..<4].withUnsafeBytes({ $0.load(as: UInt32.self) })
            let end = buffer[8..<12].withUnsafeBytes({ $0.load(as: UInt32.self) })
            if start == 0 && end == 0 {
                let time = buffer[4..<8].withUnsafeBytes({ $0.load(as: UInt32.self) }).bigEndian
                let offset = buffer[12..<16].withUnsafeBytes({ $0.load(as: UInt32.self) }).bigEndian
                segmentsData.append(SegmentData(time: time, offset: offset))
            }
        }
        buffer = buffer.subdata(in: 16..<buffer.count)
        let num = segmentsData.count
        var length: UInt32 = 0
        var total = [[UIBezierPath]]()

        let size = await UIScreen.main.bounds.size
        let videoSize = CGSize.aspectFit(aspectRatio: videoSize, boundingSize: size)
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

        for i in 0..<num {
            let seg = segmentsData[i]
            if i < num - 1 {
                length = segmentsData[i + 1].offset - seg.offset
            } else {
                length = UInt32(data.count) - seg.offset
            }

            var buffer2 = buffer.subdata(in: 0..<Data.Index(length))
            buffer = buffer.subdata(in: Int(length)..<buffer.count)
            buffer2 = try! buffer2.gunzipped()
            while buffer2.count > 0 {
                let offset = buffer2[0..<4].withUnsafeBytes({ $0.load(as: UInt32.self) }).bigEndian
                let time = buffer2[8..<12].withUnsafeBytes({ $0.load(as: UInt32.self) }).bigEndian

                defer {
                    buffer2 = buffer2.subdata(in: 12 + Int(offset)..<buffer2.count)
                }
                if time == lastTime {
                    continue
                }
                lastTime = time
                let b64Data = buffer2[12..<12 + Int(offset)]
                var b64String = String(data: b64Data, encoding: .utf8)!.replacingOccurrences(of: "\n", with: "")
                b64String = String(b64String.components(separatedBy: ";base64,").last ?? b64String)
                let newb64Data = Data(base64Encoded: b64String)!
                let decodedString = String(data: newb64Data, encoding: .utf8)!

                let paths = SVGBezierPath.paths(fromSVGString: decodedString)

                for path in paths {
                    let coordTransform = CGAffineTransform(translationX: x, y: y).scaledBy(x: videoSize.width / path.bounds.width, y: videoSize.height / path.bounds.height)
                    let finalTransform = coordTransform.scaledBy(x: 1, y: -1).translatedBy(x: 0, y: 0 - path.bounds.height - path.bounds.origin.y)
                    path.apply(finalTransform)
                    paddingPaths.forEach { path.append($0) }
                }

                total.append(paths.map { $0.reversing() })
            }
            SVGBezierPath.resetCache()
        }
        svgs = total
    }

    func getMask(for time: TimeInterval, frame: CGRect, onGet: ((CALayer) -> Void)? = nil) {
        guard time != lastTime else { return }
        lastTime = time
        if time < 0 { return }
        let idx = Int(Double(time) * Double(info.fps))
        guard idx < svgs.count else { return }
        let layer = CALayer()
        for path in svgs[idx] {
            let shapeLayer = CAShapeLayer()
            shapeLayer.path = path.cgPath
            shapeLayer.fillColor = UIColor.white.cgColor
            shapeLayer.backgroundColor = UIColor.white.cgColor
            shapeLayer.strokeColor = UIColor.white.cgColor
            layer.addSublayer(shapeLayer)
        }
        layer.frame = frame
        onGet?(layer)
    }
}

extension BMaskProvider {
    struct SegmentData {
        let time: UInt32
        let offset: UInt32
    }

    struct WebMaskInfoHeader {
        var tag: UInt8
        var tag1: UInt8
        var tag2: UInt8
        var tag3: UInt8

        var version: UInt32
        var checkcode: UInt8
        var segments: UInt32

        static func decode(data: Data) -> WebMaskInfoHeader {
            var header = (data as NSData).bytes.bindMemory(to: WebMaskInfoHeader.self, capacity: data.count).pointee
            header.version = header.version.bigEndian
            header.checkcode = header.checkcode.bigEndian
            header.segments = header.segments.bigEndian
            return header
        }
    }
}

extension CGSize {
    static func aspectFit(aspectRatio: CGSize, boundingSize: CGSize) -> CGSize {
        var boundingSize = boundingSize
        let mW = boundingSize.width / aspectRatio.width
        let mH = boundingSize.height / aspectRatio.height

        if mH < mW {
            boundingSize.width = boundingSize.height / aspectRatio.height * aspectRatio.width
        } else if mW < mH {
            boundingSize.height = boundingSize.width / aspectRatio.width * aspectRatio.height
        }

        return boundingSize
    }
}
