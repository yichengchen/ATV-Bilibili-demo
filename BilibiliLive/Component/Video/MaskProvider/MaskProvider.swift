//
//  MaskProvider.swift
//  BilibiliLive
//
//  Created by yicheng on 2024/6/10.
//
import AVKit

protocol MaskProvider: AnyObject {
    func getMask(for time: CMTime, frame: CGRect, onGet: @escaping (CALayer) -> Void)
    func needVideoOutput() -> Bool
    func setVideoOutout(ouput: AVPlayerItemVideoOutput)
    func preferFPS() -> Int
}
