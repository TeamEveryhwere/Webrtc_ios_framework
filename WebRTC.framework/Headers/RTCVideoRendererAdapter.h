/*
 *  Copyright 2015 The WebRTC project authors. All Rights Reserved.
 *
 *  Use of this source code is governed by a BSD-style license
 *  that can be found in the LICENSE file in the root of the source
 *  tree. An additional intellectual property rights grant can be found
 *  in the file PATENTS.  All contributing project authors may
 *  be found in the AUTHORS file in the root of the source tree.
 */

#import <Foundation/Foundation.h>
// #include "base/RTCVideoFrame.h"
#import "RTCVideoTrack.h"


NS_ASSUME_NONNULL_BEGIN

/*
 * Creates a rtc::VideoSinkInterface surface for an RTCVideoRenderer. The
 * rtc::VideoSinkInterface is used by WebRTC rendering code - this
 * adapter adapts calls made to that interface to the RTCVideoRenderer supplied
 * during construction.
 */

@protocol RTCVideoRendererAdapterDelegate <NSObject>
-(void)didGetFrame:(RTCVideoFrame *)videoFrame 
            userId:(NSString *)userId;
@end


@interface RTCVideoRendererAdapter : NSObject

- (instancetype)init NS_UNAVAILABLE;
@property(nonatomic, readonly) RTCVideoFrame *videoFrame;

@property (nonatomic, weak) id <RTCVideoRendererAdapterDelegate> delegate;
//
@end

NS_ASSUME_NONNULL_END
