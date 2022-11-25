//
//  UpnpDMR.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/11/25.
//

import CocoaAsyncSocket
import CoreMedia
import Foundation
import Swifter
import SwiftyJSON
import UIKit

class BiliBiliUpnpDMR: NSObject {
    static let shared = BiliBiliUpnpDMR()
    private var udp: GCDAsyncUdpSocket!
    private var httpServer = HttpServer()
    private var connectedSockets = [GCDAsyncSocket]()
    private var uuid = UUID().uuidString.components(separatedBy: "-").last!
    private var sessions = Set<NVASession>()

    override private init() { super.init() }
    func start() {
        udp = GCDAsyncUdpSocket(delegate: self, delegateQueue: DispatchQueue.main)
        try? udp.enableBroadcast(true)
        try? udp.bind(toPort: 1900)
        try? udp.joinMulticastGroup("239.255.255.250")
        try? udp.beginReceiving()
        try? httpServer.start(9958)

        httpServer["/"] = { req in
            print("handel TxMediaRenderer_desc")
            let content = """
            <root xmlns:dlna="urn:schemas-dlna-org:device-1-0" xmlns="urn:schemas-upnp-org:device-1-0">
            <specVersion>
              <major>1</major>
              <minor>0</minor>
            </specVersion>
            <device>
              <deviceType>urn:schemas-upnp-org:device:MediaRenderer:1</deviceType>
              <UDN>uuid:cfb75dca-261e-4705-8f0c-d931a5c419fd</UDN>
              <friendlyName>我的小电视</friendlyName>
              <manufacturer>Bilibili Inc.</manufacturer>
              <manufacturerURL>https://bilibili.com/</manufacturerURL>
              <modelDescription>云视听小电视</modelDescription>
              <modelName>16s</modelName>
              <modelNumber>1024</modelNumber>
              <modelURL>https://app.bilibili.com/</modelURL>
              <serialNumber>1024</serialNumber>
              <X_brandName>Meizu</X_brandName>
              <hostVersion>25</hostVersion>
              <ottVersion>104600</ottVersion>
              <channelName>master</channelName>
              <capability>254</capability>
              <dlna:X_DLNADOC xmlns:dlna="urn:schemas-dlna-org:device-1-0">DMR-1.50</dlna:X_DLNADOC>
              <dlna:X_DLNACAP xmlns:dlna="urn:schemas-dlna-org:device-1-0">playcontainer-1-0</dlna:X_DLNACAP>
              <serviceList>
              <service>
                <serviceType>urn:schemas-upnp-org:service:AVTransport:1</serviceType>
                <serviceId>urn:upnp-org:serviceId:AVTransport</serviceId>
                <controlURL>AVTransport/action</controlURL>
                <eventSubURL>AVTransport/event</eventSubURL>
                <SCPDURL>dlna/AVTransport.xml</SCPDURL>
              </service>
              <service>
                <serviceType>urn:schemas-upnp-org:service:RenderingControl:1</serviceType>
                <serviceId>urn:upnp-org:serviceId:RenderingControl</serviceId>
                <controlURL>RenderingControl/action</controlURL>
                <eventSubURL>RenderingControl/event</eventSubURL>
                <SCPDURL>dlna/RenderingControl.xml</SCPDURL>
              </service>
              <service>
                <serviceType>urn:schemas-upnp-org:service:ConnectionManager:1</serviceType>
                <serviceId>urn:upnp-org:serviceId:ConnectionManager</serviceId>
                <controlURL>ConnectionManager/action</controlURL>
                <eventSubURL>ConnectionManager/event</eventSubURL>
                <SCPDURL>dlna/ConnectionManager.xml</SCPDURL>
              </service>
              <service>
                <serviceType>urn:app-bilibili-com:service:NirvanaControl:3</serviceType>
                <serviceId>urn:app-bilibili-com:serviceId:NirvanaControl</serviceId>
                <controlURL>NirvanaControl/action</controlURL>
                <eventSubURL>NirvanaControl/event</eventSubURL>
                <SCPDURL>dlna/NirvanaControl.xml</SCPDURL>
              </service>
              </serviceList>
            </device>
            </root>
            """
            return HttpResponse.ok(.text(content))
        }

        httpServer["projection"] = nvasocket(uuid: "XY12345ABCDE12345ABCDE12345ABCDE12345", didConnect: { [weak self] session in
            self?.sessions.insert(session)
        }, didDisconnect: { [weak self] session in
            self?.sessions.remove(session)
        }, processor: { [weak self] session, frame in
            DispatchQueue.main.async {
                self?.handleEvent(frame: frame, session: session)
            }
        })

        httpServer["/dlna/NirvanaControl.xml"] = {
            req in
            print("handle NirvanaControl")
            let txt = """
            <actionList>
            <action>
            <name>GetAppInfo</name>
            <argumentList></argumentList>
            </action>
            </actionList>
            """
            return HttpResponse.ok(.text(txt))
        }
    }

