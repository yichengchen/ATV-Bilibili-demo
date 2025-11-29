//
//  BiliBiliUpnpDMR.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/11/25.
//

import AVFoundation
import CocoaAsyncSocket
import CoreMedia
import Foundation
import Swifter
import SwiftyJSON
import UIKit

class BiliBiliUpnpDMR: NSObject {
    static let shared = BiliBiliUpnpDMR()

    weak var currentPlugin: BUpnpPlugin?

    // SSDP sockets - need separate sockets for multicast receive and unicast send
    private var udpMulticast: GCDAsyncUdpSocket? // For receiving multicast M-SEARCH
    private var udpUnicast: GCDAsyncUdpSocket? // For sending unicast responses
    private var httpServer = HttpServer()
    private var connectedSockets = [GCDAsyncSocket]()
    @MainActor private var sessions = Set<NVASession>()
    private(set) var started = false
    private var ip: String?
    private var boardcastTimer: Timer?

    // Event subscription management
    private var eventSubscriptions: [String: EventSubscription] = [:]
    private let subscriptionQueue = DispatchQueue(label: "com.bilibili.upnp.subscriptions", attributes: .concurrent)
    private var subscriptionCleanupTimer: Timer?

    // DIAL app run state management
    private var dialAppStates: [String: DIALAppState] = [:] // runID -> state

    struct DIALAppState {
        let appName: String
        let runID: String
        var state: String // "running", "stopped"
        let launchedAt: Date
        var metadata: String
    }

    // AVTransport state variables
    private var transportState = "STOPPED" // STOPPED, PLAYING, PAUSED_PLAYBACK, TRANSITIONING, NO_MEDIA_PRESENT
    private var transportStatus = "OK" // OK, ERROR_OCCURRED
    private var currentSpeed = "1"
    private var trackURI = ""
    private var trackMetaData = ""
    var trackDuration = "00:00:00" // Internal for URLPlayPlugin to update
    private var relTime = "00:00:00"

    // RenderingControl state variables
    private var currentVolume = 50
    private var currentMute = false

    // Video loading state tracking (for timing race condition fix)
    private var isLoadingVideo = false
    private var pendingVideoURI: String?

    struct EventSubscription {
        let sid: String
        let service: String // Service this subscription is for (AVTransport, RenderingControl, etc.)
        let callbackURLs: [String]
        let timeout: Int
        let subscribedAt: Date
        var seq: UInt32 = 0 // Sequence number for NOTIFY messages

        var isExpired: Bool {
            return Date().timeIntervalSince(subscribedAt) > Double(timeout)
        }
    }

    private lazy var serverInfo: String = {
        guard let file = Bundle.main.url(forResource: "DLNAInfo", withExtension: "xml"),
              let content = try? String(contentsOf: file)
        else {
            Logger.warn("DLNAInfo.xml not found, using fallback")
            return generateDLNAInfo()
        }
        return content.replacingOccurrences(of: "{{UUID}}", with: bUuid)
    }()

    private lazy var nirvanaControl: String = {
        guard let file = Bundle.main.url(forResource: "NirvanaControl", withExtension: "xml"),
              let content = try? String(contentsOf: file)
        else {
            Logger.warn("NirvanaControl.xml not found, using fallback")
            return generateNirvanaControlScpd()
        }
        return content
    }()

    private lazy var avTransportScpd: String = {
        guard let file = Bundle.main.url(forResource: "AvTransportScpd", withExtension: "xml"),
              let content = try? String(contentsOf: file)
        else {
            Logger.warn("AvTransportScpd.xml not found, using fallback")
            return generateAVTransportScpd()
        }
        return content
    }()

    private lazy var connectionManagerScpd: String = {
        guard let file = Bundle.main.url(forResource: "ConnectionManagerScpd", withExtension: "xml"),
              let content = try? String(contentsOf: file)
        else {
            Logger.warn("ConnectionManagerScpd.xml not found, using fallback")
            return generateConnectionManagerScpd()
        }
        return content
    }()

    private lazy var renderingControlScpd: String = {
        guard let file = Bundle.main.url(forResource: "RenderingControlScpd", withExtension: "xml"),
              let content = try? String(contentsOf: file)
        else {
            Logger.warn("RenderingControlScpd.xml not found, using fallback")
            return generateRenderingControlScpd()
        }
        return content
    }()

    private lazy var dialInfo: String = {
        guard let file = Bundle.main.url(forResource: "DIALInfo", withExtension: "xml"),
              let content = try? String(contentsOf: file)
        else {
            Logger.warn("DIALInfo.xml not found, using fallback")
            return generateDIALInfo()
        }
        return content.replacingOccurrences(of: "{{UUID}}", with: bUuid)
    }()

    private lazy var bUuid: String = {
        if Settings.uuid.count > 0 {
            return Settings.uuid
        }
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        var randomString = ""
        for _ in 0..<35 {
            let rand = arc4random_uniform(36)
            let nextChar = letters[letters.index(letters.startIndex, offsetBy: Int(rand))]
            randomString.append(nextChar)
        }
        Settings.uuid = randomString
        return randomString
    }()

    override private init() { super.init() }

    // Fallback XML generators (in case files are not added to Xcode project)
    private func generateConnectionManagerScpd() -> String {
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <scpd xmlns="urn:schemas-upnp-org:service-1-0">
          <specVersion><major>1</major><minor>0</minor></specVersion>
          <actionList>
            <action><name>GetProtocolInfo</name>
              <argumentList>
                <argument><name>Source</name><direction>out</direction><relatedStateVariable>SourceProtocolInfo</relatedStateVariable></argument>
                <argument><name>Sink</name><direction>out</direction><relatedStateVariable>SinkProtocolInfo</relatedStateVariable></argument>
              </argumentList>
            </action>
            <action><name>GetCurrentConnectionIDs</name>
              <argumentList>
                <argument><name>ConnectionIDs</name><direction>out</direction><relatedStateVariable>CurrentConnectionIDs</relatedStateVariable></argument>
              </argumentList>
            </action>
            <action><name>GetCurrentConnectionInfo</name>
              <argumentList>
                <argument><name>ConnectionID</name><direction>in</direction><relatedStateVariable>A_ARG_TYPE_ConnectionID</relatedStateVariable></argument>
                <argument><name>RcsID</name><direction>out</direction><relatedStateVariable>A_ARG_TYPE_RcsID</relatedStateVariable></argument>
                <argument><name>AVTransportID</name><direction>out</direction><relatedStateVariable>A_ARG_TYPE_AVTransportID</relatedStateVariable></argument>
                <argument><name>ProtocolInfo</name><direction>out</direction><relatedStateVariable>A_ARG_TYPE_ProtocolInfo</relatedStateVariable></argument>
                <argument><name>PeerConnectionManager</name><direction>out</direction><relatedStateVariable>A_ARG_TYPE_ConnectionManager</relatedStateVariable></argument>
                <argument><name>PeerConnectionID</name><direction>out</direction><relatedStateVariable>A_ARG_TYPE_ConnectionID</relatedStateVariable></argument>
                <argument><name>Direction</name><direction>out</direction><relatedStateVariable>A_ARG_TYPE_Direction</relatedStateVariable></argument>
                <argument><name>Status</name><direction>out</direction><relatedStateVariable>A_ARG_TYPE_ConnectionStatus</relatedStateVariable></argument>
              </argumentList>
            </action>
          </actionList>
          <serviceStateTable>
            <stateVariable sendEvents="yes"><name>SourceProtocolInfo</name><dataType>string</dataType></stateVariable>
            <stateVariable sendEvents="yes"><name>SinkProtocolInfo</name><dataType>string</dataType>
              <defaultValue>http-get:*:video/mp4:DLNA.ORG_OP=01;DLNA.ORG_FLAGS=01500000000000000000000000000000,http-get:*:application/x-mpegURL:*</defaultValue>
            </stateVariable>
            <stateVariable sendEvents="yes"><name>CurrentConnectionIDs</name><dataType>string</dataType><defaultValue>0</defaultValue></stateVariable>
            <stateVariable sendEvents="no"><name>A_ARG_TYPE_ConnectionID</name><dataType>i4</dataType></stateVariable>
            <stateVariable sendEvents="no"><name>A_ARG_TYPE_RcsID</name><dataType>i4</dataType></stateVariable>
            <stateVariable sendEvents="no"><name>A_ARG_TYPE_AVTransportID</name><dataType>i4</dataType></stateVariable>
            <stateVariable sendEvents="no"><name>A_ARG_TYPE_ProtocolInfo</name><dataType>string</dataType></stateVariable>
            <stateVariable sendEvents="no"><name>A_ARG_TYPE_ConnectionManager</name><dataType>string</dataType></stateVariable>
            <stateVariable sendEvents="no"><name>A_ARG_TYPE_Direction</name><dataType>string</dataType><allowedValueList><allowedValue>Input</allowedValue><allowedValue>Output</allowedValue></allowedValueList></stateVariable>
            <stateVariable sendEvents="no"><name>A_ARG_TYPE_ConnectionStatus</name><dataType>string</dataType><allowedValueList><allowedValue>OK</allowedValue><allowedValue>ContentFormatMismatch</allowedValue><allowedValue>InsufficientBandwidth</allowedValue><allowedValue>UnreliableChannel</allowedValue><allowedValue>Unknown</allowedValue></allowedValueList></stateVariable>
          </serviceStateTable>
        </scpd>
        """
    }

    private func generateRenderingControlScpd() -> String {
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <scpd xmlns="urn:schemas-upnp-org:service-1-0">
          <specVersion><major>1</major><minor>0</minor></specVersion>
          <actionList>
            <action><name>GetVolume</name>
              <argumentList>
                <argument><name>InstanceID</name><direction>in</direction><relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable></argument>
                <argument><name>Channel</name><direction>in</direction><relatedStateVariable>A_ARG_TYPE_Channel</relatedStateVariable></argument>
                <argument><name>CurrentVolume</name><direction>out</direction><relatedStateVariable>Volume</relatedStateVariable></argument>
              </argumentList>
            </action>
            <action><name>SetVolume</name>
              <argumentList>
                <argument><name>InstanceID</name><direction>in</direction><relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable></argument>
                <argument><name>Channel</name><direction>in</direction><relatedStateVariable>A_ARG_TYPE_Channel</relatedStateVariable></argument>
                <argument><name>DesiredVolume</name><direction>in</direction><relatedStateVariable>Volume</relatedStateVariable></argument>
              </argumentList>
            </action>
            <action><name>GetMute</name>
              <argumentList>
                <argument><name>InstanceID</name><direction>in</direction><relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable></argument>
                <argument><name>Channel</name><direction>in</direction><relatedStateVariable>A_ARG_TYPE_Channel</relatedStateVariable></argument>
                <argument><name>CurrentMute</name><direction>out</direction><relatedStateVariable>Mute</relatedStateVariable></argument>
              </argumentList>
            </action>
            <action><name>SetMute</name>
              <argumentList>
                <argument><name>InstanceID</name><direction>in</direction><relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable></argument>
                <argument><name>Channel</name><direction>in</direction><relatedStateVariable>A_ARG_TYPE_Channel</relatedStateVariable></argument>
                <argument><name>DesiredMute</name><direction>in</direction><relatedStateVariable>Mute</relatedStateVariable></argument>
              </argumentList>
            </action>
          </actionList>
          <serviceStateTable>
            <stateVariable sendEvents="no"><name>Mute</name><dataType>boolean</dataType><defaultValue>0</defaultValue></stateVariable>
            <stateVariable sendEvents="no"><name>Volume</name><dataType>ui2</dataType><defaultValue>50</defaultValue><allowedValueRange><minimum>0</minimum><maximum>100</maximum><step>1</step></allowedValueRange></stateVariable>
            <stateVariable sendEvents="no"><name>A_ARG_TYPE_Channel</name><dataType>string</dataType><allowedValueList><allowedValue>Master</allowedValue></allowedValueList></stateVariable>
            <stateVariable sendEvents="no"><name>A_ARG_TYPE_InstanceID</name><dataType>ui4</dataType></stateVariable>
          </serviceStateTable>
        </scpd>
        """
    }

