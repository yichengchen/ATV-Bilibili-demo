//
//  MoovParseUtil.swift
//  BilibiliLive
//
//  Created by yicheng on 2023/3/7.
//

import Foundation
enum MoovParseUtil {
    struct Moov {
        fileprivate(set) var trak = [Trak]()
        struct Trak {
            fileprivate(set) var tkhd: Tkhd?
            fileprivate(set) var mdia: Mdia?
            struct Mdia {
                fileprivate(set) var minf = Minf()
                fileprivate(set) var mdhd = Mdhd(timeScale: 0)
            }
        }
    }

    struct Mdhd {
        let timeScale: UInt32
    }

    struct Tkhd {
        let createTime: UInt32
        let modification: UInt32
        let trackID: UInt32
        let duration: UInt32
        let layer: UInt16
        let group: UInt16
        let volume: UInt16
        let width: UInt32
        let height: UInt32

        var isVideo: Bool { return width > 0 && height > 0 }
    }

    struct Minf {
        fileprivate(set) var stbl = Stbl()
    }

    struct Stbl {
        fileprivate(set) var sampleSizes = [UInt32]()
        fileprivate(set) var samplePerChunk = [ChunkInfo]()
        fileprivate(set) var chunkOffset = [UInt32]()
        fileprivate(set) var sampleDurations = [UInt32]()
        fileprivate(set) var iframeIndexs = [UInt32]()

        func getSampleCount(for chunkIndex: Int) -> UInt32 {
            let index = chunkIndex + 1
            var pervious: ChunkInfo?
            for info in samplePerChunk {
                pervious = info
                if index == info.index {
                    return info.sampleCount
                }
                if info.index > index {
                    if let pervious = pervious {
                        return pervious.sampleCount
                    } else {
                        return info.sampleCount
                    }
                }
            }
            return pervious?.sampleCount ?? samplePerChunk.first?.sampleCount ?? 0
        }
    }

    struct ChunkInfo {
        let index: UInt32
        let sampleCount: UInt32
        let desp: UInt32
    }

    static func processData(initialData: Data, ignoreAudio: Bool = true, aquireMoreData: (Int, Int) async -> Data) async -> Moov? {
        var data = initialData
        var offset: UInt64 = 0
        var typeString = ""
        while offset < data.count - 8 {
            print("offset:", offset)
            let size = UInt64(data.getUint32(offset: &offset))
            let typeArr = data.getUint32(offset: &offset).toUInt8s
            typeString = String(bytes: typeArr, encoding: .utf8)!
            print(size, typeString)
            if offset + size > data.count {
                let need = Int(offset) + Int(size) - data.count + 8
                let moreData = await aquireMoreData(data.count, need)
                print("fetch, need \(need), get \(moreData.count)")
                if need != moreData.count {
                    assertionFailure()
                    return nil
                }
                data.append(moreData)
            }
            switch typeString {
            case "moov":
                print("size: ", data.count, "need", offset + size)
                let moov = processMoov(data: Data(data[Data.Index(offset)..<Int(offset + size)]), ignoreAudio: ignoreAudio)
                return moov
            default:
                break
            }
            offset += (size - 8)
        }
        return nil
    }

    private static func processMoov(data: Data, ignoreAudio: Bool) -> Moov {
        var offset: UInt64 = 0
        var moov = Moov()
        while offset < data.count - 8 {
            let boxLength = UInt64(data.getUint32(offset: &offset))
            let typeArr = data.getUint32(offset: &offset).toUInt8s
            let typeString = String(bytes: typeArr, encoding: .utf8)!
            print("boxLength", boxLength, typeString)
            switch typeString {
            case "trak":
                moov.trak.append(processTrak(data: Data(data[Data.Index(offset)..<Int(offset + boxLength)]), ignoreAudio: ignoreAudio))
            case "mvhd", "mvex", "udta":
                break
            default:
                break
            }
            offset += (boxLength - 8)
        }
        return moov
    }

    private static func processTrak(data: Data, ignoreAudio: Bool) -> Moov.Trak {
        var trak = Moov.Trak()
        var offset: UInt64 = 0
        while offset < data.count - 8 {
            let boxLength = UInt64(data.getUint32(offset: &offset))
            let typeArr = data.getUint32(offset: &offset).toUInt8s
            let typeString = String(bytes: typeArr, encoding: .utf8)!
            print("boxLength", boxLength, typeString)
            switch typeString {
            case "tkhd":
                let tkhd = processTkhd(data: Data(data[Data.Index(offset)..<Int(offset + boxLength)]))
                trak.tkhd = tkhd
                if ignoreAudio && !tkhd.isVideo { return trak }
            case "edts":
                break
            case "mdia":
                trak.mdia = processMdia(data: Data(data[Data.Index(offset)..<Int(offset + boxLength)]))
            default:
                break
            }
            offset += (boxLength - 8)
        }
        return trak
    }

