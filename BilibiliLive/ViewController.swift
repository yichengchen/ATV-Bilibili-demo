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
    enum LiveError: Error {
        case noLiving
    }
    
    var websocket: WebSocket?
    var heartBeatTimer: Timer?
    var roomID = 11367
    let parser = WSParser()
    let danMuView = DanmakuView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initDanmuView()
        refreshRoomsID(){
            self.initWebsocket()
            self.initPlayer()
        }
        parser.onDanmu = {
            [weak self] string in
            self?.displayDanMu(str: string)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillAppear(animated)
        websocket?.disconnect()
        heartBeatTimer?.invalidate()
        danMuView.stop()
        self.player?.pause()
        self.player = nil
    }
    
    func endWithError(err: Error) {
        dismiss(animated: true, completion: nil)
    }
    
    func refreshRoomsID(complete:(()->Void)?=nil) {
        let url = "https://api.live.bilibili.com/room/v1/Room/room_init?id=\(roomID)"
        AF.request(url).responseJSON {
            [weak self] resp in
            guard let self = self else { return }
            switch resp.result {
            case .success(let object):
                let json = JSON(object)
                let isLive = json["data"]["live_status"].intValue == 1
                if !isLive {
                    self.endWithError(err: LiveError.noLiving)
                    return
                }
                if let newID = json["data"]["room_id"].int {
                    self.roomID = newID
                }
                complete?()
            case .failure(let error):
                self.endWithError(err: error)
            }
        }
    }
    func initDanmuView() {
        view.addSubview(danMuView)
        danMuView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            danMuView.topAnchor.constraint(equalTo: view.topAnchor),
            danMuView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            danMuView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            danMuView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        danMuView.play()
        
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        danMuView.recaculateTracks()
        danMuView.paddingTop = 20
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
                    self.player?.playImmediately(atRate: 1)
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
        heartBeatTimer = Timer.scheduledTimer(timeInterval: 30, target: self, selector: #selector(sendHeartBeat), userInfo: nil, repeats: true)
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
    
    func displayDanMu(str:String) {
        let model = DanmakuTextCellModel(str: str)
        danMuView.shoot(danmaku: model)
    }
}

extension PlayerView: WebSocketDelegate {
    func didReceive(event: WebSocketEvent, client: WebSocket) {
        print(event)
        switch event {
        case .connected(_):
            sendJoinLiveRoom()
            setupHeartBeat()
        case .disconnected(_, _):
            print("disconnect")
        case .binary(let data):
            parser.parseData(data: data)
        default:
            break
        }
    }
    
    
    
    
}
