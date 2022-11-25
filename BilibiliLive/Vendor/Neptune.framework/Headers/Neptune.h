//
//  Neptune.h
//  Neptune.framework
//
//  Created by Sylvain Rebaud on 4/10/15.
//
//

//#include <UIKit/UIKit.h>
//
////! Project version number for Neptune.
//FOUNDATION_EXPORT double Neptune_VersionNumber;
//
////! Project version string for Neptune.
//FOUNDATION_EXPORT const unsigned char Neptune_VersionString[];

#include <Neptune/NptConfig.h>
#include <Neptune/NptCommon.h>
#include <Neptune/NptResults.h>
#include <Neptune/NptTypes.h>
#include <Neptune/NptConstants.h>
#include <Neptune/NptReferences.h>
#include <Neptune/NptStreams.h>
#include <Neptune/NptBufferedStreams.h>
#include <Neptune/NptFile.h>
#include <Neptune/NptNetwork.h>
#include <Neptune/NptSockets.h>
#include <Neptune/NptTime.h>
#include <Neptune/NptThreads.h>
#include <Neptune/NptSystem.h>
#include <Neptune/NptMessaging.h>
#include <Neptune/NptQueue.h>
#include <Neptune/NptSimpleMessageQueue.h>
#include <Neptune/NptSelectableMessageQueue.h>
#include <Neptune/NptXml.h>
#include <Neptune/NptStrings.h>
#include <Neptune/NptArray.h>
#include <Neptune/NptList.h>
#include <Neptune/NptMap.h>
#include <Neptune/NptStack.h>
#include <Neptune/NptUri.h>
#include <Neptune/NptHttp.h>
#include <Neptune/NptDataBuffer.h>
#include <Neptune/NptUtils.h>
#include <Neptune/NptRingBuffer.h>
#include <Neptune/NptBase64.h>
#include <Neptune/NptConsole.h>
#include <Neptune/NptLogging.h>
#include <Neptune/NptSerialPort.h>
#include <Neptune/NptVersion.h>
#include <Neptune/NptDynamicLibraries.h>
#include <Neptune/NptDynamicCast.h>
#include <Neptune/NptDigest.h>
#include <Neptune/NptCrypto.h>
#include <Neptune/NptVersion.h>

// optional modules
#include <Neptune/NptZip.h>
#include <Neptune/NptTls.h>

#if TARGET_OS_IPHONE || TARGET_OS_SIMULATOR || TARGET_OS_TV
#import <UIKit/UIKit.h>
#else
#import <SystemConfiguration/SystemConfiguration.h>
#endif