    private static func processMdia(data: Data) -> Moov.Trak.Mdia {
        var offset: UInt64 = 0
        var mdia = Moov.Trak.Mdia()
        while offset < data.count - 8 {
            let boxLength = UInt64(data.getUint32(offset: &offset))
            let typeArr = data.getUint32(offset: &offset).toUInt8s
            let typeString = String(bytes: typeArr, encoding: .utf8)!
            print("boxLength", boxLength, typeString)
            switch typeString {
            case "minf":
                mdia.minf = processMinf(data: Data(data[Data.Index(offset)..<Int(offset + boxLength)]))
            case "mdhd":
                mdia.mdhd = processMdhd(data: Data(data[Data.Index(offset)..<Int(offset + boxLength)]))
            default:
                break
            }
            offset += (boxLength - 8)
        }
        return mdia
    }

    private static func processMdhd(data: Data) -> Mdhd {
        var offset: UInt64 = 0
        offset += 4
        offset += 8 // create, mod time
        let timeScale = data.getUint32(offset: &offset)
        return Mdhd(timeScale: timeScale)
    }

    private static func processMinf(data: Data) -> Minf {
        var offset: UInt64 = 0
        var minf = Minf()
        while offset < data.count - 8 {
            let boxLength = UInt64(data.getUint32(offset: &offset))
            let typeArr = data.getUint32(offset: &offset).toUInt8s
            let typeString = String(bytes: typeArr, encoding: .utf8)!
            print("boxLength", boxLength, typeString)
            switch typeString {
            case "stbl":
                minf.stbl = processStbl(data: Data(data[Data.Index(offset)..<Int(offset + boxLength)]))
            default:
                break
            }
            offset += (boxLength - 8)
        }
        return minf
    }

    private static func processStbl(data: Data) -> Stbl {
        var offset: UInt64 = 0
        var stbl = Stbl()
        while offset < data.count - 8 {
            let boxLength = UInt64(data.getUint32(offset: &offset))
            let typeArr = data.getUint32(offset: &offset).toUInt8s
            let typeString = String(bytes: typeArr, encoding: .utf8)!
            print("boxLength", boxLength, typeString)
            switch typeString {
            case "stsz":
                stbl.sampleSizes = processStsz(data: Data(data[Data.Index(offset)..<Int(offset + boxLength)]))
            case "stsc":
                stbl.samplePerChunk = processStsc(data: Data(data[Data.Index(offset)..<Int(offset + boxLength)]))
            case "stco":
                stbl.chunkOffset = processStco(data: Data(data[Data.Index(offset)..<Int(offset + boxLength)]))
            case "stts":
                stbl.sampleDurations = processStts(data: Data(data[Data.Index(offset)..<Int(offset + boxLength)]))
            case "stss":
                stbl.iframeIndexs = processStss(data: Data(data[Data.Index(offset)..<Int(offset + boxLength)]))
            default:
                break
            }
            offset += (boxLength - 8)
        }
        return stbl
    }

    private static func processStss(data: Data) -> [UInt32] {
        // i-frame index
        var indexs = [UInt32]()
        var offset: UInt64 = 0
        offset += 4
        let count = data.getUint32(offset: &offset)
        for _ in 0..<count {
            indexs.append(data.getUint32(offset: &offset))
        }
        return indexs
    }

    private static func processStts(data: Data) -> [UInt32] {
        // sample duration
        var durations = [UInt32]()
        var offset: UInt64 = 0
        offset += 4
        let count = data.getUint32(offset: &offset)
        for _ in 0..<count {
            let sameCount = data.getUint32(offset: &offset)
            let duration = data.getUint32(offset: &offset)
            for _ in 0..<sameCount {
                durations.append(duration)
            }
        }
        return durations
    }

    private static func processStsz(data: Data) -> [UInt32] {
        // sample information
        var samples = [UInt32]()
        var offset: UInt64 = 0
        offset += 4
        let sampleSize = data.getUint32(offset: &offset)
        let sampleCount = data.getUint32(offset: &offset)
        print("stsz", sampleSize, sampleCount)
        if sampleSize == 0 {
            for _ in 0..<sampleCount {
                samples.append(data.getUint32(offset: &offset))
            }
        } else {
            samples = [UInt32](repeating: sampleSize, count: Int(sampleCount))
        }
        return samples
    }

