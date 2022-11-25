//
//  DlnaServer.h
//  BilibiliLive
//
//  Created by yicheng on 2022/11/25.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
typedef void (^PlayBlock)(NSString* url);

@interface DlnaServer : NSObject
@property (nonatomic, strong) PlayBlock onPlayAction;
- (void)setup;
- (void) start;
@end

NS_ASSUME_NONNULL_END
