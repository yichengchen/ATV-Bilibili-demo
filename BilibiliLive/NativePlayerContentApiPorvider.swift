//
//  NativePlayerContentApiPorvider.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/8/19.
//

import Foundation
import Vapor
import SwiftyJSON

class NativePlayerContentApiPorvider {
    static let shared = NativePlayerContentApiPorvider()
    let port: Int = 8424
    
    private var info: JSON?
    private var app: Application

    private var xml = ""
    private var videoURL = ""
    private var audioURL = ""
    
    private init() {
        app = Application(.production)
        configure(app)
    }
    
    func setVideo(info: JSON) {
        self.info = info
        let dash = info["data"]["dash"]
        let duration = dash["duration"].intValue
        
        let video = dash["video"][1]
        let videoBaseURL = video["base_url"].stringValue
        let videoBackupURL = video["backup_url"].arrayValue.map({$0.stringValue})
        
        
        
        let width = video["width"].intValue
        let height = video["height"].intValue
        let videocodecs = video["codecs"].stringValue
        let videomimeType = video["mimeType"].stringValue
        let frameRate = video["frameRate"].stringValue
        let sar = video["sar"].stringValue
        let startWithSap = video["startWithSap"].stringValue
        let videoBandwidth = video["bandwidth"].stringValue
        
        videoURL = videoBackupURL.first ?? videoBaseURL

        
        let audio = dash["audio"][0]
        let audioBaseURL = audio["base_url"].stringValue
        let audioBackupURL = audio["backup_url"].arrayValue.map({$0.stringValue})
        audioURL = audioBackupURL.first ?? audioBaseURL
        
        let audioMime = audio["mimeType"].stringValue
        let audioCodec = audio["codecs"].stringValue
        
        let aduioBandwidth = audio["bandwidth"].stringValue

        xml = """
<?xml version="1.0"?>
<MPD xmlns="urn:mpeg:dash:schema:mpd:2011">
 <Period id="" duration="\(duration)">
  <AdaptationSet segmentAlignment="true" subsegmentStartsWithSAP="1">
   <Representation id="1" mimeType="\(videomimeType)" codecs="\(videocodecs)" width="\(width)" height="\(height)"  frameRate="\(frameRate)" duration="\(duration)" timescale="1"  sar="\(sar)" startWithSAP="\(startWithSap)" bandwidth="\(videoBandwidth)" media="video.m4s">
   </Representation>
  </AdaptationSet>
  <AdaptationSet segmentAlignment="true" subsegmentStartsWithSAP="1">
   <Representation id="1" mimeType="\(audioMime)" codecs="\(audioCodec)" audioSamplingRate="48000" startWithSAP="1" duration="\(duration)" timescale="1" bandwidth="\(aduioBandwidth)" media="audio.m4s" >
    <AudioChannelConfiguration schemeIdUri="urn:mpeg:dash:23003:3:audio_channel_configuration:2011" value="2"/>
   </Representation>
  </AdaptationSet>
 </Period>
</MPD>
"""
        
    }
    
    private func configure(_ app: Application) {
        app.http.server.configuration.hostname = "0.0.0.0"
        app.http.server.configuration.port = port

        
        app.get("playitem.mpd") { [unowned self] req -> String in
            guard let _ = self.info else { throw Abort(.notFound) }
            return self.xml
        }
        
        app.get("video.m4s") { req in
            req.redirect(to: self.videoURL)
        }
        
        app.get("audio.m4s") { req in
            req.redirect(to: self.audioURL)
        }
    }
    
    func start() {
        do {
            try app.start()
            print("started")
        } catch let err {
            print(err)
        }
    }
}