    private func generateDIALInfo() -> String {
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <root xmlns="urn:schemas-upnp-org:device-1-0" xmlns:r="urn:restful-tv-org:schemas:upnp-dd">
          <specVersion><major>1</major><minor>0</minor></specVersion>
          <device>
            <deviceType>urn:dial-multiscreen-org:device:dial:1</deviceType>
            <friendlyName>我的小电视</friendlyName>
            <manufacturer>Bilibili Inc.</manufacturer>
            <modelName>BRAVIA 4K 2015</modelName>
            <UDN>uuid:\(bUuid)</UDN>
            <serviceList>
              <service>
                <serviceType>urn:dial-multiscreen-org:service:dial:1</serviceType>
                <serviceId>urn:dial-multiscreen-org:serviceId:dial</serviceId>
                <controlURL>/apps</controlURL>
                <eventSubURL>/dial/event</eventSubURL>
                <SCPDURL>/dial/service.xml</SCPDURL>
              </service>
            </serviceList>
          </device>
        </root>
        """
    }

    private func generateDIALServiceScpd() -> String {
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <scpd xmlns="urn:schemas-upnp-org:service-1-0">
          <specVersion><major>1</major><minor>0</minor></specVersion>
          <actionList>
            <action><name>GetAppState</name>
              <argumentList>
                <argument><name>AppName</name><direction>in</direction><relatedStateVariable>A_ARG_TYPE_AppName</relatedStateVariable></argument>
                <argument><name>State</name><direction>out</direction><relatedStateVariable>A_ARG_TYPE_AppState</relatedStateVariable></argument>
              </argumentList>
            </action>
          </actionList>
          <serviceStateTable>
            <stateVariable sendEvents="no"><name>A_ARG_TYPE_AppName</name><dataType>string</dataType></stateVariable>
            <stateVariable sendEvents="no"><name>A_ARG_TYPE_AppState</name><dataType>string</dataType></stateVariable>
          </serviceStateTable>
        </scpd>
        """
    }

    func start() {
        startIfNeed()
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)

        httpServer["/description.xml"] = { [weak self] req in
            let clientIP = req.headers["x-forwarded-for"] ?? req.headers["host"] ?? "unknown"
            Logger.info("[HTTP] 📥 GET /description.xml from \(clientIP)")
            return HttpResponse.ok(.text(self?.serverInfo ?? ""))
        }

        httpServer["projection"] = nvasocket(uuid: bUuid, didConnect: { [weak self] session in
            Logger.info("[NVA] ✅ WebSocket session connected: \(session)")
            DispatchQueue.main.async {
                self?.sessions.insert(session)
            }
        }, didDisconnect: { [weak self] session in
            Logger.info("[NVA] WebSocket session disconnected: \(session)")
            DispatchQueue.main.async {
                self?.sessions.remove(session)
            }
        }, processor: { [weak self] session, frame in
            DispatchQueue.main.async {
                self?.handleEvent(frame: frame, session: session)
            }
        })

        httpServer["/dlna/NirvanaControl.xml"] = {
            [weak self] req in
            Logger.debug("handle NirvanaControl")
            let txt = self?.nirvanaControl ?? ""
            return HttpResponse.ok(.text(txt))
        }

        httpServer.get["/dlna/AVTransport.xml"] = {
            [weak self] req in
            Logger.debug("handle AVTransport.xml")
            let txt = self?.avTransportScpd ?? ""
            return HttpResponse.ok(.text(txt))
        }

        httpServer.get["/dlna/ConnectionManager.xml"] = {
            [weak self] req in
            Logger.debug("handle ConnectionManager.xml")
            let txt = self?.connectionManagerScpd ?? ""
            return HttpResponse.ok(.text(txt))
        }

        httpServer.get["/dlna/RenderingControl.xml"] = {
            [weak self] req in
            Logger.debug("handle RenderingControl.xml")
            let txt = self?.renderingControlScpd ?? ""
            return HttpResponse.ok(.text(txt))
        }

        httpServer.post["/AVTransport/action"] = {
            [weak self] req in
            let str = String(data: Data(req.body), encoding: .utf8) ?? ""
            let soapAction = req.headers["soapaction"] ?? ""
            Logger.debug("handle AVTransport action, SOAPACTION: \(soapAction)")
            return self?.handleAVTransportAction(body: str, soapAction: soapAction) ?? HttpResponse.ok(.text(str))
        }

        httpServer.post["/ConnectionManager/action"] = {
            [weak self] req in
            let str = String(data: Data(req.body), encoding: .utf8) ?? ""
            let soapAction = req.headers["soapaction"] ?? ""
            Logger.debug("handle ConnectionManager action, SOAPACTION: \(soapAction)")
            return self?.handleConnectionManagerAction(body: str, soapAction: soapAction) ?? HttpResponse.ok(.text(""))
        }

        httpServer.post["/RenderingControl/action"] = {
            [weak self] req in
            let str = String(data: Data(req.body), encoding: .utf8) ?? ""
            let soapAction = req.headers["soapaction"] ?? ""
            Logger.debug("handle RenderingControl action, SOAPACTION: \(soapAction)")
            return self?.handleRenderingControlAction(body: str, soapAction: soapAction) ?? HttpResponse.ok(.text(""))
        }

        httpServer["AVTransport/event"] = {
            [weak self] req in
            return self?.handleEventSubscription(request: req, service: "AVTransport") ?? HttpResponse.internalServerError(nil)
        }

        httpServer["ConnectionManager/event"] = {
            [weak self] req in
            return self?.handleEventSubscription(request: req, service: "ConnectionManager") ?? HttpResponse.internalServerError(nil)
        }

        httpServer["RenderingControl/event"] = {
            [weak self] req in
            return self?.handleEventSubscription(request: req, service: "RenderingControl") ?? HttpResponse.internalServerError(nil)
        }

        httpServer["/dial/event"] = {
            [weak self] req in
            return self?.handleEventSubscription(request: req, service: "DIAL") ?? HttpResponse.internalServerError(nil)
        }

        // DIAL support
        httpServer["/ssdp/device-desc.xml"] = {
            [weak self] req in
            Logger.debug("handle DIAL device description")
            return HttpResponse.ok(.text(self?.dialInfo ?? ""))
        }

        httpServer.get["/dial/service.xml"] = {
            [weak self] req in
            Logger.debug("handle DIAL service description")
            return HttpResponse.ok(.text(self?.generateDIALServiceScpd() ?? ""))
        }

        httpServer.get["/apps/:appName"] = {
            req in
            let appName = req.params.first?.value ?? ""
            Logger.debug("DIAL app query: \(appName)")
            return self.handleDIALAppQuery(appName: appName)
        }

        httpServer.post["/apps/:appName"] = {
            req in
            let appName = req.params.first?.value ?? ""
            let body = String(data: Data(req.body), encoding: .utf8) ?? ""
            Logger.debug("DIAL app launch: \(appName), body: \(body)")
            return self.handleDIALAppLaunch(appName: appName, body: body)
        }

        // DIAL run state query
        httpServer.get["/apps/:appName/run/:runID"] = {
            [weak self] req in
            guard let runID = req.params["runID"] else {
                return HttpResponse.notFound()
            }

            guard let state = self?.dialAppStates[runID] else {
                Logger.warn("DIAL run state not found: \(runID)")
                return HttpResponse.notFound()
            }

            let stateXML = """
            <?xml version="1.0"?>
            <service xmlns="urn:dial-multiscreen-org:schemas:dial">
            <name>\(state.appName)</name>
            <state>\(state.state)</state>
            </service>
            """
            Logger.debug("DIAL run state query: \(runID) -> \(state.state)")
            return HttpResponse.ok(.text(stateXML))
        }

        // DIAL app stop
        httpServer.delete["/apps/:appName/run/:runID"] = {
            [weak self] req in
            guard let runID = req.params["runID"] else {
                return HttpResponse.notFound()
            }

            guard var state = self?.dialAppStates[runID] else {
                Logger.warn("DIAL run state not found for DELETE: \(runID)")
                return HttpResponse.notFound()
            }

            // Actually stop playback when DIAL app is stopped
            Task { @MainActor in
                Logger.info("DIAL stopping app: \(state.appName) runID: \(runID)")

                // Call Stop to dismiss player
                if let plugin = self?.currentPlugin {
                    plugin.pause()

                    // Dismiss the player
                    if let topVC = UIViewController.topMostViewController(),
                       topVC is VideoDetailViewController || topVC is CommonPlayerViewController
                    {
                        topVC.dismiss(animated: true) {
                            Logger.info("Player dismissed by DIAL stop")
                        }
                    }

                    self?.currentPlugin = nil
                }

                // Update state
                state.state = "stopped"
                self?.dialAppStates[runID] = state

                // Update transport state
                self?.transportState = "STOPPED"
                self?.relTime = "00:00:00"
                self?.notifyStateChange(service: "AVTransport", properties: [
                    "TransportState": "STOPPED",
                    "RelativeTimePosition": "00:00:00",
                ])
            }

            return HttpResponse.raw(200, "OK", ["Content-Length": "0"], nil)
        }

        httpServer["/debug/log"] = {
            req in
            if let path = Logger.latestLogPath(),
               let str = try? String(contentsOf: URL(fileURLWithPath: path))
            {
                return HttpResponse.ok(.text(str))
            }
            return HttpResponse.internalServerError(nil)
        }