    private static func processStco(data: Data) -> [UInt32] {
        // chunkOffset information
        var offsets = [UInt32]()
        var offset: UInt64 = 0
        offset += 4
        let count = data.getUint32(offset: &offset)
        for _ in 0..<count {
            offsets.append(data.getUint32(offset: &offset))
        }

        return offsets
    }

    private static func processStsc(data: Data) -> [ChunkInfo] {
        // how many sample in a chunk
        var chunks = [ChunkInfo]()
        var offset: UInt64 = 0
        offset += 4
        let chunkCount = data.getUint32(offset: &offset)
        print("chunk", chunkCount)
        for _ in 0..<chunkCount {
            let chunk = ChunkInfo(index: data.getUint32(offset: &offset),
                                  sampleCount: data.getUint32(offset: &offset),
                                  desp: data.getUint32(offset: &offset))
            chunks.append(chunk)
        }
        return chunks
    }

    private static func processTkhd(data: Data) -> Tkhd {
        var offset: UInt64 = 0
        _ = data.getUint8(offset: &offset) // version
        _ = data.getUint8(offset: &offset) // flag
        _ = data.getUint8(offset: &offset) // flag
        _ = data.getUint8(offset: &offset) // flag
        let createTime = data.getUint32(offset: &offset)
        let modification = data.getUint32(offset: &offset)
        let trackID = data.getUint32(offset: &offset)
        _ = data.getUint32(offset: &offset) // reserve
        let duration = data.getUint32(offset: &offset) // duration
        offset += 8 // reserver
        let layer = data.getUint16(offset: &offset)
        let group = data.getUint16(offset: &offset)
        let volume = data.getUint16(offset: &offset)
        offset += 2 // reserver
        offset += 36 // matrix
        let width = data.getUint32(offset: &offset)
        let height = data.getUint32(offset: &offset)
        return Tkhd(createTime: createTime, modification: modification, trackID: trackID, duration: duration, layer: layer, group: group, volume: volume, width: width, height: height)
    }
}

extension MoovParseUtil {
    class FrameInfo {
        let offset: UInt32
        let size: UInt32
        let beginTime: Double
        fileprivate(set) var duration: Double

        init(offset: UInt32, size: UInt32, beginTime: Double, duration: Double) {
            self.offset = offset
            self.size = size
            self.beginTime = beginTime
            self.duration = duration
        }
    }

    static func getIframeList(from moov: Moov) -> [FrameInfo]? {
        guard let trak = moov.trak.first(where: { $0.tkhd?.isVideo == true }) else { return nil }
        guard let info = trak.mdia?.minf.stbl else { return nil }
        guard let timescaleInt = trak.mdia?.mdhd.timeScale else { return nil }
        let timescale = Double(timescaleInt)
        var sampleIndex = 0
        var passDuration: Double = 0
        var frames = [FrameInfo]()
        for (idx, chunk) in info.chunkOffset.enumerated() {
            let sampleCount = info.getSampleCount(for: idx)
            for _ in 0..<sampleCount {
                var passSize: UInt32 = 0
                let sampleSize = info.sampleSizes[sampleIndex]
                let sampleDuration = Double(info.sampleDurations[sampleIndex]) / timescale
                let frame = FrameInfo(offset: chunk + passSize, size: sampleSize, beginTime: passDuration + sampleDuration, duration: sampleDuration)
                passSize += sampleSize
                passDuration += sampleDuration
                sampleIndex += 1
                frames.append(frame)
            }
        }

        var iframes = [FrameInfo]()
        var pervious: FrameInfo?
        for iframeIdx in info.iframeIndexs {
            let frame = frames[Int(iframeIdx) - 1]
            iframes.append(frame)
            if let pervious {
                pervious.duration = frame.beginTime - pervious.beginTime
            }
            pervious = frame
        }
        return iframes
    }
}

extension MoovParseUtil {
    static func generateIframePlayList(iframes: [FrameInfo]) -> String {
        let maxLength = Int(ceil(iframes.map({ $0.duration }).max() ?? 10))
        print(maxLength)
        var playlist = """
        #EXTM3U
        #EXT-X-TARGETDURATION:\(maxLength)
        #EXT-X-VERSION:4
        #EXT-X-MEDIA-SEQUENCE:0
        #EXT-X-PLAYLIST-TYPE:VOD
        #EXT-X-I-FRAMES-ONLY

        """
        for iframe in iframes {
            let inf = String(format: "%.5f", iframe.duration)
            let str = """
            #EXTINF:\(inf),
            #EXT-X-BYTERANGE:\(iframe.size)@\(iframe.offset)
            http://127.0.0.1:8080/2.mp4

            """
            playlist.append(str)
        }
        playlist.append("#EXT-X-ENDLIST\n")
        print(playlist)
        return playlist
    }
}
