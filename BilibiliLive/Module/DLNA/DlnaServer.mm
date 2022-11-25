//
//  DlnaServer.m
//  BilibiliLive
//
//  Created by yicheng on 2022/11/25.
//

#import "DlnaServer.h"
#import <Platinum/Platinum.h>
#import <Platinum/PltMediaRenderer.h>
#import <CocoaLumberjack/DDLogMacros.h>
#import <CocoaLumberjack/DDLog.h>
#import <CocoaLumberjack/DDLog+LOGV.h>

typedef void (^ActionBlock)(NPT_Reference<PLT_Action> action);

class MyMediaDelegate: public PLT_MediaRendererDelegate {
public:
    __strong ActionBlock onNext_;
    __strong ActionBlock OnSetAVTransportURI_;

    void SetOnNext(ActionBlock action) {
        onNext_ = action;
    }
    void SetOnSetAVTransportURI(ActionBlock action) {
        OnSetAVTransportURI_ = action;
    }
    
    NPT_Result OnGetCurrentConnectionInfo(PLT_ActionReference& action){return 0;}

    // AVTransport
    NPT_Result OnNext(PLT_ActionReference& action){onNext_(action); return 0;}
    NPT_Result OnPause(PLT_ActionReference& action){return 0;}
    NPT_Result OnPlay(PLT_ActionReference& action){return 0;}
    NPT_Result OnPrevious(PLT_ActionReference& action){return 0;}
    NPT_Result OnSeek(PLT_ActionReference& action){return 0;}
    NPT_Result OnStop(PLT_ActionReference& action){return 0;}
    NPT_Result OnSetAVTransportURI(PLT_ActionReference& action){OnSetAVTransportURI_(action);return 0;}
    NPT_Result OnSetPlayMode(PLT_ActionReference& action){return 0;}
    
    // RenderingControl
    NPT_Result OnSetVolume(PLT_ActionReference& action){return 0;}
    NPT_Result OnSetVolumeDB(PLT_ActionReference& action){return 0;}
    NPT_Result OnGetVolumeDBRange(PLT_ActionReference& action){return 0;}
    NPT_Result OnSetMute(PLT_ActionReference& action){return 0;}
};

@interface DlnaServer() {
    PLT_UPnP upnp;
    PLT_MediaRenderer* player;
    MyMediaDelegate *playerDelegate;
}
@end


class Bilibi: public PLT_DeviceHost {
    
};
#define ddLogLevel DDLogLevelDebug
@implementation DlnaServer
- (void)setup {
    
    if (player != nil) { return; }
    DDLogInfo(@"setup");
    player = new PLT_MediaRenderer("通用投屏", false, "e6572b54-f3c7-2d91-2fb5-b757f2537e21");
    __weak typeof(self) weakself = self;
    playerDelegate = new MyMediaDelegate();
    player->SetDelegate(playerDelegate);
    playerDelegate->SetOnNext(^(NPT_Reference<PLT_Action> action) {

        NSLog(@"========");
    });
    playerDelegate->SetOnSetAVTransportURI(^(NPT_Reference<PLT_Action> action) {
        __strong typeof(self) self = weakself;
        NPT_String uri;
        action->GetArgumentValue("CurrentURI", uri);
        NSString *url = [NSString stringWithCString:uri.GetChars() encoding: NSUTF8StringEncoding];
        NSLog(@"=========url:%@", url);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.onPlayAction) {
                self.onPlayAction(url);
            }
        });
    });
    PLT_DeviceHostReference device(player);
    upnp.AddDevice(device);
    
}
- (void) start {
    NSLog(@"start");
    upnp.Start();
}

- (void) stop {
    NSLog(@"stop");
    upnp.Stop();
}
@end