        httpServer["/debug/old"] = {
            req in
            if let path = Logger.oldestLogPath(),
               let str = try? String(contentsOf: URL(fileURLWithPath: path))
            {
                return HttpResponse.ok(.text(str))
            }
            return HttpResponse.internalServerError(nil)
        }
    }

    func stop() {
        // Send ssdp:byebye before stopping
        if started {
            sendSSDPNotify(nts: "ssdp:byebye")
        }

        boardcastTimer?.invalidate()
        boardcastTimer = nil
        subscriptionCleanupTimer?.invalidate()
        subscriptionCleanupTimer = nil
        removeAllSubscriptions()

        // Properly close and release UDP sockets
        udpMulticast?.close()
        udpMulticast = nil
        udpUnicast?.close()
        udpUnicast = nil

        httpServer.stop()
        started = false
        Logger.info("[DLNA] DMR stopped")
    }

    @objc func didEnterBackground() {
        stop()
    }

    @objc func willEnterForeground() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.startIfNeed()
        }
    }

    private func startIfNeed() {
        stop()
        guard Settings.enableDLNA else {
            Logger.info("[DLNA] DLNA is disabled in settings, skipping start")
            return
        }

        // Get network interface info
        let networkInfo = getNetworkInterface()
        ip = networkInfo?.ip
        let interfaceName = networkInfo?.name

        Logger.info("[DLNA] Starting DMR with IP: \(ip ?? "unknown"), interface: \(interfaceName ?? "unknown"), UUID: \(bUuid)")

        if !started {
            do {
                // === Setup unicast socket for sending responses (do this first) ===
                let unicastSocket = GCDAsyncUdpSocket(delegate: self, delegateQueue: DispatchQueue.main)
                udpUnicast = unicastSocket
                try unicastSocket.enableBroadcast(true)
                try unicastSocket.bind(toPort: 0) // Random port for sending
                Logger.info("[DLNA] Unicast socket: bound to port \(unicastSocket.localPort())")

                // === Setup multicast socket for receiving M-SEARCH ===
                let multicastSocket = GCDAsyncUdpSocket(delegate: self, delegateQueue: DispatchQueue.main)
                udpMulticast = multicastSocket

                // Enable port reuse - critical for multicast
                try multicastSocket.enableReusePort(true)
                Logger.info("[DLNA] Multicast socket: reuse port enabled")

                // Try to bind and join multicast with different strategies
                var multicastSuccess = false

                // Strategy 1: Try with detected interface name
                if let ifName = interfaceName {
                    do {
                        try multicastSocket.bind(toPort: 1900, interface: ifName)
                        try multicastSocket.joinMulticastGroup("239.255.255.250", onInterface: ifName)
                        Logger.info("[DLNA] Multicast socket: bound to port 1900 on \(ifName)")
                        multicastSuccess = true
                    } catch {
                        Logger.warn("[DLNA] Failed to bind multicast on \(ifName): \(error.localizedDescription)")
                    }
                }

                // Strategy 2: Try with IP address as interface
                if !multicastSuccess, let ipAddr = ip {
                    do {
                        udpMulticast?.close()
                        let newMulticast = GCDAsyncUdpSocket(delegate: self, delegateQueue: DispatchQueue.main)
                        udpMulticast = newMulticast
                        try newMulticast.enableReusePort(true)
                        try newMulticast.bind(toPort: 1900, interface: ipAddr)
                        try newMulticast.joinMulticastGroup("239.255.255.250", onInterface: ipAddr)
                        Logger.info("[DLNA] Multicast socket: bound to port 1900 on IP \(ipAddr)")
                        multicastSuccess = true
                    } catch {
                        Logger.warn("[DLNA] Failed to bind multicast on IP \(ipAddr): \(error.localizedDescription)")
                    }
                }

                // Strategy 3: Try without specifying interface (nil = all interfaces)
                if !multicastSuccess {
                    do {
                        udpMulticast?.close()
                        let newMulticast = GCDAsyncUdpSocket(delegate: self, delegateQueue: DispatchQueue.main)
                        udpMulticast = newMulticast
                        try newMulticast.enableReusePort(true)
                        try newMulticast.bind(toPort: 1900)
                        try newMulticast.joinMulticastGroup("239.255.255.250")
                        Logger.info("[DLNA] Multicast socket: bound to port 1900 on all interfaces")
                        multicastSuccess = true
                    } catch {
                        Logger.warn("[DLNA] Failed to bind multicast on all interfaces: \(error.localizedDescription)")
                    }
                }

                // Strategy 4: Fallback - just receive on any port (won't get SSDP multicast but can still work via Bonjour)
                if !multicastSuccess {
                    Logger.warn("[DLNA] ⚠️ Could not bind to multicast port 1900, SSDP discovery may not work")
                    Logger.warn("[DLNA] ⚠️ Device will rely on Bonjour/mDNS for discovery")
                    udpMulticast?.close()
                    udpMulticast = nil
                }

                if let multicast = udpMulticast {
                    try multicast.beginReceiving()
                    Logger.info("[DLNA] Multicast socket: receiving started")
                }

                // === Start HTTP server ===
                try httpServer.start(9958)
                Logger.info("[DLNA] HTTP server started on port 9958")

                started = true
                Logger.info("[DLNA] ✅ DMR started successfully")
                Logger.info("[DLNA] 📺 Device: 我的小电视")
                Logger.info("[DLNA] 🌐 IP: \(ip ?? "unknown"):9958")
                Logger.info("[DLNA] 🔑 UUID: \(bUuid)")
                if !multicastSuccess {
                    Logger.info("[DLNA] ⚠️ SSDP multicast disabled")
                }

                // Send immediate ssdp:alive on startup
                sendSSDPNotify(nts: "ssdp:alive")
                Logger.info("[DLNA] Initial SSDP alive notification sent")

            } catch let err {
                started = false
                Logger.warn("[DLNA] ❌ DMR start failed: \(err.localizedDescription)")

                // Cleanup on failure
                udpMulticast?.close()
                udpMulticast = nil
                udpUnicast?.close()
                udpUnicast = nil
            }
        }
        boardcastTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) {
            [weak self] _ in
            self?.sendSSDPNotify(nts: "ssdp:alive")
        }

        // Start subscription cleanup timer (every 5 minutes)
        subscriptionCleanupTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) {
            [weak self] _ in
            self?.cleanupExpiredSubscriptions()
        }
    }

    private func sendSSDPNotify(nts: String) {
        guard let udpUnicast = udpUnicast else {
            Logger.warn("[SSDP] Cannot send NOTIFY: unicast socket not available")
            return
        }
        for notify in getSSDPNotify(nts: nts) {
            if let data = notify.data(using: .utf8) {
                udpUnicast.send(data, toHost: "239.255.255.250", port: 1900, withTimeout: 1, tag: 0)
                Logger.debug("[SSDP] Sent NOTIFY (\(nts))")
            }
        }
    }

    private func getIPAddress() -> String? {
        let result = getNetworkInterface()
        return result?.ip
    }

    /// Returns (interfaceName, ipAddress) tuple for the active network interface
    func getNetworkInterface() -> (name: String, ip: String)? {
        var result: (name: String, ip: String)?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                guard let interface = ptr?.pointee else { continue }
                let addrFamily = interface.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) {
                    let name = String(cString: interface.ifa_name)
                    // Check for common network interface names on tvOS/iOS
                    // en0 is usually WiFi, but tvOS might use different names
                    let validInterfaces = ["en0", "en1", "en2", "en3", "en4", "en5", "en6", "eth0", "eth1"]
                    if validInterfaces.contains(name) {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                        let ip = String(cString: hostname)
                        Logger.debug("[DLNA] Found interface: \(name) with IP: \(ip)")
                        result = (name: name, ip: ip)
                        // Prefer en0 if available, otherwise take first valid
                        if name == "en0" {
                            break
                        }
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        return result
    }

    private var bootId: Int = .init(Date().timeIntervalSince1970)
    private var configId: Int = 1

    private func getSSDPResp(searchTarget: String = "upnp:rootdevice") -> String {
        guard let ip = ip ?? getIPAddress() else {
            Logger.debug("no ip")
            return ""
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "E, d MMM yyyy HH:mm:ss"

        let usn: String
        let location: String

        // Fix DIAL LOCATION to point to correct device description
        if searchTarget.contains("dial") {
            location = "http://\(ip):9958/ssdp/device-desc.xml"
            usn = "uuid:\(bUuid)::urn:dial-multiscreen-org:service:dial:1"
        } else {
            location = "http://\(ip):9958/description.xml"
            if searchTarget == "upnp:rootdevice" {
                usn = "uuid:\(bUuid)::upnp:rootdevice"
            } else if searchTarget == "ssdp:all" {
                // Fix: ssdp:all should respond with rootdevice USN
                usn = "uuid:\(bUuid)::upnp:rootdevice"
            } else if searchTarget.contains("MediaRenderer") {
                usn = "uuid:\(bUuid)::urn:schemas-upnp-org:device:MediaRenderer:1"
            } else if searchTarget.contains("AVTransport") {
                usn = "uuid:\(bUuid)::urn:schemas-upnp-org:service:AVTransport:1"
            } else if searchTarget.contains("ConnectionManager") {
                usn = "uuid:\(bUuid)::urn:schemas-upnp-org:service:ConnectionManager:1"
            } else if searchTarget.contains("RenderingControl") {
                usn = "uuid:\(bUuid)::urn:schemas-upnp-org:service:RenderingControl:1"
            } else if searchTarget.contains("NirvanaControl") || searchTarget.contains("bilibili") {
                usn = "uuid:\(bUuid)::urn:app-bilibili-com:service:NirvanaControl:3"
            } else {
                usn = "uuid:\(bUuid)"
            }
        }

        return """
        HTTP/1.1 200 OK\r
        LOCATION: \(location)\r
        CACHE-CONTROL: max-age=1800\r
        SERVER: Linux/3.0.0 UPnP/1.0 Platinum/1.0.5.13\r
        EXT:\r
        BOOTID.UPNP.ORG: \(bootId)\r
        CONFIGID.UPNP.ORG: \(configId)\r
        USN: \(usn)\r
        ST: \(searchTarget)\r
        DATE: \(formatter.string(from: Date())) GMT\r
        \r
        """
    }

    private func getSSDPNotify(nts: String = "ssdp:alive") -> [String] {
        guard let ip = ip ?? getIPAddress() else {
            Logger.debug("no ip")
            return []
        }

        let notifyTypes: [(nt: String, location: String)] = [
            ("upnp:rootdevice", "http://\(ip):9958/description.xml"),
            ("uuid:\(bUuid)", "http://\(ip):9958/description.xml"),
            ("urn:schemas-upnp-org:device:MediaRenderer:1", "http://\(ip):9958/description.xml"),
            ("urn:schemas-upnp-org:service:AVTransport:1", "http://\(ip):9958/description.xml"),
            ("urn:schemas-upnp-org:service:ConnectionManager:1", "http://\(ip):9958/description.xml"),
            ("urn:schemas-upnp-org:service:RenderingControl:1", "http://\(ip):9958/description.xml"),
            ("urn:app-bilibili-com:service:NirvanaControl:3", "http://\(ip):9958/description.xml"),
            ("urn:dial-multiscreen-org:service:dial:1", "http://\(ip):9958/ssdp/device-desc.xml"),
        ]

        return notifyTypes.map { item in
            let usn = item.nt == "upnp:rootdevice" ? "uuid:\(bUuid)::\(item.nt)" : (item.nt.starts(with: "uuid:") ? item.nt : "uuid:\(bUuid)::\(item.nt)")
            return """
            NOTIFY * HTTP/1.1\r
            HOST: 239.255.255.250:1900\r
            LOCATION: \(item.location)\r
            CACHE-CONTROL: max-age=1800\r
            SERVER: Linux/3.0.0 UPnP/1.0 Platinum/1.0.5.13\r
            NTS: \(nts)\r
            NT: \(item.nt)\r
            USN: \(usn)\r
            BOOTID.UPNP.ORG: \(bootId)\r
            CONFIGID.UPNP.ORG: \(configId)\r
            \r
            """
        }
    }

    // SOAP Action Handlers
    private func handleAVTransportAction(body: String, soapAction: String) -> HttpResponse {
        // Extract action name from SOAPACTION header (format: "urn:...:service:ServiceType:Version#ActionName")
        let actionName = extractActionName(from: soapAction)

        // Validate service type
        guard soapAction.contains("AVTransport:1") else {
            return createSOAPFault(
                faultCode: "s:Client",
                faultString: "Invalid service type in SOAPACTION header"
            )
        }

        if actionName == "GetTransportInfo" || body.contains("GetTransportInfo") {
            return createSOAPResponse(
                serviceType: "urn:schemas-upnp-org:service:AVTransport:1",
                action: "GetTransportInfo",
                content: """
                <CurrentTransportState>\(transportState)</CurrentTransportState>
                <CurrentTransportStatus>\(transportStatus)</CurrentTransportStatus>
                <CurrentSpeed>\(currentSpeed)</CurrentSpeed>
                """
            )
        } else if body.contains("GetPositionInfo") {
            return createSOAPResponse(
                serviceType: "urn:schemas-upnp-org:service:AVTransport:1",
                action: "GetPositionInfo",
                content: """
                <Track>1</Track>
                <TrackDuration>\(trackDuration)</TrackDuration>
                <TrackMetaData>\(escapeXML(trackMetaData))</TrackMetaData>
                <TrackURI>\(escapeXML(trackURI))</TrackURI>
                <RelTime>\(relTime)</RelTime>
                <AbsTime>\(relTime)</AbsTime>
                <RelCount>2147483647</RelCount>
                <AbsCount>2147483647</AbsCount>
                """
            )
        } else if body.contains("GetDeviceCapabilities") {
            return createSOAPResponse(
                serviceType: "urn:schemas-upnp-org:service:AVTransport:1",
                action: "GetDeviceCapabilities",
                content: """
                <PlayMedia>NETWORK,HDD</PlayMedia>
                <RecMedia>NOT_IMPLEMENTED</RecMedia>
                <RecQualityModes>NOT_IMPLEMENTED</RecQualityModes>
                """
            )
        } else if body.contains("SetAVTransportURI") {
            // Parse URI and metadata from SOAP body
            guard let currentURI = parseSOAPParameter(body, parameter: "CurrentURI") else {
                Logger.warn("SetAVTransportURI: missing CurrentURI parameter")
                return createSOAPFault(
                    faultCode: "s:Client",
                    faultString: "Missing required parameter: CurrentURI",
                    upnpErrorCode: 402,
                    upnpErrorDescription: "Invalid Args"
                )
            }

            let currentURIMetaData = parseSOAPParameter(body, parameter: "CurrentURIMetaData") ?? ""

            // Update transport state
            trackURI = currentURI
            trackMetaData = currentURIMetaData
            transportState = "STOPPED" // URI loaded, ready to play
            relTime = "00:00:00"

            Logger.info("SetAVTransportURI: URI=\(currentURI)")

            // Load video into player
            Task { @MainActor in
                loadVideo(uri: currentURI, metadata: currentURIMetaData)
            }

            // Notify subscribers of state change
            notifyStateChange(service: "AVTransport", properties: [
                "AVTransportURI": trackURI,
                "AVTransportURIMetaData": trackMetaData,
                "TransportState": transportState,
            ])

            return createSOAPResponse(
                serviceType: "urn:schemas-upnp-org:service:AVTransport:1",
                action: "SetAVTransportURI",
                content: ""
            )
        } else if body.contains("Play") {
            // Verify that a URI has been set
            guard !trackURI.isEmpty else {
                Logger.warn("Play: no URI set")
                return createSOAPFault(
                    faultCode: "s:Client",
                    faultString: "No AVTransportURI set",
                    upnpErrorCode: 701,
                    upnpErrorDescription: "Transition not available"
                )
            }

            // Parse optional Speed parameter (default "1")
            let speed = parseSOAPParameter(body, parameter: "Speed") ?? "1"
            currentSpeed = speed

            // Update transport state
            transportState = "PLAYING"

            Logger.info("Play: URI=\(trackURI) Speed=\(speed)")

            // Trigger actual playback
            if let plugin = currentPlugin {
                // Resume existing playback
                plugin.resume()

                // Notify subscribers of state change
                notifyStateChange(service: "AVTransport", properties: [
                    "TransportState": transportState,
                    "CurrentSpeed": currentSpeed,
                ])

                return createSOAPResponse(
                    serviceType: "urn:schemas-upnp-org:service:AVTransport:1",
                    action: "Play",
                    content: ""
                )
            } else if isLoadingVideo {
                // Video is currently loading - return error indicating transitioning
                Logger.warn("Play called while video loading - player not ready")
                transportState = "TRANSITIONING"
                transportStatus = "OK"

                notifyStateChange(service: "AVTransport", properties: [
                    "TransportState": transportState,
                    "TransportStatus": transportStatus,
                ])

                // Return fault - player is transitioning, not ready to play
                return createSOAPFault(
                    faultCode: "s:Server",
                    faultString: "Player is loading, not ready to play",
                    upnpErrorCode: 701,
                    upnpErrorDescription: "Transition not available"
                )
            } else {
                // No active player and not loading - SetAVTransportURI wasn't called
                Logger.warn("Play called but no media loaded")
                transportState = "NO_MEDIA_PRESENT"
                transportStatus = "OK"

                notifyStateChange(service: "AVTransport", properties: [
                    "TransportState": transportState,
                    "TransportStatus": transportStatus,
                ])

                return createSOAPFault(
                    faultCode: "s:Server",
                    faultString: "No media present",
                    upnpErrorCode: 701,
                    upnpErrorDescription: "Transition not available"
                )
            }
        } else if body.contains("Pause") {
            // Update transport state
            transportState = "PAUSED_PLAYBACK"

            Logger.info("Pause called")

            // Pause actual playback
            currentPlugin?.pause()

            // Notify subscribers of state change
            notifyStateChange(service: "AVTransport", properties: [
                "TransportState": transportState,
            ])

            return createSOAPResponse(
                serviceType: "urn:schemas-upnp-org:service:AVTransport:1",
                action: "Pause",
                content: ""
            )
        } else if body.contains("Stop") {
            // Update transport state
            transportState = "STOPPED"
            relTime = "00:00:00"

            Logger.info("Stop called")

            // Stop actual playback and dismiss player
            Task { @MainActor in
                if let plugin = currentPlugin {
                    plugin.pause()

                    // Dismiss the player - handle both VideoDetailViewController and CommonPlayerViewController
                    guard let topVC = UIViewController.topMostViewController() else {
                        currentPlugin = nil
                        return
                    }

                    if topVC is VideoDetailViewController || topVC is CommonPlayerViewController {
                        // Dismiss the video player
                        topVC.dismiss(animated: true) {
                            Logger.info("Video player dismissed after Stop: \(type(of: topVC))")
                        }
                    } else if let presentedVC = topVC.presentedViewController,
                              presentedVC is VideoDetailViewController || presentedVC is CommonPlayerViewController
                    {
                        // Player is presented on top of current VC
                        presentedVC.dismiss(animated: true) {
                            Logger.info("Presented video player dismissed after Stop: \(type(of: presentedVC))")
                        }
                    } else {
                        // Fallback: try to dismiss any presented VC
                        Logger.warn("Stop: Could not find video player VC, attempting generic dismiss")
                        AppDelegate.shared.window?.rootViewController?.presentedViewController?.dismiss(animated: true) {
                            Logger.info("Generic presented VC dismissed after Stop")
                        }
                    }

                    // Clear the current plugin
                    currentPlugin = nil
                }

                // Clear loading state
                isLoadingVideo = false
                pendingVideoURI = nil
            }

            // Notify subscribers of state change
            notifyStateChange(service: "AVTransport", properties: [
                "TransportState": transportState,
                "RelativeTimePosition": relTime,
            ])

            return createSOAPResponse(
                serviceType: "urn:schemas-upnp-org:service:AVTransport:1",
                action: "Stop",
                content: ""
            )
        } else if actionName == "Seek" || body.contains("Seek") {
            // Parse Unit and Target from SOAP body
            guard let unit = parseSOAPParameter(body, parameter: "Unit"),
                  let target = parseSOAPParameter(body, parameter: "Target")
            else {
                Logger.warn("Seek: missing Unit or Target parameter")
                return createSOAPFault(
                    faultCode: "s:Client",
                    faultString: "Missing required parameter: Unit or Target",
                    upnpErrorCode: 402,
                    upnpErrorDescription: "Invalid Args"
                )
            }

            Logger.info("Seek: Unit=\(unit) Target=\(target)")

            // Update relative time for supported seek modes
            if unit == "ABS_TIME" || unit == "REL_TIME" {
                // Check if player is available
                guard let plugin = currentPlugin else {
                    Logger.warn("Seek called but no active player")
                    return createSOAPFault(
                        faultCode: "s:Server",
                        faultString: "No media present",
                        upnpErrorCode: 701,
                        upnpErrorDescription: "Transition not available"
                    )
                }

                // Convert HH:MM:SS to TimeInterval
                let targetSeconds = parseTimeString(target)

                // Perform seek
                plugin.seek(to: targetSeconds)
                relTime = target
                Logger.info("Seek to \(target) (\(targetSeconds)s)")

                // Notify subscribers of position change
                notifyStateChange(service: "AVTransport", properties: [
                    "RelativeTimePosition": relTime,
                    "AbsoluteTimePosition": relTime,
                ])
            } else if unit == "TRACK_NR" {
                // Track number seeking not implemented for single-track playback
                Logger.warn("Seek: TRACK_NR not implemented")
                return createSOAPFault(
                    faultCode: "s:Client",
                    faultString: "Seek mode not supported",
                    upnpErrorCode: 710,
                    upnpErrorDescription: "Seek mode not supported"
                )
            }

            return createSOAPResponse(
                serviceType: "urn:schemas-upnp-org:service:AVTransport:1",
                action: "Seek",
                content: ""
            )
        }

        // Unknown action - return SOAP Fault
        Logger.warn("Unknown AVTransport action: \(actionName)")
        return createSOAPFault(
            faultCode: "s:Client",
            faultString: "Invalid Action: \(actionName)",
            upnpErrorCode: 401,
            upnpErrorDescription: "Invalid Action"
        )
    }

    private func handleConnectionManagerAction(body: String, soapAction: String) -> HttpResponse {
        let actionName = extractActionName(from: soapAction)

        guard soapAction.contains("ConnectionManager:1") else {
            return createSOAPFault(
                faultCode: "s:Client",
                faultString: "Invalid service type in SOAPACTION header"
            )
        }

        if actionName == "GetProtocolInfo" || body.contains("GetProtocolInfo") {
            let protocolInfo = """
            http-get:*:video/mp4:DLNA.ORG_PN=AVC_MP4_BL_CIF15_AAC_520;DLNA.ORG_OP=01;DLNA.ORG_FLAGS=01500000000000000000000000000000,\
            http-get:*:video/x-matroska:DLNA.ORG_OP=01;DLNA.ORG_FLAGS=01500000000000000000000000000000,\
            http-get:*:application/x-mpegURL:*,\
            http-get:*:application/vnd.apple.mpegurl:*,\
            http-get:*:video/MP2T:DLNA.ORG_OP=01;DLNA.ORG_FLAGS=01500000000000000000000000000000
            """
            return createSOAPResponse(
                serviceType: "urn:schemas-upnp-org:service:ConnectionManager:1",
                action: "GetProtocolInfo",
                content: """
                <Source></Source>
                <Sink>\(protocolInfo)</Sink>
                """
            )
        } else if body.contains("GetCurrentConnectionIDs") {
            return createSOAPResponse(
                serviceType: "urn:schemas-upnp-org:service:ConnectionManager:1",
                action: "GetCurrentConnectionIDs",
                content: "<ConnectionIDs>0</ConnectionIDs>"
            )
        } else if actionName == "GetCurrentConnectionInfo" || body.contains("GetCurrentConnectionInfo") {
            return createSOAPResponse(
                serviceType: "urn:schemas-upnp-org:service:ConnectionManager:1",
                action: "GetCurrentConnectionInfo",
                content: """
                <RcsID>0</RcsID>
                <AVTransportID>0</AVTransportID>
                <ProtocolInfo>http-get:*:video/mp4:*</ProtocolInfo>
                <PeerConnectionManager></PeerConnectionManager>
                <PeerConnectionID>-1</PeerConnectionID>
                <Direction>Input</Direction>
                <Status>OK</Status>
                """
            )
        }

        Logger.warn("Unknown ConnectionManager action: \(actionName)")
        return createSOAPFault(
            faultCode: "s:Client",
            faultString: "Invalid Action: \(actionName)",
            upnpErrorCode: 401,
            upnpErrorDescription: "Invalid Action"
        )
    }

    private func handleRenderingControlAction(body: String, soapAction: String) -> HttpResponse {
        let actionName = extractActionName(from: soapAction)

        guard soapAction.contains("RenderingControl:1") else {
            return createSOAPFault(
                faultCode: "s:Client",
                faultString: "Invalid service type in SOAPACTION header"
            )
        }

        if actionName == "GetVolume" || body.contains("GetVolume") {
            return createSOAPResponse(
                serviceType: "urn:schemas-upnp-org:service:RenderingControl:1",
                action: "GetVolume",
                content: "<CurrentVolume>\(currentVolume)</CurrentVolume>"
            )
        } else if body.contains("GetMute") {
            let muteValue = currentMute ? "1" : "0"
            return createSOAPResponse(
                serviceType: "urn:schemas-upnp-org:service:RenderingControl:1",
                action: "GetMute",
                content: "<CurrentMute>\(muteValue)</CurrentMute>"
            )
        } else if body.contains("SetVolume") {
            // Parse DesiredVolume from SOAP body
            guard let volumeStr = parseSOAPParameter(body, parameter: "DesiredVolume"),
                  let volume = Int(volumeStr), volume >= 0, volume <= 100
            else {
                Logger.warn("SetVolume: invalid DesiredVolume parameter")
                return createSOAPFault(
                    faultCode: "s:Client",
                    faultString: "Invalid DesiredVolume parameter",
                    upnpErrorCode: 402,
                    upnpErrorDescription: "Invalid Args"
                )
            }

            // Update volume state
            currentVolume = volume

            Logger.info("SetVolume: \(volume)")

            // Actually control player volume
            if let plugin = currentPlugin, let player = plugin.player {
                // AVPlayer volume is 0.0-1.0
                player.volume = Float(volume) / 100.0
                Logger.info("Set AVPlayer volume to \(player.volume)")
            } else {
                // Note: tvOS does not allow apps to control system volume
                // We can only control AVPlayer volume when player is active
                Logger.warn("SetVolume called but no active player - volume will be applied when player starts")
            }

            // Notify subscribers of volume change
            notifyStateChange(service: "RenderingControl", properties: [
                "Volume": "\(currentVolume)",
            ])

            return createSOAPResponse(
                serviceType: "urn:schemas-upnp-org:service:RenderingControl:1",
                action: "SetVolume",
                content: ""
            )
        } else if actionName == "SetMute" || body.contains("SetMute") {
            // Parse DesiredMute from SOAP body
            guard let muteStr = parseSOAPParameter(body, parameter: "DesiredMute") else {
                Logger.warn("SetMute: invalid DesiredMute parameter")
                return createSOAPFault(
                    faultCode: "s:Client",
                    faultString: "Invalid DesiredMute parameter",
                    upnpErrorCode: 402,
                    upnpErrorDescription: "Invalid Args"
                )
            }

            // Update mute state (1 = muted, 0 = unmuted)
            currentMute = (muteStr == "1" || muteStr.lowercased() == "true")

            Logger.info("SetMute: \(currentMute)")

            // Actually control player mute
            if let plugin = currentPlugin, let player = plugin.player {
                player.isMuted = currentMute
                Logger.info("Set AVPlayer muted to \(player.isMuted)")
            } else {
                // Note: tvOS does not allow apps to control system volume
                // We can only control AVPlayer mute when player is active
                Logger.warn("SetMute called but no active player - mute will be applied when player starts")
            }

            // Notify subscribers of mute change
            notifyStateChange(service: "RenderingControl", properties: [
                "Mute": currentMute ? "1" : "0",
            ])

            return createSOAPResponse(
                serviceType: "urn:schemas-upnp-org:service:RenderingControl:1",
                action: "SetMute",
                content: ""
            )
        }

        Logger.warn("Unknown RenderingControl action: \(actionName)")
        return createSOAPFault(
            faultCode: "s:Client",
            faultString: "Invalid Action: \(actionName)",
            upnpErrorCode: 401,
            upnpErrorDescription: "Invalid Action"
        )
    }

    private func createSOAPResponse(serviceType: String, action: String, content: String) -> HttpResponse {
        let soap = """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
        <s:Body>
        <u:\(action)Response xmlns:u="\(serviceType)">
        \(content)
        </u:\(action)Response>
        </s:Body>
        </s:Envelope>
        """
        let headers = ["Content-Type": "text/xml; charset=\"utf-8\""]
        return HttpResponse.raw(200, "OK", headers, { writer in
            if let data = soap.data(using: .utf8) {
                try writer.write(data)
            }
        })
    }

    // DIAL Handlers
    private func handleDIALAppQuery(appName: String) -> HttpResponse {
        Logger.debug("DIAL query for app: \(appName)")

        // Check if there's any running instance of this app
        let runningState = dialAppStates.values.first { state in
            state.appName == appName && state.state == "running"
        }

        let currentState = runningState?.state ?? "stopped"
        var additionalXML = ""

        // If app is running, include run link
        if let running = runningState {
            additionalXML = """

            <link rel="run" href="/apps/\(appName)/run/\(running.runID)"/>
            """
        } else {
            additionalXML = """

            <link rel="run" href="/apps/\(appName)/run"/>
            """
        }

        let appStatus = """
        <?xml version="1.0" encoding="UTF-8"?>
        <service xmlns="urn:dial-multiscreen-org:schemas:dial">
        <name>\(appName)</name>
        <state>\(currentState)</state>\(additionalXML)
        </service>
        """
        return HttpResponse.ok(.text(appStatus))
    }

    private func handleDIALAppLaunch(appName: String, body: String) -> HttpResponse {
        Logger.debug("DIAL launch app: \(appName) with data: \(body)")

        // Minimum viable DIAL implementation
        switch appName.lowercased() {
        case "bilibili", "youtube", "netflix", "video":
            // Try to extract video URL from POST body
            // Body can be URL-encoded parameters or direct URL
            var videoURL: String?

            // Try to parse as URL-encoded form data
            if let url = parseURLFromDIALBody(body) {
                videoURL = url
            } else if body.hasPrefix("http://") || body.hasPrefix("https://") {
                // Direct URL in body
                videoURL = body.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            guard let url = videoURL else {
                Logger.warn("DIAL launch: Could not extract URL from body: \(body)")
                return HttpResponse.raw(400, "Bad Request", ["Content-Type": "text/plain"], { writer in
                    if let data = "No valid URL in request body".data(using: .utf8) {
                        try writer.write(data)
                    }
                })
            }

            // Generate run ID
            let runID = UUID().uuidString

            // Store DIAL app state
            Task { @MainActor in
                self.dialAppStates[runID] = DIALAppState(
                    appName: appName,
                    runID: runID,
                    state: "running",
                    launchedAt: Date(),
                    metadata: ""
                )

                // Map to SetAVTransportURI + Play
                Logger.info("DIAL launching \(appName) with URL: \(url)")
                self.loadVideo(uri: url, metadata: "")

                // Auto-play after short delay to allow loading
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s

                if self.currentPlugin != nil {
                    self.currentPlugin?.resume()
                    Logger.info("DIAL auto-play started for \(appName)")
                }
            }

            // Return 201 Created with run location
            let location = "/apps/\(appName)/run/\(runID)"
            return HttpResponse.raw(
                201,
                "Created",
                [
                    "Location": location,
                    "Content-Length": "0",
                ],
                { _ in }
            )

        default:
            Logger.info("DIAL app launch for unsupported app: \(appName)")
            return HttpResponse.raw(
                503,
                "Service Unavailable",
                ["Content-Type": "text/plain"],
                { writer in
                    if let data = "App not supported".data(using: .utf8) {
                        try writer.write(data)
                    }
                }
            )
        }
    }

    /// Parse URL from DIAL POST body (form-encoded or plain text)
    private func parseURLFromDIALBody(_ body: String) -> String? {
        // Try common parameter names: v, url, videoUrl, etc.
        let paramPatterns = ["v=", "url=", "videoUrl=", "video=", "uri="]

        for pattern in paramPatterns {
            if let range = body.range(of: pattern) {
                let urlStart = range.upperBound
                var urlEnd = body.endIndex

                // Find end of parameter (& or end of string)
                if let ampersand = body[urlStart...].firstIndex(of: "&") {
                    urlEnd = ampersand
                }

                let extractedURL = String(body[urlStart..<urlEnd])
                    .removingPercentEncoding ?? String(body[urlStart..<urlEnd])

                if extractedURL.hasPrefix("http://") || extractedURL.hasPrefix("https://") {
                    return extractedURL
                }
            }
        }

        return nil
    }

    // UPnP Event Subscription Handler
    private func handleEventSubscription(request: HttpRequest, service: String) -> HttpResponse {
        let method = request.method.uppercased()

        if method == "SUBSCRIBE" {
            // Check if this is a renewal or new subscription
            if let sid = request.headers["sid"] {
                // Renewal
                return handleEventRenewal(sid: sid, service: service)
            } else {
                // New subscription
                guard let callback = request.headers["callback"],
                      let timeout = request.headers["timeout"]
                else {
                    // Per UPnP spec: missing required headers → HTTP 400 Bad Request
                    return HttpResponse.raw(400, "Bad Request", [:], nil)
                }
                return handleEventSubscribe(callback: callback, timeout: timeout, service: service)
            }
        } else if method == "UNSUBSCRIBE" {
            guard let sid = request.headers["sid"] else {
                // Per UPnP spec: missing SID header → HTTP 400 Bad Request
                return HttpResponse.raw(400, "Bad Request", [:], nil)
            }
            return handleEventUnsubscribe(sid: sid, service: service)
        }

        return HttpResponse.raw(405, "Method Not Allowed", ["Allow": "SUBSCRIBE, UNSUBSCRIBE"], nil)
    }

    private func handleEventSubscribe(callback: String, timeout: String, service: String) -> HttpResponse {
        // Parse callback URLs (format: <url1><url2>...)
        let callbackURLs = parseCallbackURLs(callback)
        guard !callbackURLs.isEmpty else {
            // Per UPnP spec: invalid callback format → HTTP 400 Bad Request
            return HttpResponse.raw(400, "Bad Request", [:], nil)
        }

        // Parse timeout (format: "Second-1800" or "infinite")
        var timeoutSeconds = 1800 // Default 30 minutes
        if timeout.lowercased() != "infinite" {
            if let seconds = Int(timeout.replacingOccurrences(of: "Second-", with: "").trimmingCharacters(in: .whitespaces)) {
                timeoutSeconds = min(seconds, 86400) // Max 24 hours
            }
        }

        // Generate SID
        let sid = "uuid:\(UUID().uuidString)"

        // Store subscription
        let subscription = EventSubscription(
            sid: sid,
            service: service,
            callbackURLs: callbackURLs,
            timeout: timeoutSeconds,
            subscribedAt: Date()
        )
        setSubscription(subscription, forKey: sid)

        Logger.info("Event subscription created for \(service): SID=\(sid), timeout=\(timeoutSeconds)s")

        // Send initial NOTIFY (SEQ=0) with current state
        // Per UPnP spec, initial NOTIFY must be sent immediately after successful subscription
        DispatchQueue.main.async { [weak self] in
            self?.sendInitialEventNotify(sid: sid, service: service)
        }

        // Return subscription confirmation
        let headers = [
            "SID": sid,
            "TIMEOUT": "Second-\(timeoutSeconds)",
            "Content-Length": "0",
        ]
        return HttpResponse.raw(200, "OK", headers, nil)
    }

    private func handleEventRenewal(sid: String, service: String) -> HttpResponse {
        guard let subscription = getSubscription(forKey: sid) else {
            // Per UPnP spec: invalid SID → HTTP 412 Precondition Failed
            return HttpResponse.raw(412, "Precondition Failed", [:], nil)
        }

        // Renew subscription by updating timestamp
        let renewed = EventSubscription(
            sid: subscription.sid,
            service: subscription.service,
            callbackURLs: subscription.callbackURLs,
            timeout: subscription.timeout,
            subscribedAt: Date()
        )
        setSubscription(renewed, forKey: sid)

        Logger.info("Event subscription renewed for \(service): SID=\(sid)")

        let headers = [
            "SID": sid,
            "TIMEOUT": "Second-\(subscription.timeout)",
            "Content-Length": "0",
        ]
        return HttpResponse.raw(200, "OK", headers, nil)
    }

    private func handleEventUnsubscribe(sid: String, service: String) -> HttpResponse {
        guard getSubscription(forKey: sid) != nil else {
            // Per UPnP spec: invalid SID → HTTP 412 Precondition Failed
            return HttpResponse.raw(412, "Precondition Failed", [:], nil)
        }

        removeSubscription(forKey: sid)
        Logger.info("Event subscription removed for \(service): SID=\(sid)")

        return HttpResponse.raw(200, "OK", ["Content-Length": "0"], nil)
    }

    // MARK: - Thread-safe subscription access methods

    private func setSubscription(_ subscription: EventSubscription, forKey key: String) {
        subscriptionQueue.async(flags: .barrier) { [weak self] in
            self?.eventSubscriptions[key] = subscription
        }
    }

    private func getSubscription(forKey key: String) -> EventSubscription? {
        return subscriptionQueue.sync {
            return eventSubscriptions[key]
        }
    }

    private func removeSubscription(forKey key: String) {
        subscriptionQueue.async(flags: .barrier) { [weak self] in
            self?.eventSubscriptions.removeValue(forKey: key)
        }
    }

    private func getAllSubscriptions() -> [String: EventSubscription] {
        return subscriptionQueue.sync {
            return eventSubscriptions
        }
    }

    private func removeAllSubscriptions() {
        subscriptionQueue.async(flags: .barrier) { [weak self] in
            self?.eventSubscriptions.removeAll()
        }
    }

    private func parseCallbackURLs(_ callback: String) -> [String] {
        var urls: [String] = []
        var current = callback

        while let start = current.range(of: "<"), let end = current.range(of: ">", range: start.upperBound..<current.endIndex) {
            let url = String(current[start.upperBound..<end.lowerBound])
            urls.append(url)
            current = String(current[end.upperBound...])
        }

        return urls
    }

    private func cleanupExpiredSubscriptions() {
        let allSubs = getAllSubscriptions()
        let expired = allSubs.filter { $0.value.isExpired }
        for (sid, _) in expired {
            removeSubscription(forKey: sid)
            Logger.debug("Removed expired subscription: \(sid)")
        }
    }

    // MARK: - Event NOTIFY Implementation

    /// Sends UPnP event NOTIFY message to subscribers
    /// - Parameters:
    ///   - sid: Subscription ID
    ///   - service: Service name (AVTransport, ConnectionManager, RenderingControl)
    ///   - properties: Property changes to notify
    private func sendEventNotify(sid: String, service: String, properties: [String: String]) {
        guard var subscription = getSubscription(forKey: sid) else {
            Logger.warn("Subscription \(sid) not found for NOTIFY")
            return
        }

        let lastChange = generateLastChange(service: service, properties: properties)
        let notifyBody = """
        <?xml version="1.0"?>
        <e:propertyset xmlns:e="urn:schemas-upnp-org:event-1-0">
        <e:property>
        <LastChange>\(escapeXML(lastChange))</LastChange>
        </e:property>
        </e:propertyset>
        """

        for callbackURL in subscription.callbackURLs {
            sendHTTPNotify(
                to: callbackURL,
                sid: sid,
                seq: subscription.seq,
                body: notifyBody
            )
        }

        // Increment sequence number for next NOTIFY
        subscription.seq += 1
        if subscription.seq == UInt32.max {
            subscription.seq = 1 // Wrap around, 0 is reserved for initial NOTIFY
        }
        setSubscription(subscription, forKey: sid)
    }

    /// Sends HTTP NOTIFY request to callback URL
    /// - Parameters:
    ///   - url: Callback URL
    ///   - sid: Subscription ID
    ///   - seq: Sequence number
    ///   - body: NOTIFY body XML
    private func sendHTTPNotify(to url: String, sid: String, seq: UInt32, body: String) {
        guard let callbackURL = URL(string: url) else {
            Logger.warn("Invalid callback URL: \(url)")
            return
        }

        var request = URLRequest(url: callbackURL)
        request.httpMethod = "NOTIFY"
        request.setValue("text/xml; charset=\"utf-8\"", forHTTPHeaderField: "CONTENT-TYPE")
        request.setValue("upnp:event", forHTTPHeaderField: "NT")
        request.setValue("upnp:propchange", forHTTPHeaderField: "NTS")
        request.setValue(sid, forHTTPHeaderField: "SID")
        request.setValue("\(seq)", forHTTPHeaderField: "SEQ")
        request.httpBody = body.data(using: .utf8)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                Logger.warn("NOTIFY failed for \(sid) SEQ \(seq): \(error.localizedDescription)")
            } else if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200 {
                    Logger.warn("NOTIFY response \(httpResponse.statusCode) for \(sid) SEQ \(seq)")
                } else {
                    Logger.debug("NOTIFY sent successfully to \(url) SID: \(sid) SEQ: \(seq)")
                }
            }
        }.resume()
    }

    /// Generates LastChange XML for event notification
    /// - Parameters:
    ///   - service: Service name
    ///   - properties: Property changes
    /// - Returns: LastChange XML string
    private func generateLastChange(service: String, properties: [String: String]) -> String {
        var xmlns = "urn:schemas-upnp-org:metadata-1-0/AVT/"

        switch service {
        case "AVTransport":
            xmlns = "urn:schemas-upnp-org:metadata-1-0/AVT/"
        case "RenderingControl":
            xmlns = "urn:schemas-upnp-org:metadata-1-0/RCS/"
        case "ConnectionManager":
            xmlns = "urn:schemas-upnp-org:metadata-1-0/CM/"
        default:
            break
        }

        var propertyXML = ""
        for (key, value) in properties {
            propertyXML += "<\(key) val=\"\(escapeXMLAttribute(value))\"/>"
        }

        return """
        <Event xmlns="\(xmlns)">
        <InstanceID val="0">
        \(propertyXML)
        </InstanceID>
        </Event>
        """
    }

    /// Escapes XML content (for element text)
    private func escapeXML(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    /// Escapes XML attributes (for attribute values)
    private func escapeXMLAttribute(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    /// Parses a SOAP parameter value from XML body
    /// - Parameters:
    ///   - body: SOAP XML body
    ///   - parameter: Parameter name to extract
    /// - Returns: Parameter value or nil if not found
    private func parseSOAPParameter(_ body: String, parameter: String) -> String? {
        // Try to find the parameter in the SOAP body
        // Format: <ParameterName>value</ParameterName>
        let openTag = "<\(parameter)>"
        let closeTag = "</\(parameter)>"

        guard let openRange = body.range(of: openTag),
              let closeRange = body.range(of: closeTag, range: openRange.upperBound..<body.endIndex)
        else {
            return nil
        }

        let valueRange = openRange.upperBound..<closeRange.lowerBound
        return String(body[valueRange])
    }

    /// Sends NOTIFY to all subscribers of a service when state changes
    /// - Parameters:
    ///   - service: Service name (AVTransport, RenderingControl)
    ///   - properties: Changed properties
    private func notifyStateChange(service: String, properties: [String: String]) {
        // Find all subscriptions for this service
        let allSubs = getAllSubscriptions()
        for (sid, subscription) in allSubs {
            // Only notify subscriptions for this specific service
            if subscription.service == service && !subscription.isExpired {
                sendEventNotify(sid: sid, service: service, properties: properties)
            }
        }
    }

    /// Sends initial NOTIFY (SEQ=0) after subscription with current state
    /// - Parameters:
    ///   - sid: Subscription ID
    ///   - service: Service name
    private func sendInitialEventNotify(sid: String, service: String) {
        var properties: [String: String] = [:]

        switch service {
        case "AVTransport":
            // Send current AVTransport state
            properties = [
                "TransportState": "STOPPED",
                "TransportStatus": "OK",
                "CurrentTrackURI": "",
                "AVTransportURI": "",
                "CurrentTransportActions": "Play,Stop,Pause,Seek,Next,Previous",
            ]
        case "RenderingControl":
            // Send current volume/mute state (use actual current values)
            properties = [
                "Volume": "\(currentVolume)",
                "Mute": currentMute ? "1" : "0",
            ]
        case "ConnectionManager":
            // Send connection info
            properties = [
                "SourceProtocolInfo": "",
                "SinkProtocolInfo": "http-get:*:video/mp4:*,http-get:*:application/x-mpegURL:*",
                "CurrentConnectionIDs": "0",
            ]
        default:
            Logger.warn("Unknown service for initial NOTIFY: \(service)")
            return
        }

        sendEventNotify(sid: sid, service: service, properties: properties)
        Logger.debug("Initial NOTIFY sent for \(service) SID: \(sid)")
    }

    // SOAP Fault Response
    private func createSOAPFault(faultCode: String, faultString: String, upnpErrorCode: Int? = nil, upnpErrorDescription: String? = nil) -> HttpResponse {
        var faultDetail = ""
        if let errorCode = upnpErrorCode, let errorDesc = upnpErrorDescription {
            faultDetail = """
            <detail>
            <UPnPError xmlns="urn:schemas-upnp-org:control-1-0">
            <errorCode>\(errorCode)</errorCode>
            <errorDescription>\(errorDesc)</errorDescription>
            </UPnPError>
            </detail>
            """
        }

        let fault = """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
        <s:Body>
        <s:Fault>
        <faultcode>\(faultCode)</faultcode>
        <faultstring>\(faultString)</faultstring>
        \(faultDetail)
        </s:Fault>
        </s:Body>
        </s:Envelope>
        """
        let headers = ["Content-Type": "text/xml; charset=\"utf-8\""]
        return HttpResponse.raw(500, "Internal Server Error", headers, { writer in
            if let data = fault.data(using: .utf8) {
                try writer.write(data)
            }
        })
    }

    // Extract action name from SOAPACTION header
    private func extractActionName(from soapAction: String) -> String {
        // Format: "urn:schemas-upnp-org:service:ServiceType:Version#ActionName"
        // Also handles quoted format: "\"urn:...:service:ServiceType:Version#ActionName\""
        let cleaned = soapAction.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        if let hashIndex = cleaned.lastIndex(of: "#") {
            return String(cleaned[cleaned.index(after: hashIndex)...])
        }
        return ""
    }

    func handleEvent(frame: NVASession.NVAFrame, session: NVASession) {
        let topMost = UIViewController.topMostViewController()
        switch frame.action {
        case "GetVolume":
            session.sendReply(content: ["volume": 30])
        case "Play":
            handlePlay(json: JSON(parseJSON: frame.body))
            session.sendEmpty()
        case "Pause":
            currentPlugin?.pause()
            session.sendEmpty()
        case "Resume":
            currentPlugin?.resume()
            session.sendEmpty()
        case "SwitchDanmaku":
            let json = JSON(parseJSON: frame.body)
            Defaults.shared.showDanmu = json["open"].boolValue
            session.sendEmpty()
        case "Seek":
            let json = JSON(parseJSON: frame.body)
            currentPlugin?.seek(to: json["seekTs"].doubleValue)
            session.sendEmpty()
        case "Stop":
            (topMost as? CommonPlayerViewController)?.dismiss(animated: true)
            session.sendEmpty()
        case "PlayUrl":
            let json = JSON(parseJSON: frame.body)
            session.sendEmpty()
            guard let url = json["url"].url,
                  let extStr = URLComponents(string: url.absoluteString)?.queryItems?
                  .first(where: { $0.name == "nva_ext" })?.value
            else {
                Logger.warn("get play url: \(frame.body)")
                return
            }
            let ext = JSON(parseJSON: extStr)
            handlePlay(json: ext["content"])
        default:
            Logger.debug("action: \(frame.action)")
            session.sendEmpty()
        }
    }

    func handlePlay(json: JSON) {
        let roomId = json["roomId"].stringValue
        if roomId.count > 0, let room = Int(roomId), room > 0 {
            playLive(roomID: room)
        } else {
            playVideo(json: json)
        }
    }

    enum PlayStatus: Int {
        case loading = 3
        case playing = 4
        case paused = 5
        case end = 6
        case stop = 7
    }

    @MainActor func sendStatus(status: PlayStatus) {
        Logger.debug("send status: \(status)")
        Array(sessions).forEach { $0.sendCommand(action: "OnPlayState", content: ["playState": status.rawValue]) }

        // Update UPnP transport state and send NOTIFY
        let upnpState: String
        var properties: [String: String] = [:]

        switch status {
        case .loading:
            upnpState = "TRANSITIONING"
            transportStatus = "OK"
        case .playing:
            upnpState = "PLAYING"
            transportStatus = "OK"
        case .paused:
            upnpState = "PAUSED_PLAYBACK"
            transportStatus = "OK"
        case .end:
            upnpState = "STOPPED"
            transportStatus = "OK"
            // Set position to end when playback completes
            relTime = trackDuration
            properties["RelativeTimePosition"] = relTime
            properties["AbsoluteTimePosition"] = relTime
        case .stop:
            upnpState = "STOPPED"
            transportStatus = "ERROR_OCCURRED"
            // Reset position when playback fails
            relTime = "00:00:00"
            properties["RelativeTimePosition"] = relTime
            properties["AbsoluteTimePosition"] = relTime
        }

        if transportState != upnpState || !properties.isEmpty {
            transportState = upnpState
            properties["TransportState"] = transportState
            properties["TransportStatus"] = transportStatus

            notifyStateChange(service: "AVTransport", properties: properties)
        }
    }

    /// Clear loading state when player is ready
    @MainActor func clearLoadingState() {
        isLoadingVideo = false
        pendingVideoURI = nil
        Logger.debug("Loading state cleared - player is ready")
    }

    /// Apply volume and mute settings to player
    @MainActor func applyVolumeSettings(to player: AVPlayer) {
        // Apply volume (0-100 to 0.0-1.0)
        player.volume = Float(currentVolume) / 100.0
        // Apply mute
        player.isMuted = currentMute
        Logger.info("Applied volume settings: volume=\(player.volume), muted=\(player.isMuted)")
    }

    @MainActor func sendProgress(duration: Int, current: Int) {
        Array(sessions).forEach { $0.sendCommand(action: "OnProgress", content: ["duration": duration, "position": current]) }

        // Update UPnP position and duration
        trackDuration = formatTime(duration)
        relTime = formatTime(current)

        // Send NOTIFY every 5 seconds to avoid excessive traffic
        if current % 5 == 0 {
            notifyStateChange(service: "AVTransport", properties: [
                "RelativeTimePosition": relTime,
                "AbsoluteTimePosition": relTime,
            ])
        }
    }

    /// Format seconds to HH:MM:SS
    private func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }

    /// Parse HH:MM:SS time string to TimeInterval (seconds)
    private func parseTimeString(_ timeString: String) -> TimeInterval {
        let components = timeString.split(separator: ":").compactMap { Int($0) }
        guard components.count == 3 else {
            Logger.warn("Invalid time string format: \(timeString)")
            return 0
        }
        let hours = components[0]
        let minutes = components[1]
        let seconds = components[2]
        return TimeInterval(hours * 3600 + minutes * 60 + seconds)
    }

    func sendVideoSwitch(aid: Int, cid: Int) {
        /* this might cause client disconnect for unkown reason
         let playItem = ["aid": aid, "cid": cid, "contentType": 0, "epId": 0, "seasonId": 0, "roomId": 0] as [String: Any]
         let mockQnDesc = ["curQn": 0,
                           "supportQnList": [
                               [
                                   "description": "",
                                   "displayDesc": "",
                                   "needLogin": false,
                                   "needVip": false,
                                   "quality": 0,
                                   "superscript": "",
                               ],
                           ],
                           "userDesireQn": 0] as [String: Any]
         let data = ["playItem": playItem, "qnDesc": mockQnDesc, "title": "null"] as [String: Any]
         Array(sessions).forEach { $0.sendCommand(action: "OnEpisodeSwitch", content: data) }
          */
    }
}

