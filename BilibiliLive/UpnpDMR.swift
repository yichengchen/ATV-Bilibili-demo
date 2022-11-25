//
//  UpnpDMR.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/11/25.
//

import CocoaAsyncSocket
import Foundation
import Swifter

class UpnpDMR: NSObject {
    static let shared = UpnpDMR()
    private var udp: GCDAsyncUdpSocket!
    private var httpServer = HttpServer()

    func start() {
        udp = GCDAsyncUdpSocket(delegate: self, delegateQueue: DispatchQueue.main)
        try! udp.enableBroadcast(true)
        try! udp.bind(toPort: 1900)
        try! udp.joinMulticastGroup("239.255.255.250")
        try! udp.beginReceiving()
        try! httpServer.start(49152)
        httpServer["/"] = { req in
            print("handel TxMediaRenderer_desc")
            let content = """
            <root xmlns="urn:schemas-upnp-org:device-1-0" xmlns:dlna="urn:schemas-dlna-org:device-1-0" configId="499354">
              <specVersion>
                <major>1</major>
                <minor>1</minor>
              </specVersion>
              <device>
                <deviceType>urn:schemas-upnp-org:device:MediaRenderer:1</deviceType>
                <friendlyName>卧室的AppleTV</friendlyName>
                <manufacturer>Plutinosoft LLC</manufacturer>
                <manufacturerURL>http://www.plutinosoft.com</manufacturerURL>
                <modelDescription>Plutinosoft AV Media Renderer Device</modelDescription>
                <modelName>AV Renderer Device</modelName>
                <modelURL>http://www.plutinosoft.com/platinum</modelURL>
                <UDN>uuid:9c443d47158b-dmr</UDN>
                <dlna:X_DLNADOC xmlns:dlna="urn:schemas-dlna-org:device-1-0">DMR-1.50</dlna:X_DLNADOC>
                <serviceList>
                  <service>
                    <serviceType>urn:schemas-upnp-org:service:AVTransport:1</serviceType>
                    <serviceId>urn:upnp-org:serviceId:AVTransport</serviceId>
                    <SCPDURL>/scpd.xml</SCPDURL>
                    <controlurl>
                       /control.xml
                     </controlurl>
             <eventsuburl>
               /event.xml
             </eventsuburl>
                  </service>
                </serviceList>
              </device>
            </root>
            """
            return HttpResponse.ok(.text(content))
        }

        httpServer.post["/control.xml"] = {
            req in
            print("handle control")
            print(req.body)
            return HttpResponse.ok(.text(""))
        }
        httpServer["/event.xml"] = {
            req in
            print("handle event")
            print(req.body)
            return HttpResponse.ok(.text(""))
        }
        httpServer["/scpd.xml"] = { req in
            print("handle scp")
            let content = """
            <html>
             <head></head>
             <body>
              This XML file does not appear to have any style information associated with it. The document tree is shown below.
              <scpd xmlns="urn:schemas-upnp-org:service-1-0">
               <specversion>
                <major>
                 1
                </major>
                <minor>
                 0
                </minor>
               </specversion>
               <actionlist>
                <action>
                 <name>
                  GetCurrentTransportActions
                 </name>
                 <argumentlist>
                  <argument>
                   <name>
                    InstanceID
                   </name>
                   <direction>
                    in
                   </direction>
                   <relatedstatevariable>
                    A_ARG_TYPE_InstanceID
                   </relatedstatevariable>
                  </argument>
                  <argument>
                   <name>
                    Actions
                   </name>
                   <direction>
                    out
                   </direction>
                   <relatedstatevariable>
                    CurrentTransportActions
                   </relatedstatevariable>
                  </argument>
                 </argumentlist>
                </action>
                <action>
                 <name>
                  GetDeviceCapabilities
                 </name>
                 <argumentlist>
                  <argument>
                   <name>
                    InstanceID
                   </name>
                   <direction>
                    in
                   </direction>
                   <relatedstatevariable>
                    A_ARG_TYPE_InstanceID
                   </relatedstatevariable>
                  </argument>
                  <argument>
                   <name>
                    PlayMedia
                   </name>
                   <direction>
                    out
                   </direction>
                   <relatedstatevariable>
                    PossiblePlaybackStorageMedia
                   </relatedstatevariable>
                  </argument>
                  <argument>
                   <name>
                    RecMedia
                   </name>
                   <direction>
                    out
                   </direction>
                   <relatedstatevariable>
                    PossibleRecordStorageMedia
                   </relatedstatevariable>
                  </argument>
                  <argument>
                   <name>
                    RecQualityModes
                   </name>
                   <direction>
                    out
                   </direction>
                   <relatedstatevariable>
                    PossibleRecordQualityModes
                   </relatedstatevariable>
                  </argument>
                 </argumentlist>
                </action>
                <action>
                 <name>
                  GetMediaInfo
                 </name>
                 <argumentlist>
                  <argument>
                   <name>
                    InstanceID
                   </name>
                   <direction>
                    in
                   </direction>
                   <relatedstatevariable>
                    A_ARG_TYPE_InstanceID
                   </relatedstatevariable>
                  </argument>
                  <argument>
                   <name>
                    NrTracks
                   </name>
                   <direction>
                    out
                   </direction>
                   <relatedstatevariable>
                    NumberOfTracks
                   </relatedstatevariable>
                  </argument>
                  <argument>
                   <name>
                    MediaDuration
                   </name>
                   <direction>
                    out
                   </direction>
                   <relatedstatevariable>
                    CurrentMediaDuration
                   </relatedstatevariable>
                  </argument>
                  <argument>
                   <name>
                    CurrentURI
                   </name>
                   <direction>
                    out
                   </direction>
                   <relatedstatevariable>
                    AVTransportURI
                   </relatedstatevariable>
                  </argument>
                  <argument>
                   <name>
                    CurrentURIMetaData
                   </name>
                   <direction>
                    out
                   </direction>
                   <relatedstatevariable>
                    AVTransportURIMetaData
                   </relatedstatevariable>
                  </argument>
                  <argument>
                   <name>
                    NextURI
                   </name>
                   <direction>
                    out
                   </direction>
                   <relatedstatevariable>
                    NextAVTransportURI
                   </relatedstatevariable>
                  </argument>
                  <argument>
                   <name>
                    NextURIMetaData
                   </name>
                   <direction>
                    out
                   </direction>
                   <relatedstatevariable>
                    NextAVTransportURIMetaData
                   </relatedstatevariable>
                  </argument>
                  <argument>
                   <name>
                    PlayMedium
                   </name>
                   <direction>
                    out
                   </direction>
                   <relatedstatevariable>
                    PlaybackStorageMedium
                   </relatedstatevariable>
                  </argument>
                  <argument>
                   <name>
                    RecordMedium
                   </name>
                   <direction>
                    out
                   </direction>
                   <relatedstatevariable>
                    RecordStorageMedium
                   </relatedstatevariable>
                  </argument>
                  <argument>
                   <name>
                    WriteStatus
                   </name>
                   <direction>
                    out
                   </direction>
                   <relatedstatevariable>
                    RecordMediumWriteStatus
                   </relatedstatevariable>
                  </argument>
                 </argumentlist>
                </action>
                <action>
                 <name>
                  GetPositionInfo
                 </name>
                 <argumentlist>
                  <argument>
                   <name>
                    InstanceID
                   </name>
                   <direction>
                    in
                   </direction>
                   <relatedstatevariable>
                    A_ARG_TYPE_InstanceID
                   </relatedstatevariable>
                  </argument>
                  <argument>
                   <name>
                    Track
                   </name>
                   <direction>
                    out
                   </direction>
                   <relatedstatevariable>
                    CurrentTrack
                   </relatedstatevariable>
                  </argument>
                  <argument>
                   <name>
                    TrackDuration
                   </name>
                   <direction>
                    out
                   </direction>
                   <relatedstatevariable>
                    CurrentTrackDuration
                   </relatedstatevariable>
                  </argument>
                  <argument>
                   <name>
                    TrackMetaData
                   </name>
                   <direction>
                    out
                   </direction>
                   <relatedstatevariable>
                    CurrentTrackMetaData
                   </relatedstatevariable>
                  </argument>
                  <argument>
                   <name>
                    TrackURI
                   </name>
                   <direction>
                    out
                   </direction>
                   <relatedstatevariable>
                    CurrentTrackURI
                   </relatedstatevariable>
                  </argument>
                  <argument>
                   <name>
                    RelTime
                   </name>
                   <direction>
                    out
                   </direction>
                   <relatedstatevariable>
                    RelativeTimePosition
                   </relatedstatevariable>
                  </argument>
                  <argument>
                   <name>
                    AbsTime
                   </name>
                   <direction>
                    out
                   </direction>
                   <relatedstatevariable>
                    AbsoluteTimePosition
                   </relatedstatevariable>
                  </argument>
                  <argument>
                   <name>
                    RelCount
                   </name>
                   <direction>
                    out
                   </direction>
                   <relatedstatevariable>
                    RelativeCounterPosition
                   </relatedstatevariable>
                  </argument>
                  <argument>
                   <name>
                    AbsCount
                   </name>
                   <direction>
                    out
                   </direction>
                   <relatedstatevariable>
                    AbsoluteCounterPosition
                   </relatedstatevariable>
                  </argument>
                 </argumentlist>
                </action>
                <action>
                 <name>
                  GetTransportInfo
                 </name>
                 <argumentlist>
                  <argument>
                   <name>
                    InstanceID
                   </name>
                   <direction>
                    in
                   </direction>
                   <relatedstatevariable>
                    A_ARG_TYPE_InstanceID
                   </relatedstatevariable>
                  </argument>
                  <argument>
                   <name>
                    CurrentTransportState
                   </name>
                   <direction>
                    out
                   </direction>
                   <relatedstatevariable>
                    TransportState
                   </relatedstatevariable>
                  </argument>
                  <argument>
                   <name>
                    CurrentTransportStatus
                   </name>
                   <direction>
                    out
                   </direction>
                   <relatedstatevariable>
                    TransportStatus
                   </relatedstatevariable>
                  </argument>
                  <argument>
                   <name>
                    CurrentSpeed
                   </name>
                   <direction>
                    out
                   </direction>
                   <relatedstatevariable>
                    TransportPlaySpeed
                   </relatedstatevariable>
                  </argument>
                 </argumentlist>
                </action>
                <action>
                 <name>
                  GetTransportSettings
                 </name>
                 <argumentlist>
                  <argument>
                   <name>
                    InstanceID
                   </name>
                   <direction>
                    in
                   </direction>
                   <relatedstatevariable>
                    A_ARG_TYPE_InstanceID
                   </relatedstatevariable>
                  </argument>
                  <argument>
                   <name>
                    PlayMode
                   </name>
                   <direction>
                    out
                   </direction>
                   <relatedstatevariable>
                    CurrentPlayMode
                   </relatedstatevariable>
                  </argument>
                  <argument>
                   <name>
                    RecQualityMode
                   </name>
                   <direction>
                    out
                   </direction>
                   <relatedstatevariable>
                    CurrentRecordQualityMode
                   </relatedstatevariable>
                  </argument>
                 </argumentlist>
                </action>
                <action>
                 <name>
                  Next
                 </name>
                 <argumentlist>
                  <argument>
                   <name>
                    InstanceID
                   </name>
                   <direction>
                    in
                   </direction>
                   <relatedstatevariable>
                    A_ARG_TYPE_InstanceID
                   </relatedstatevariable>
                  </argument>
                 </argumentlist>
                </action>
                <action>
                 <name>
                  Pause
                 </name>
                 <argumentlist>
                  <argument>
                   <name>
                    InstanceID
                   </name>
                   <direction>
                    in
                   </direction>
                   <relatedstatevariable>
                    A_ARG_TYPE_InstanceID
                   </relatedstatevariable>
                  </argument>
                 </argumentlist>
                </action>
                <action>
                 <name>
                  Play
                 </name>
                 <argumentlist>
                  <argument>
                   <name>
                    InstanceID
                   </name>
                   <direction>
                    in
                   </direction>
                   <relatedstatevariable>
                    A_ARG_TYPE_InstanceID
                   </relatedstatevariable>
                  </argument>
                  <argument>
                   <name>
                    Speed
                   </name>
                   <direction>
                    in
                   </direction>
                   <relatedstatevariable>
                    TransportPlaySpeed
                   </relatedstatevariable>
                  </argument>
                 </argumentlist>
                </action>
                <action>
                 <name>
                  Previous
                 </name>
                 <argumentlist>
                  <argument>
                   <name>
                    InstanceID
                   </name>
                   <direction>
                    in
                   </direction>
                   <relatedstatevariable>
                    A_ARG_TYPE_InstanceID
                   </relatedstatevariable>
                  </argument>
                 </argumentlist>
                </action>
                <action>
                 <name>
                  Seek
                 </name>
                 <argumentlist>
                  <argument>
                   <name>
                    InstanceID
                   </name>
                   <direction>
                    in
                   </direction>
                   <relatedstatevariable>
                    A_ARG_TYPE_InstanceID
                   </relatedstatevariable>
                  </argument>
                  <argument>
                   <name>
                    Unit
                   </name>
                   <direction>
                    in
                   </direction>
                   <relatedstatevariable>
                    A_ARG_TYPE_SeekMode
                   </relatedstatevariable>
                  </argument>
                  <argument>
                   <name>
                    Target
                   </name>
                   <direction>
                    in
                   </direction>
                   <relatedstatevariable>
                    A_ARG_TYPE_SeekTarget
                   </relatedstatevariable>
                  </argument>
                 </argumentlist>
                </action>
                <action>
                 <name>
                  SetAVTransportURI
                 </name>
                 <argumentlist>
                  <argument>
                   <name>
                    InstanceID
                   </name>
                   <direction>
                    in
                   </direction>
                   <relatedstatevariable>
                    A_ARG_TYPE_InstanceID
                   </relatedstatevariable>
                  </argument>
                  <argument>
                   <name>
                    CurrentURI
                   </name>
                   <direction>
                    in
                   </direction>
                   <relatedstatevariable>
                    AVTransportURI
                   </relatedstatevariable>
                  </argument>
                  <argument>
                   <name>
                    CurrentURIMetaData
                   </name>
                   <direction>
                    in
                   </direction>
                   <relatedstatevariable>
                    AVTransportURIMetaData
                   </relatedstatevariable>
                  </argument>
                 </argumentlist>
                </action>
                <action>
                 <name>
                  SetPlayMode
                 </name>
                 <argumentlist>
                  <argument>
                   <name>
                    InstanceID
                   </name>
                   <direction>
                    in
                   </direction>
                   <relatedstatevariable>
                    A_ARG_TYPE_InstanceID
                   </relatedstatevariable>
                  </argument>
                  <argument>
                   <name>
                    NewPlayMode
                   </name>
                   <direction>
                    in
                   </direction>
                   <relatedstatevariable>
                    CurrentPlayMode
                   </relatedstatevariable>
                  </argument>
                 </argumentlist>
                </action>
                <action>
                 <name>
                  Stop
                 </name>
                 <argumentlist>
                  <argument>
                   <name>
                    InstanceID
                   </name>
                   <direction>
                    in
                   </direction>
                   <relatedstatevariable>
                    A_ARG_TYPE_InstanceID
                   </relatedstatevariable>
                  </argument>
                 </argumentlist>
                </action>
               </actionlist>
               <servicestatetable>
                <statevariable sendevents="no">
                 <name>
                  CurrentPlayMode
                 </name>
                 <datatype>
                  string
                 </datatype>
                 <defaultvalue>
                  NORMAL
                 </defaultvalue>
                 <allowedvaluelist>
                  <allowedvalue>
                   NORMAL
                  </allowedvalue>
                  <allowedvalue>
                   REPEAT_ONE
                  </allowedvalue>
                  <allowedvalue>
                   REPEAT_ALL
                  </allowedvalue>
                  <allowedvalue>
                   SHUFFLE
                  </allowedvalue>
                  <allowedvalue>
                   SHUFFLE_NOREPEAT
                  </allowedvalue>
                 </allowedvaluelist>
                </statevariable>
                <statevariable sendevents="no">
                 <name>
                  RecordStorageMedium
                 </name>
                 <datatype>
                  string
                 </datatype>
                 <allowedvaluelist>
                  <allowedvalue>
                   NOT_IMPLEMENTED
                  </allowedvalue>
                 </allowedvaluelist>
                </statevariable>
                <statevariable sendevents="yes">
                 <name>
                  LastChange
                 </name>
                 <datatype>
                  string
                 </datatype>
                </statevariable>
                <statevariable sendevents="no">
                 <name>
                  RelativeTimePosition
                 </name>
                 <datatype>
                  string
                 </datatype>
                </statevariable>
                <statevariable sendevents="no">
                 <name>
                  CurrentTrackURI
                 </name>
                 <datatype>
                  string
                 </datatype>
                </statevariable>
                <statevariable sendevents="no">
                 <name>
                  CurrentTrackDuration
                 </name>
                 <datatype>
                  string
                 </datatype>
                </statevariable>
                <statevariable sendevents="no">
                 <name>
                  CurrentRecordQualityMode
                 </name>
                 <datatype>
                  string
                 </datatype>
                 <allowedvaluelist>
                  <allowedvalue>
                   NOT_IMPLEMENTED
                  </allowedvalue>
                 </allowedvaluelist>
                </statevariable>
                <statevariable sendevents="no">
                 <name>
                  CurrentMediaDuration
                 </name>
                 <datatype>
                  string
                 </datatype>
                </statevariable>
                <statevariable sendevents="no">
                 <name>
                  AbsoluteCounterPosition
                 </name>
                 <datatype>
                  i4
                 </datatype>
                </statevariable>
                <statevariable sendevents="no">
                 <name>
                  RelativeCounterPosition
                 </name>
                 <datatype>
                  i4
                 </datatype>
                </statevariable>
                <statevariable sendevents="no">
                 <name>
                  A_ARG_TYPE_InstanceID
                 </name>
                 <datatype>
                  ui4
                 </datatype>
                </statevariable>
                <statevariable sendevents="no">
                 <name>
                  AVTransportURI
                 </name>
                 <datatype>
                  string
                 </datatype>
                </statevariable>
                <statevariable sendevents="no">
                 <name>
                  TransportState
                 </name>
                 <datatype>
                  string
                 </datatype>
                 <allowedvaluelist>
                  <allowedvalue>
                   STOPPED
                  </allowedvalue>
                  <allowedvalue>
                   PAUSED_PLAYBACK
                  </allowedvalue>
                  <allowedvalue>
                   PLAYING
                  </allowedvalue>
                  <allowedvalue>
                   TRANSITIONING
                  </allowedvalue>
                  <allowedvalue>
                   NO_MEDIA_PRESENT
                  </allowedvalue>
                 </allowedvaluelist>
                </statevariable>
                <statevariable sendevents="no">
                 <name>
                  CurrentTrackMetaData
                 </name>
                 <datatype>
                  string
                 </datatype>
                </statevariable>
                <statevariable sendevents="no">
                 <name>
                  NextAVTransportURI
                 </name>
                 <datatype>
                  string
                 </datatype>
                </statevariable>
                <statevariable sendevents="no">
                 <name>
                  PossibleRecordQualityModes
                 </name>
                 <datatype>
                  string
                 </datatype>
                 <allowedvaluelist>
                  <allowedvalue>
                   NOT_IMPLEMENTED
                  </allowedvalue>
                 </allowedvaluelist>
                </statevariable>
                <statevariable sendevents="no">
                 <name>
                  CurrentTrack
                 </name>
                 <datatype>
                  ui4
                 </datatype>
                 <allowedvaluerange>
                  <minimum>
                   0
                  </minimum>
                  <maximum>
                   65535
                  </maximum>
                  <step>
                   1
                  </step>
                 </allowedvaluerange>
                </statevariable>
                <statevariable sendevents="no">
                 <name>
                  AbsoluteTimePosition
                 </name>
                 <datatype>
                  string
                 </datatype>
                </statevariable>
                <statevariable sendevents="no">
                 <name>
                  NextAVTransportURIMetaData
                 </name>
                 <datatype>
                  string
                 </datatype>
                </statevariable>
                <statevariable sendevents="no">
                 <name>
                  PlaybackStorageMedium
                 </name>
                 <datatype>
                  string
                 </datatype>
                 <allowedvaluelist>
                  <allowedvalue>
                   NONE
                  </allowedvalue>
                  <allowedvalue>
                   UNKNOWN
                  </allowedvalue>
                  <allowedvalue>
                   CD-DA
                  </allowedvalue>
                  <allowedvalue>
                   HDD
                  </allowedvalue>
                  <allowedvalue>
                   NETWORK
                  </allowedvalue>
                 </allowedvaluelist>
                </statevariable>
                <statevariable sendevents="no">
                 <name>
                  CurrentTransportActions
                 </name>
                 <datatype>
                  string
                 </datatype>
                </statevariable>
                <statevariable sendevents="no">
                 <name>
                  RecordMediumWriteStatus
                 </name>
                 <datatype>
                  string
                 </datatype>
                 <allowedvaluelist>
                  <allowedvalue>
                   NOT_IMPLEMENTED
                  </allowedvalue>
                 </allowedvaluelist>
                </statevariable>
                <statevariable sendevents="no">
                 <name>
                  PossiblePlaybackStorageMedia
                 </name>
                 <datatype>
                  string
                 </datatype>
                 <allowedvaluelist>
                  <allowedvalue>
                   NONE
                  </allowedvalue>
                  <allowedvalue>
                   UNKNOWN
                  </allowedvalue>
                  <allowedvalue>
                   CD-DA
                  </allowedvalue>
                  <allowedvalue>
                   HDD
                  </allowedvalue>
                  <allowedvalue>
                   NETWORK
                  </allowedvalue>
                 </allowedvaluelist>
                </statevariable>
                <statevariable sendevents="no">
                 <name>
                  AVTransportURIMetaData
                 </name>
                 <datatype>
                  string
                 </datatype>
                </statevariable>
                <statevariable sendevents="no">
                 <name>
                  NumberOfTracks
                 </name>
                 <datatype>
                  ui4
                 </datatype>
                 <allowedvaluerange>
                  <minimum>
                   0
                  </minimum>
                  <maximum>
                   65535
                  </maximum>
                 </allowedvaluerange>
                </statevariable>
                <statevariable sendevents="no">
                 <name>
                  A_ARG_TYPE_SeekMode
                 </name>
                 <datatype>
                  string
                 </datatype>
                 <allowedvaluelist>
                  <allowedvalue>
                   REL_TIME
                  </allowedvalue>
                  <allowedvalue>
                   TRACK_NR
                  </allowedvalue>
                 </allowedvaluelist>
                </statevariable>
                <statevariable sendevents="no">
                 <name>
                  A_ARG_TYPE_SeekTarget
                 </name>
                 <datatype>
                  string
                 </datatype>
                </statevariable>
                <statevariable sendevents="no">
                 <name>
                  PossibleRecordStorageMedia
                 </name>
                 <datatype>
                  string
                 </datatype>
                 <allowedvaluelist>
                  <allowedvalue>
                   NOT_IMPLEMENTED
                  </allowedvalue>
                 </allowedvaluelist>
                </statevariable>
                <statevariable sendevents="no">
                 <name>
                  TransportStatus
                 </name>
                 <datatype>
                  string
                 </datatype>
                 <allowedvaluelist>
                  <allowedvalue>
                   OK
                  </allowedvalue>
                  <allowedvalue>
                   ERROR_OCCURRED
                  </allowedvalue>
                 </allowedvaluelist>
                </statevariable>
                <statevariable sendevents="no">
                 <name>
                  TransportPlaySpeed
                 </name>
                 <datatype>
                  string
                 </datatype>
                 <allowedvaluelist>
                  <allowedvalue>
                   1
                  </allowedvalue>
                 </allowedvaluelist>
                </statevariable>
               </servicestatetable>
              </scpd>
             </body>
            </html>
            """
            return HttpResponse.ok(.text(content))
        }
    }

    func getIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }

                guard let interface = ptr?.pointee else { return "" }
                let addrFamily = interface.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) {
                    // wifi = ["en0"]
                    // wired = ["en2", "en3", "en4"]
                    // cellular = ["pdp_ip0","pdp_ip1","pdp_ip2","pdp_ip3"]

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

    func getSSDPResp() -> String {
        guard let ip = getIPAddress() else { assertionFailure(); return "" }
        print("generate ssdp res", ip)
        return """
        HTTP/1.1 200 OK
        Location: http://\(ip):49152/
        Cache-Control: max-age=1
        Server: UPnP/1.0 DLNADOC/1.50 Platinum/1.0.4.2
        EXT:
        USN: uuid:skyworth&208B3756FFED&192.168.124.43::urn:schemas-upnp-org:service:AVTransport:1
        ST: urn:schemas-upnp-org:service:AVTransport:1
        Date: Fir, 25 Nov 2022 11:36:18 GMT
        """
    }
}

extension UpnpDMR: GCDAsyncUdpSocketDelegate {
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

        print(data, ipAddress)
        let data = getSSDPResp().data(using: .utf8)!
        sock.send(data, toAddress: address, withTimeout: -1, tag: 0)
    }
}
