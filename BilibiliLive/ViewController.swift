//
//  ViewController.swift
//  BilibiliLive
//
//  Created by Etan on 2021/3/27.
//

import UIKit
import AVKit
import Alamofire
import SwiftyJSON
import Starscream
import Gzip

class ViewController: UIViewController {
    let player = AVPlayer()
    override func viewDidLoad() {
        super.viewDidLoad()
    }
}

class PlayerView:AVPlayerViewController {
    
    var websocket: WebSocket?
    var heartBeatTimer: Timer?
    var roomID = 16405
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initWebsocket()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillAppear(animated)
        websocket?.disconnect()
        heartBeatTimer?.invalidate()
    }
    
    func endWithError(err: Error) {
        dismiss(animated: true, completion: nil)
    }
    
    func refreshRoomsID(complete:(()->Void)?=nil) {
        let url = "http://api.live.bilibili.com/room/v1/Room/room_init?id=\(roomID)"
        AF.request(url).responseJSON {
            [weak self] resp in
            guard let self = self else { return }
            switch resp.result {
            case .success(let object):
                let json = JSON(object)
                let isLive = json["live_status"].intValue == 1
            case .failure(let error):
                endWithError(err: error)
            }
        }
    }
    
    func initPlayer() {
        let requestUrl = "https://api.live.bilibili.com/room/v1/Room/playUrl?cid=\(roomID)&platform=h5&otype=json&quality=10000"
        AF.request(requestUrl).responseJSON {
            [unowned self] resp in
            switch resp.result {
            case .success(let object):
                let json = JSON(object)
                if let playUrl = json["data"]["durl"].arrayValue.first?["url"].string {
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
    
    func setupHeartBeat() {
        heartBeatTimer = Timer.scheduledTimer(timeInterval: 60, target: self, selector: #selector(sendHeartBeat), userInfo: nil, repeats: true)
        sendHeartBeat()
    }
    
    @objc func sendHeartBeat() {
        let data = WSParser.getHeartbeatPackage()
        websocket?.write(data: data)
    }
    
    func sendJoinLiveRoom() {
        let data = LiveWSHeader.encode(operatorType: .auth, data: AuthPackage(roomid: roomID).encode())
        websocket?.write(data: data)
    }
}

extension PlayerView: WebSocketDelegate {
    func didReceive(event: WebSocketEvent, client: WebSocket) {
        print(event)
        switch event {
        case .connected(_):
            sendJoinLiveRoom()
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