extension BiliBiliUpnpDMR {
    func playLive(roomID: Int) {
        let player = LivePlayerViewController()
        player.room = LiveRoom(title: "", room_id: roomID, uname: "", area_v2_name: "", keyframe: nil, face: nil, cover_from_user: nil)
        UIViewController.topMostViewController()?.present(player, animated: true)
    }

    func playVideo(json: JSON) {
        let aid = json["aid"].intValue
        let cid = json["cid"].intValue
        let epid = json["epid"].intValue

        let player: VideoDetailViewController
        if epid > 0 {
            player = VideoDetailViewController.create(epid: epid)
        } else {
            player = VideoDetailViewController.create(aid: aid, cid: cid)
        }
        guard let topMost = UIViewController.topMostViewController() else { return }
        if let rootVC = AppDelegate.shared.window?.rootViewController,
           rootVC.presentedViewController != nil
        {
            rootVC.dismiss(animated: false) {
                if let newTopMost = UIViewController.topMostViewController() {
                    player.present(from: newTopMost, direatlyEnterVideo: true)
                }
            }
        } else {
            player.present(from: topMost, direatlyEnterVideo: true)
        }
    }

    /// Load video from DLNA SetAVTransportURI
    @MainActor private func loadVideo(uri: String, metadata: String) {
        Logger.info("Loading video from URI: \(uri)")

        // Set loading state
        isLoadingVideo = true
        pendingVideoURI = uri

        // Check if URI is a Bilibili URL
        if uri.contains("bilibili.com") {
            // Parse Bilibili URL
            if let videoInfo = parseBilibiliURL(uri) {
                Logger.info("Parsed Bilibili URL: aid=\(videoInfo.aid ?? 0), bvid=\(videoInfo.bvid ?? ""), epid=\(videoInfo.epid ?? 0), seasonId=\(videoInfo.seasonId ?? 0)")

                // Create VideoDetailViewController
                let player: VideoDetailViewController
                if let epid = videoInfo.epid, epid > 0 {
                    player = VideoDetailViewController.create(epid: epid)
                } else if let aid = videoInfo.aid, aid > 0 {
                    player = VideoDetailViewController.create(aid: aid, cid: videoInfo.cid ?? 0)
                } else if let bvid = videoInfo.bvid, !bvid.isEmpty {
                    // BV号需要先转换为aid，这里先记录警告
                    Logger.warn("BV号需要转换为aid，暂不支持: \(bvid)")
                    isLoadingVideo = false
                    transportState = "NO_MEDIA_PRESENT"
                    notifyStateChange(service: "AVTransport", properties: [
                        "TransportState": transportState,
                    ])
                    return
                } else if let seasonId = videoInfo.seasonId, seasonId > 0 {
                    // Season ID (ss) URLs require API lookup to convert to epid
                    Logger.warn("季度链接 (ss\(seasonId)) 需要通过 API 转换为 epid，当前暂不支持。请使用具体的剧集链接 (ep 开头)。")
                    isLoadingVideo = false
                    transportState = "NO_MEDIA_PRESENT"
                    notifyStateChange(service: "AVTransport", properties: [
                        "TransportState": transportState,
                    ])
                    return
                } else {
                    Logger.warn("Unable to extract valid video ID from URL: \(uri)")
                    isLoadingVideo = false
                    transportState = "NO_MEDIA_PRESENT"
                    notifyStateChange(service: "AVTransport", properties: [
                        "TransportState": transportState,
                    ])
                    return
                }

                // Present player
                guard let topMost = UIViewController.topMostViewController() else { return }
                if let rootVC = AppDelegate.shared.window?.rootViewController,
                   rootVC.presentedViewController != nil
                {
                    rootVC.dismiss(animated: false) {
                        if let newTopMost = UIViewController.topMostViewController() {
                            player.present(from: newTopMost, direatlyEnterVideo: false)
                        }
                    }
                } else {
                    player.present(from: topMost, direatlyEnterVideo: false)
                }
            } else {
                Logger.warn("Failed to parse Bilibili URL: \(uri)")
                isLoadingVideo = false
                transportState = "NO_MEDIA_PRESENT"
                notifyStateChange(service: "AVTransport", properties: [
                    "TransportState": transportState,
                ])
            }
        } else if uri.hasPrefix("http://") || uri.hasPrefix("https://") {
            // Direct HTTP/HLS URL - use URLPlayPlugin for generic video playback
            Logger.info("Playing direct URL: \(uri)")

            Task { @MainActor in
                // Detect if this is an HLS stream
                let isLive = uri.contains(".m3u8")

                // Create URLPlayPlugin for direct URL playback
                let plugin = URLPlayPlugin(referer: "", isLive: isLive)

                // Set up failure handler
                plugin.onPlayFail = { [weak self] in
                    Task { @MainActor in
                        self?.isLoadingVideo = false
                        self?.transportState = "NO_MEDIA_PRESENT"
                        self?.transportStatus = "ERROR_OCCURRED"
                        self?.notifyStateChange(service: "AVTransport", properties: [
                            "TransportState": self?.transportState ?? "NO_MEDIA_PRESENT",
                            "TransportStatus": self?.transportStatus ?? "ERROR_OCCURRED",
                        ])
                    }
                }

                // Create player view controller
                let playerVC = CommonPlayerViewController()
                playerVC.addPlugin(plugin: plugin)

                // Also add BUpnpPlugin for DLNA control integration
                // Duration will be updated from AVPlayerItem once available
                let upnpPlugin = BUpnpPlugin(duration: nil)
                playerVC.addPlugin(plugin: upnpPlugin)

                // Set up duration tracking for direct URL playback
                // URLPlayPlugin stores weak reference to playerVC in playerDidLoad
                // We'll observe AVPlayerItem.duration in URLPlayPlugin

                // Present the player
                guard let topMost = UIViewController.topMostViewController() else { return }
                topMost.present(playerVC, animated: true) {
                    // Start playback after presentation
                    plugin.play(urlString: uri)
                    Logger.info("Direct URL player presented and playback started")
                }
            }
        } else {
            Logger.warn("Unsupported URI format: \(uri)")
            isLoadingVideo = false
            transportState = "NO_MEDIA_PRESENT"
            notifyStateChange(service: "AVTransport", properties: [
                "TransportState": transportState,
            ])
        }
    }