    private func getIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                guard let interface = ptr?.pointee else { return "" }
                let addrFamily = interface.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) {
                    let name = String(cString: interface.ifa_name)
                    if name == "en0" || name == "en2" || name == "en3" || name == "en4" || name == "pdp_ip0" || name == "pdp_ip1" || name == "pdp_ip2" || name == "pdp_ip3" {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                        address = String(cString: hostname)
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        return address
    }

    private func getSSDPResp() -> String {
        guard let ip = getIPAddress() else { assertionFailure(); return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "E, d MMM yyyy HH:mm:ss"
        return """
        HTTP/1.1 200 OK
        Location: http://\(ip):9958/
        Cache-Control: max-age=1800
        Server: UPnP/1.0 DLNADOC/1.50 Platinum/1.0.4.2
        EXT:
        USN: uuid:atvbilibili&\(uuid)::urn:schemas-upnp-org:service:AVTransport:1
        ST: urn:schemas-upnp-org:service:AVTransport:1
        Date: \(formatter.string(from: Date())) GMT
        """
    }

    func handleEvent(frame: NVASession.NVAFrame, session: NVASession) {
        let topMost = UIViewController.topMostViewController()
        switch frame.action {
        case "GetVolume":
            session.sendReply(content: ["volume": 30])
        case "Play":
            let json = JSON(parseJSON: frame.body)
            let aid = json["aid"].intValue
            let cid = json["cid"].intValue
            let epid = json["epid"].intValue
            let player: VideoDetailViewController
            if epid > 0 {
                player = VideoDetailViewController.create(epid: epid)
            } else {
                player = VideoDetailViewController.create(aid: aid, cid: cid)
            }
            if topMost is CommonPlayerViewController {
                topMost.dismiss(animated: false) {
                    player.present(from: UIViewController.topMostViewController(), direatlyEnterVideo: true)
                }
            } else {
                player.present(from: topMost, direatlyEnterVideo: true)
            }
            session.sendEmpty()
        case "Pause":
            (topMost as? VideoPlayerViewController)?.player?.pause()
            session.sendEmpty()
        case "Resume":
            (topMost as? VideoPlayerViewController)?.player?.play()
            session.sendEmpty()
        case "SwitchDanmaku":
            let json = JSON(parseJSON: frame.body)
            (topMost as? VideoPlayerViewController)?.danMuView.isHidden = !json["open"].boolValue
            session.sendEmpty()
        case "Seek":
            let json = JSON(parseJSON: frame.body)
            (topMost as? VideoPlayerViewController)?.player?.seek(to: CMTime(seconds: json["seekTs"].doubleValue, preferredTimescale: 1), toleranceBefore: .zero, toleranceAfter: .zero)
            session.sendEmpty()
        case "Stop":
            (topMost as? VideoPlayerViewController)?.dismiss(animated: true)
            session.sendEmpty()
        default:
            print("action:", frame.action)
            session.sendEmpty()
        }
    }

    enum PlayStatus: Int {
        case loading = 3
        case playing = 4
        case paused = 5
        case end = 6
        case stop = 7
    }

    func sendStatus(status: PlayStatus) {
        print("send status:", status)
        Array(sessions).forEach { $0.sendCommand(action: "OnPlayState", content: ["playState": status.rawValue]) }
    }

    func sendProgress(duration: Int, current: Int) {
        Array(sessions).forEach { $0.sendCommand(action: "OnProgress", content: ["duration": duration, "position": current]) }
    }
}

extension BiliBiliUpnpDMR: GCDAsyncUdpSocketDelegate {
    func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive data: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {
        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        address.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
            let sockaddrPtr = pointer.bindMemory(to: sockaddr.self)
            guard let unsafePtr = sockaddrPtr.baseAddress else { return }
            guard getnameinfo(unsafePtr, socklen_t(data.count), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 else {
                return
            }
        }
        var ipAddress = String(cString: hostname)
        ipAddress = ipAddress.replacingOccurrences(of: "::ffff:", with: "")
        let str = String(data: data, encoding: .utf8)
        if str?.contains("ssdp:discover") == true {}

        let data = getSSDPResp().data(using: .utf8)!
        sock.send(data, toAddress: address, withTimeout: -1, tag: 0)
    }
}
