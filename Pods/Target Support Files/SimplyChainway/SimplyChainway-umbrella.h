#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "AppHelper.h"
#import "BLEModel.h"
#import "BluetoothUtil.h"
#import "RFIDBlutoothManager.h"
#import "SimplyChainway.h"

FOUNDATION_EXPORT double SimplyChainwayVersionNumber;
FOUNDATION_EXPORT const unsigned char SimplyChainwayVersionString[];