    /// Parse Bilibili URL to extract video IDs
    private func parseBilibiliURL(_ urlString: String) -> (aid: Int?, bvid: String?, epid: Int?, cid: Int?, seasonId: Int?)? {
        guard let url = URL(string: urlString) else { return nil }

        var aid: Int?
        var bvid: String?
        var epid: Int?
        var cid: Int?
        var seasonId: Int?

        // Extract from path
        let path = url.path

        // Match patterns:
        // /video/av123456
        // /video/BV1xx411c7mD
        // /bangumi/play/ep123456
        // /bangumi/play/ss123456

        if path.contains("/video/av") {
            // Extract aid from /video/av123456
            if let range = path.range(of: "av(\\d+)", options: .regularExpression) {
                let avString = String(path[range])
                aid = Int(avString.replacingOccurrences(of: "av", with: ""))
            }
        } else if path.contains("/video/BV") {
            // Extract bvid from /video/BV1xx411c7mD
            if let range = path.range(of: "BV[a-zA-Z0-9]+", options: .regularExpression) {
                bvid = String(path[range])
            }
        } else if path.contains("/bangumi/play/ep") {
            // Extract epid from /bangumi/play/ep123456
            if let range = path.range(of: "ep(\\d+)", options: .regularExpression) {
                let epString = String(path[range])
                epid = Int(epString.replacingOccurrences(of: "ep", with: ""))
            }
        } else if path.contains("/bangumi/play/ss") {
            // Extract season id from /bangumi/play/ss123456
            let ssPattern = #"ss(\d+)"#
            if let ssMatch = path.range(of: ssPattern, options: .regularExpression) {
                let ssString = String(path[ssMatch])
                if let ss = Int(ssString.replacingOccurrences(of: "ss", with: "")) {
                    seasonId = ss
                    Logger.info("Extracted season ID: ss\(ss)")
                }
            }
        }

        // Extract cid from query parameters if available
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems
        {
            for item in queryItems {
                if item.name == "cid", let value = item.value {
                    cid = Int(value)
                }
            }
        }

        // Return if we found at least one valid ID
        if aid != nil || bvid != nil || epid != nil || seasonId != nil {
            return (aid, bvid, epid, cid, seasonId)
        }

        return nil
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

        if str?.contains("M-SEARCH") == true || str?.contains("ssdp:discover") == true {
            Logger.info("[SSDP] 📥 M-SEARCH received from: \(ipAddress)")
            Logger.debug("[SSDP] Request content:\n\(str ?? "nil")")

            // Parse search target
            var searchTarget = "ssdp:all"
            if let str = str {
                let lines = str.components(separatedBy: "\r\n")
                for line in lines {
                    if line.uppercased().hasPrefix("ST:") {
                        searchTarget = line.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
                        break
                    }
                }
            }

            Logger.info("[SSDP] Search target: \(searchTarget)")

            // Respond to relevant search targets (including Bilibili NirvanaControl)
            let shouldRespond = searchTarget == "ssdp:all" ||
                searchTarget == "upnp:rootdevice" ||
                searchTarget.contains("MediaRenderer") ||
                searchTarget.contains("AVTransport") ||
                searchTarget.contains("ConnectionManager") ||
                searchTarget.contains("RenderingControl") ||
                searchTarget.contains("NirvanaControl") ||
                searchTarget.contains("bilibili") ||
                searchTarget.contains("dial")

            if shouldRespond {
                Logger.info("[SSDP] ✅ Will respond to search target: \(searchTarget)")
                if let responseData = getSSDPResp(searchTarget: searchTarget).data(using: .utf8) {
                    // Add delay to avoid network congestion
                    let delay = Double.random(in: 0.0...0.5)
                    Logger.debug("[SSDP] Sending response after \(String(format: "%.2f", delay))s delay")
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                        // Use unicast socket for sending response (multicast socket is for receiving only)
                        if let unicastSock = self?.udpUnicast {
                            unicastSock.send(responseData, toAddress: address, withTimeout: -1, tag: 0)
                            Logger.info("[SSDP] 📤 Response sent to \(ipAddress) via unicast socket")
                        } else {
                            Logger.warn("[SSDP] ❌ Cannot send response: unicast socket unavailable")
                        }
                    }
                }
            } else {
                Logger.debug("[SSDP] ⏭️ Ignoring search target: \(searchTarget)")
            }
        } else {
            // Log other UDP packets for debugging (non M-SEARCH)
            if let str = str, !str.isEmpty {
                Logger.debug("[UDP] Received non-SSDP packet from \(ipAddress): \(str.prefix(100))...")
            }
        }
    }

    // MARK: - Fallback XML Generators

    /// Generates fallback DLNAInfo.xml content when file is not found in bundle
    private func generateDLNAInfo() -> String {
        return """
        <?xml version="1.0" encoding="utf-8"?>
        <root xmlns:dlna="urn:schemas-dlna-org:device-1-0" xmlns="urn:schemas-upnp-org:device-1-0">
        <specVersion>
        <major>1</major>
        <minor>0</minor>
        </specVersion>
        <device>
        <deviceType>urn:schemas-upnp-org:device:MediaRenderer:1</deviceType>
        <friendlyName>我的小电视</friendlyName>
        <manufacturer>Bilibili Inc.</manufacturer>
        <manufacturerURL>https://www.bilibili.com</manufacturerURL>
        <modelDescription>Bilibili DLNA Renderer</modelDescription>
        <modelName>BilibiliLive</modelName>
        <modelNumber>1.0</modelNumber>
        <UDN>uuid:\(bUuid)</UDN>
        <serviceList>
        <service>
        <serviceType>urn:schemas-upnp-org:service:AVTransport:1</serviceType>
        <serviceId>urn:upnp-org:serviceId:AVTransport</serviceId>
        <controlURL>AVTransport/action</controlURL>
        <eventSubURL>AVTransport/event</eventSubURL>
        <SCPDURL>dlna/AVTransport.xml</SCPDURL>
        </service>
        <service>
        <serviceType>urn:schemas-upnp-org:service:ConnectionManager:1</serviceType>
        <serviceId>urn:upnp-org:serviceId:ConnectionManager</serviceId>
        <controlURL>ConnectionManager/action</controlURL>
        <eventSubURL>ConnectionManager/event</eventSubURL>
        <SCPDURL>dlna/ConnectionManager.xml</SCPDURL>
        </service>
        <service>
        <serviceType>urn:schemas-upnp-org:service:RenderingControl:1</serviceType>
        <serviceId>urn:upnp-org:serviceId:RenderingControl</serviceId>
        <controlURL>RenderingControl/action</controlURL>
        <eventSubURL>RenderingControl/event</eventSubURL>
        <SCPDURL>dlna/RenderingControl.xml</SCPDURL>
        </service>
        <service>
        <serviceType>urn:bilibili-com:service:NirvanaControl:1</serviceType>
        <serviceId>urn:bilibili-com:serviceId:NirvanaControl</serviceId>
        <controlURL>NirvanaControl/action</controlURL>
        <eventSubURL>NirvanaControl/event</eventSubURL>
        <SCPDURL>dlna/NirvanaControl.xml</SCPDURL>
        </service>
        </serviceList>
        </device>
        </root>
        """
    }

    /// Generates fallback NirvanaControl.xml content when file is not found in bundle
    private func generateNirvanaControlScpd() -> String {
        return """
        <?xml version="1.0" encoding="utf-8"?>
        <scpd xmlns="urn:schemas-upnp-org:service-1-0">
        <specVersion><major>1</major><minor>0</minor></specVersion>
        <actionList>
        <action>
        <name>GetAppInfo</name>
        <argumentList></argumentList>
        </action>
        </actionList>
        <serviceStateTable></serviceStateTable>
        </scpd>
        """
    }

    /// Generates fallback AvTransportScpd.xml content when file is not found in bundle
    private func generateAVTransportScpd() -> String {
        return """
        <?xml version="1.0" encoding="utf-8"?>
        <scpd xmlns="urn:schemas-upnp-org:service-1-0">
        <specVersion>
        <major>1</major>
        <minor>0</minor>
        </specVersion>
        <actionList>
        <action>
        <name>GetCurrentTransportActions</name>
        <argumentList>
        <argument>
        <name>InstanceID</name>
        <direction>in</direction>
        <relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable>
        </argument>
        <argument>
        <name>Actions</name>
        <direction>out</direction>
        <relatedStateVariable>CurrentTransportActions</relatedStateVariable>
        </argument>
        </argumentList>
        </action>
        <action>
        <name>GetDeviceCapabilities</name>
        <argumentList>
        <argument>
        <name>InstanceID</name>
        <direction>in</direction>
        <relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable>
        </argument>
        <argument>
        <name>PlayMedia</name>
        <direction>out</direction>
        <relatedStateVariable>PossiblePlaybackStorageMedia</relatedStateVariable>
        </argument>
        <argument>
        <name>RecMedia</name>
        <direction>out</direction>
        <relatedStateVariable>PossibleRecordStorageMedia</relatedStateVariable>
        </argument>
        <argument>
        <name>RecQualityModes</name>
        <direction>out</direction>
        <relatedStateVariable>PossibleRecordQualityModes</relatedStateVariable>
        </argument>
        </argumentList>
        </action>
        <action>
        <name>GetMediaInfo</name>
        <argumentList>
        <argument>
        <name>InstanceID</name>
        <direction>in</direction>
        <relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable>
        </argument>
        <argument>
        <name>NrTracks</name>
        <direction>out</direction>
        <relatedStateVariable>NumberOfTracks</relatedStateVariable>
        </argument>
        <argument>
        <name>MediaDuration</name>
        <direction>out</direction>
        <relatedStateVariable>CurrentMediaDuration</relatedStateVariable>
        </argument>
        <argument>
        <name>CurrentURI</name>
        <direction>out</direction>
        <relatedStateVariable>AVTransportURI</relatedStateVariable>
        </argument>
        <argument>
        <name>CurrentURIMetaData</name>
        <direction>out</direction>
        <relatedStateVariable>AVTransportURIMetaData</relatedStateVariable>
        </argument>
        <argument>
        <name>NextURI</name>
        <direction>out</direction>
        <relatedStateVariable>NextAVTransportURI</relatedStateVariable>
        </argument>
        <argument>
        <name>NextURIMetaData</name>
        <direction>out</direction>
        <relatedStateVariable>NextAVTransportURIMetaData</relatedStateVariable>
        </argument>
        <argument>
        <name>PlayMedium</name>
        <direction>out</direction>
        <relatedStateVariable>PlaybackStorageMedium</relatedStateVariable>
        </argument>
        <argument>
        <name>RecordMedium</name>
        <direction>out</direction>
        <relatedStateVariable>RecordStorageMedium</relatedStateVariable>
        </argument>
        <argument>
        <name>WriteStatus</name>
        <direction>out</direction>
        <relatedStateVariable>RecordMediumWriteStatus</relatedStateVariable>
        </argument>
        </argumentList>
        </action>
        <action>
        <name>GetPositionInfo</name>
        <argumentList>
        <argument>
        <name>InstanceID</name>
        <direction>in</direction>
        <relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable>
        </argument>
        <argument>
        <name>Track</name>
        <direction>out</direction>
        <relatedStateVariable>CurrentTrack</relatedStateVariable>
        </argument>
        <argument>
        <name>TrackDuration</name>
        <direction>out</direction>
        <relatedStateVariable>CurrentTrackDuration</relatedStateVariable>
        </argument>
        <argument>
        <name>TrackMetaData</name>
        <direction>out</direction>
        <relatedStateVariable>CurrentTrackMetaData</relatedStateVariable>
        </argument>
        <argument>
        <name>TrackURI</name>
        <direction>out</direction>
        <relatedStateVariable>CurrentTrackURI</relatedStateVariable>
        </argument>
        <argument>
        <name>RelTime</name>
        <direction>out</direction>
        <relatedStateVariable>RelativeTimePosition</relatedStateVariable>
        </argument>
        <argument>
        <name>AbsTime</name>
        <direction>out</direction>
        <relatedStateVariable>AbsoluteTimePosition</relatedStateVariable>
        </argument>
        <argument>
        <name>RelCount</name>
        <direction>out</direction>
        <relatedStateVariable>RelativeCounterPosition</relatedStateVariable>
        </argument>
        <argument>
        <name>AbsCount</name>
        <direction>out</direction>
        <relatedStateVariable>AbsoluteCounterPosition</relatedStateVariable>
        </argument>
        </argumentList>
        </action>
        <action>
        <name>GetTransportInfo</name>
        <argumentList>
        <argument>
        <name>InstanceID</name>
        <direction>in</direction>
        <relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable>
        </argument>
        <argument>
        <name>CurrentTransportState</name>
        <direction>out</direction>
        <relatedStateVariable>TransportState</relatedStateVariable>
        </argument>
        <argument>
        <name>CurrentTransportStatus</name>
        <direction>out</direction>
        <relatedStateVariable>TransportStatus</relatedStateVariable>
        </argument>
        <argument>
        <name>CurrentSpeed</name>
        <direction>out</direction>
        <relatedStateVariable>TransportPlaySpeed</relatedStateVariable>
        </argument>
        </argumentList>
        </action>
        <action>
        <name>GetTransportSettings</name>
        <argumentList>
        <argument>
        <name>InstanceID</name>
        <direction>in</direction>
        <relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable>
        </argument>
        <argument>
        <name>PlayMode</name>
        <direction>out</direction>
        <relatedStateVariable>CurrentPlayMode</relatedStateVariable>
        </argument>
        <argument>
        <name>RecQualityMode</name>
        <direction>out</direction>
        <relatedStateVariable>CurrentRecordQualityMode</relatedStateVariable>
        </argument>
        </argumentList>
        </action>
        <action>
        <name>Next</name>
        <argumentList>
        <argument>
        <name>InstanceID</name>
        <direction>in</direction>
        <relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable>
        </argument>
        </argumentList>
        </action>
        <action>
        <name>Pause</name>
        <argumentList>
        <argument>
        <name>InstanceID</name>
        <direction>in</direction>
        <relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable>
        </argument>
        </argumentList>
        </action>
        <action>
        <name>Play</name>
        <argumentList>
        <argument>
        <name>InstanceID</name>
        <direction>in</direction>
        <relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable>
        </argument>
        <argument>
        <name>Speed</name>
        <direction>in</direction>
        <relatedStateVariable>TransportPlaySpeed</relatedStateVariable>
        </argument>
        </argumentList>
        </action>
        <action>
        <name>Previous</name>
        <argumentList>
        <argument>
        <name>InstanceID</name>
        <direction>in</direction>
        <relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable>
        </argument>
        </argumentList>
        </action>
        <action>
        <name>Seek</name>
        <argumentList>
        <argument>
        <name>InstanceID</name>
        <direction>in</direction>
        <relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable>
        </argument>
        <argument>
        <name>Unit</name>
        <direction>in</direction>
        <relatedStateVariable>A_ARG_TYPE_SeekMode</relatedStateVariable>
        </argument>
        <argument>
        <name>Target</name>
        <direction>in</direction>
        <relatedStateVariable>A_ARG_TYPE_SeekTarget</relatedStateVariable>
        </argument>
        </argumentList>
        </action>
        <action>
        <name>SetAVTransportURI</name>
        <argumentList>
        <argument>
        <name>InstanceID</name>
        <direction>in</direction>
        <relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable>
        </argument>
        <argument>
        <name>CurrentURI</name>
        <direction>in</direction>
        <relatedStateVariable>AVTransportURI</relatedStateVariable>
        </argument>
        <argument>
        <name>CurrentURIMetaData</name>
        <direction>in</direction>
        <relatedStateVariable>AVTransportURIMetaData</relatedStateVariable>
        </argument>
        </argumentList>
        </action>
        <action>
        <name>SetPlayMode</name>
        <argumentList>
        <argument>
        <name>InstanceID</name>
        <direction>in</direction>
        <relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable>
        </argument>
        <argument>
        <name>NewPlayMode</name>
        <direction>in</direction>
        <relatedStateVariable>CurrentPlayMode</relatedStateVariable>
        </argument>
        </argumentList>
        </action>
        <action>
        <name>Stop</name>
        <argumentList>
        <argument>
        <name>InstanceID</name>
        <direction>in</direction>
        <relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable>
        </argument>
        </argumentList>
        </action>
        </actionList>
        <serviceStateTable>
        <stateVariable sendEvents="no">
        <name>A_ARG_TYPE_InstanceID</name>
        <dataType>ui4</dataType>
        </stateVariable>
        <stateVariable sendEvents="yes">
        <name>TransportState</name>
        <dataType>string</dataType>
        <allowedValueList>
        <allowedValue>STOPPED</allowedValue>
        <allowedValue>PAUSED_PLAYBACK</allowedValue>
        <allowedValue>PLAYING</allowedValue>
        <allowedValue>TRANSITIONING</allowedValue>
        <allowedValue>NO_MEDIA_PRESENT</allowedValue>
        </allowedValueList>
        </stateVariable>
        <stateVariable sendEvents="yes">
        <name>TransportStatus</name>
        <dataType>string</dataType>
        <allowedValueList>
        <allowedValue>OK</allowedValue>
        <allowedValue>ERROR_OCCURRED</allowedValue>
        </allowedValueList>
        </stateVariable>
        <stateVariable sendEvents="yes">
        <name>TransportPlaySpeed</name>
        <dataType>string</dataType>
        <allowedValueList>
        <allowedValue>1</allowedValue>
        </allowedValueList>
        </stateVariable>
        <stateVariable sendEvents="yes">
        <name>CurrentTransportActions</name>
        <dataType>string</dataType>
        </stateVariable>
        <stateVariable sendEvents="no">
        <name>NumberOfTracks</name>
        <dataType>ui4</dataType>
        <allowedValueRange>
        <minimum>0</minimum>
        <maximum>4294967295</maximum>
        </allowedValueRange>
        </stateVariable>
        <stateVariable sendEvents="yes">
        <name>CurrentMediaDuration</name>
        <dataType>string</dataType>
        </stateVariable>
        <stateVariable sendEvents="yes">
        <name>AVTransportURI</name>
        <dataType>string</dataType>
        </stateVariable>
        <stateVariable sendEvents="yes">
        <name>AVTransportURIMetaData</name>
        <dataType>string</dataType>
        </stateVariable>
        <stateVariable sendEvents="yes">
        <name>NextAVTransportURI</name>
        <dataType>string</dataType>
        </stateVariable>
        <stateVariable sendEvents="yes">
        <name>NextAVTransportURIMetaData</name>
        <dataType>string</dataType>
        </stateVariable>
        <stateVariable sendEvents="yes">
        <name>PlaybackStorageMedium</name>
        <dataType>string</dataType>
        <allowedValueList>
        <allowedValue>NETWORK</allowedValue>
        <allowedValue>NONE</allowedValue>
        </allowedValueList>
        </stateVariable>
        <stateVariable sendEvents="yes">
        <name>PossiblePlaybackStorageMedia</name>
        <dataType>string</dataType>
        </stateVariable>
        <stateVariable sendEvents="yes">
        <name>RecordStorageMedium</name>
        <dataType>string</dataType>
        <allowedValueList>
        <allowedValue>NOT_IMPLEMENTED</allowedValue>
        </allowedValueList>
        </stateVariable>
        <stateVariable sendEvents="yes">
        <name>PossibleRecordStorageMedia</name>
        <dataType>string</dataType>
        </stateVariable>
        <stateVariable sendEvents="yes">
        <name>PossibleRecordQualityModes</name>
        <dataType>string</dataType>
        </stateVariable>
        <stateVariable sendEvents="yes">
        <name>CurrentRecordQualityMode</name>
        <dataType>string</dataType>
        <allowedValueList>
        <allowedValue>NOT_IMPLEMENTED</allowedValue>
        </allowedValueList>
        </stateVariable>
        <stateVariable sendEvents="yes">
        <name>RecordMediumWriteStatus</name>
        <dataType>string</dataType>
        <allowedValueList>
        <allowedValue>NOT_IMPLEMENTED</allowedValue>
        </allowedValueList>
        </stateVariable>
        <stateVariable sendEvents="no">
        <name>CurrentTrack</name>
        <dataType>ui4</dataType>
        <allowedValueRange>
        <minimum>0</minimum>
        <maximum>4294967295</maximum>
        <step>1</step>
        </allowedValueRange>
        </stateVariable>
        <stateVariable sendEvents="yes">
        <name>CurrentTrackDuration</name>
        <dataType>string</dataType>
        </stateVariable>
        <stateVariable sendEvents="yes">
        <name>CurrentTrackMetaData</name>
        <dataType>string</dataType>
        </stateVariable>
        <stateVariable sendEvents="yes">
        <name>CurrentTrackURI</name>
        <dataType>string</dataType>
        </stateVariable>
        <stateVariable sendEvents="yes">
        <name>RelativeTimePosition</name>
        <dataType>string</dataType>
        </stateVariable>
        <stateVariable sendEvents="yes">
        <name>AbsoluteTimePosition</name>
        <dataType>string</dataType>
        </stateVariable>
        <stateVariable sendEvents="no">
        <name>RelativeCounterPosition</name>
        <dataType>i4</dataType>
        </stateVariable>
        <stateVariable sendEvents="no">
        <name>AbsoluteCounterPosition</name>
        <dataType>i4</dataType>
        </stateVariable>
        <stateVariable sendEvents="yes">
        <name>CurrentPlayMode</name>
        <dataType>string</dataType>
        <allowedValueList>
        <allowedValue>NORMAL</allowedValue>
        <allowedValue>SHUFFLE</allowedValue>
        <allowedValue>REPEAT_ONE</allowedValue>
        <allowedValue>REPEAT_ALL</allowedValue>
        <allowedValue>RANDOM</allowedValue>
        <allowedValue>DIRECT_1</allowedValue>
        <allowedValue>INTRO</allowedValue>
        </allowedValueList>
        <defaultValue>NORMAL</defaultValue>
        </stateVariable>
        <stateVariable sendEvents="no">
        <name>A_ARG_TYPE_SeekMode</name>
        <dataType>string</dataType>
        <allowedValueList>
        <allowedValue>ABS_TIME</allowedValue>
        <allowedValue>REL_TIME</allowedValue>
        <allowedValue>ABS_COUNT</allowedValue>
        <allowedValue>REL_COUNT</allowedValue>
        <allowedValue>TRACK_NR</allowedValue>
        <allowedValue>CHANNEL_FREQ</allowedValue>
        <allowedValue>TAPE-INDEX</allowedValue>
        <allowedValue>FRAME</allowedValue>
        </allowedValueList>
        </stateVariable>
        <stateVariable sendEvents="no">
        <name>A_ARG_TYPE_SeekTarget</name>
        <dataType>string</dataType>
        </stateVariable>
        </serviceStateTable>
        </scpd>
        """
    }
}
