//
//  ViewController.swift
//  BilibiliLive
//
//  Created by Etan on 2021/3/27.
//

import UIKit
import AVKit
import Alamofire
import Starscream
import Gzip

class ViewController: UIViewController {
    let player = AVPlayer()
    override func viewDidLoad() {
    }
    
    
}

class PlayerView:AVPlayerViewController {
    
    var websocket: WebSocket?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initWebsocket()
    }
    
    func initPlayer() {
        let roomID = "16405"
        let requestUrl = "https://api.live.bilibili.com/room/v1/Room/playUrl?cid=\(roomID)&platform=h5&otype=json&quality=10000"
        AF.request(requestUrl).responseJSON {
            [unowned self] resp in
            switch resp.result {
            case .success(let json):
                let durls = ((((json as? [String: Any])?["data"]) as? [String: Any])?["durl"]) as? [[String:Any]]
                if let playUrl = durls?.first?["url"] as? String {
                    self.player = AVPlayer(url: URL(string: playUrl)!)
                    self.player?.play()
                } else {
                    dismiss(animated: true, completion: nil)
                }
                
                break
            case .failure(let err):
                print(err)
                dismiss(animated: true, completion: nil)
            }
        }
    }
    
    func initWebsocket() {
        let request = URLRequest(url: URL(string: "ws://broadcastlv.chat.bilibili.com:2244/sub")!)
        websocket = WebSocket(request: request)
        websocket?.delegate = self
        websocket?.connect()
    }
}

extension PlayerView: WebSocketDelegate {
    func didReceive(event: WebSocketEvent, client: WebSocket) {
        print(event)
        switch event {
        case .connected(_):
            print("connected")
            let data = LiveWSHeader.encode(operatorType: .auth, data: AuthPackage().encode())
            client.write(data: data)
        case .disconnected(_, _):
            print("disconnect")
        case .binary(let data):
            parseData(data: data)
        default:
            break
        }
    }
    
    
    func parseData(data: Data, decompressed: Bool = false) {
        let header = LiveWSHeader.decode(data: data)
        let contentData = data.subdata(in: Int(header.headerSize) ..< Int(header.size))
        let operatorType = OperatorType(rawValue: header.operatorType)
        switch operatorType {
        case nil:
            assertionFailure()
            break
        case .authReply:
            print("get authReply")
        case .heaerBeatReply:
            print("get authReply")
        case .normal:
            do {
                if decompressed {
                    parseNormalData(data: contentData)
                } else {
                    parseData(data: try contentData.gunzipped())
                }
            } catch {
                parseNormalData(data: contentData)
            }
        default:
            print("get",operatorType?.rawValue ?? 0)
        }
    }
    
    func parseNormalData(data: Data) {
        let content = String(data: data, encoding: .utf8)
        print(String(data: data, encoding: .utf8) ?? "")
        if content == nil {
            print("000")
        }
    }
    
}
